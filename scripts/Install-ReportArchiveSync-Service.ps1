#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs the Report Archive Sync (Systems/ReportArchiveSync) as a Windows Service.

.DESCRIPTION
    Publishes the net10 worker, registers it with the SCM and starts it.

    The worker mirrors calibration report PDFs out of Priority's Tomax archive
    (\\maba-priority\priority\Tomax\Archives\DOC_Q\Out) into the S3 bucket the web app reads, and
    indexes them in dbo.CalibrationReportFile so the report icon can light up. It runs on-prem
    because the archive is an SMB share the cloud cannot reach.

    Secrets are stored as MACHINE-scope environment variables; a service cannot see the User-scope
    variables of whoever installed it. Values are only written when supplied, so re-running to
    upgrade the binaries leaves existing secrets untouched.

.PARAMETER LogOnAccount
    Domain account the service runs as, e.g. MABA\svc-reportsync.

    This matters more here than for a typical service. LocalSystem authenticates to other machines
    as the COMPUTER account, and \\maba-priority will usually refuse it - the worker would then
    log "archive folder could not be listed" on every cycle and quietly sync nothing. Give it an
    account with READ access to the share. The service never writes there: that is Priority's own
    document archive.

    Omit it on a re-run to keep the service's current registration and account: the binaries are
    republished in place and the service restarted. Pass it to (re)create the service under that
    account.

.PARAMETER LogOnPassword
    Password for -LogOnAccount, as a SecureString. Omit it to be prompted (masked), which keeps it
    out of the command line and the PowerShell history. It is checked against the domain before
    anything is changed, and handed to New-Service as a PSCredential: sc.exe with password= fails
    with 1639 when the password holds characters its parser treats specially.

.PARAMETER ConnectionString
    Calibrator database (CalibratorProd or Calibrator). Omit to keep the current one.

.PARAMETER BucketName
    S3 bucket the app reads reports from: calibrationsoftware (PROD) or calibrationsoftware-stage
    (STAGE). No default (MBA-1028). Required on a first install; omit to keep the current one.

.PARAMETER AwsAccessKeyId
    AWS credentials for that bucket. Omit to keep the current ones.

.PARAMETER AwsSecretAccessKey
    Secret half of the AWS credentials.

.PARAMETER SourceId
    Priority company: 1 = MABA (amaba), 2 = SEPHARM. Default 1.

    Deliberately not "both". The two companies keep independent DOC sequences in the same numeric
    range, so processing them against one archive could attach one company's report to the other's
    device, silently.

.PARAMETER DryRun
    "true" (the DEFAULT) resolves and logs what it would do, uploading and writing nothing.
    Pass "false" only once the log for that environment looks right.

.PARAMETER ArchiveRoot
    UNC path of the Tomax archive. Must be UNC, never a mapped drive letter - a service account
    has no drive mappings, so "P:\..." would resolve to nothing and find no reports at all.
    PROD: \\maba-priority\priority\Tomax\Archives\DOC_Q\Out. STAGE: the same folder on the test
    Priority server. No default (MBA-1028), so a STAGE install can never read production's archive
    by omission. Required on a first install; omit to keep the current one.

.PARAMETER InvoiceRoot
    UNC root of Priority's own files, which invoice attachment paths (..\..\system\mail\...) are
    relative to (MBA-998). PROD: \\maba-priority\Priority. STAGE: \\priority-test\Priority.
    Set it to turn on copying invoice PDFs to S3 for the customer portal. On a first install,
    leaving it unset means the service copies reports only; on a later run, omitting it keeps the
    current one (use -DisableInvoices to turn copying off). The service account needs read access
    to <root>\system\mail.

.PARAMETER DisableInvoices
    Turns invoice copying off: removes the ReportArchiveSync__InvoiceRoot machine variable.
    Cannot be combined with -InvoiceRoot.

.PARAMETER OrderAttachmentShare
    UNC folder of Priority's order attachments (MBA-930). PROD: \\maba-priority\Priority\Attachments.
    STAGE: \\priority-test\Priority\Attachments - priority-test's rows still name \\maba-priority,
    and the service reads this root instead. Set it to turn on converting the documents Priority
    attaches to an order into PDFs in S3, for the work-assignment screen. Omitting it keeps the
    current one; on a first install that means off. Turning it on also installs Chromium into
    -BrowsersPath and grants -LogOnAccount read access to it.

.PARAMETER DisableOrderAttachments
    Turns order-attachment conversion off: removes ReportArchiveSync__OrderAttachmentShare.
    Cannot be combined with -OrderAttachmentShare.

.PARAMETER BrowsersPath
    Where Chromium is installed for the attachment conversion. Default C:\ProgramData\ms-playwright.
    Set for this service only, never as a machine-wide PLAYWRIGHT_BROWSERS_PATH: another Playwright
    on the box pins a different build and stopped launching when that happened (07/09/2026).

.PARAMETER LibreOfficePath
    soffice.exe, for Word/Excel documents inside a mail. Optional: without it those parts are listed
    as errors (the Word/Excel converter is not installed) and everything else converts. Files that
    got such an error are converted again after OrderAttachmentRetryErrorPartsDays (default 7), so
    installing LibreOffice later fills them in.

.PARAMETER DryRun
    'true' converts and logs without uploading or writing; 'false' acts. Omit to keep the current
    value; a first install with no value starts in DryRun.

.PARAMETER PromptForSecrets
    Ask (masked) for the connection string and the AWS keys instead of taking them as parameters,
    so they never appear in the command line or the PowerShell history. Leave a prompt empty to
    keep the machine's current value.

.PARAMETER SkipPublish
    Use the binaries already in Systems\ReportArchiveSync\publish instead of running dotnet
    publish. For a server without the .NET SDK: build the package on a workstation with
    scripts\New-ReportArchiveSyncPackage.ps1, copy and unzip it there, and run this script from
    the package's scripts folder. On an upgrade, stop the service before unzipping over it.

.EXAMPLE
    # First install: observe only. Prompts for the account password and the secrets.
    .\Install-ReportArchiveSync-Service.ps1 -LogOnAccount MABA\svc-reportsync -PromptForSecrets -BucketName calibrationsoftware-stage -ArchiveRoot ...

.EXAMPLE
    # Let it act, after reviewing the dry-run log. Keeps the account, the secrets and every path.
    .\Install-ReportArchiveSync-Service.ps1 -DryRun false
#>
param(
    [string] $LogOnAccount,
    [System.Security.SecureString] $LogOnPassword,
    [switch] $PromptForSecrets,
    [switch] $SkipPublish,
    [string] $ConnectionString,
    [string] $BucketName,
    [string] $AwsAccessKeyId,
    [string] $AwsSecretAccessKey,
    [ValidateSet(1, 2)]
    [int]    $SourceId = 1,
    [ValidateSet('', 'true', 'false')]
    [string] $DryRun = '',
    [string] $ArchiveRoot,
    [string] $InvoiceRoot,
    [switch] $DisableInvoices,
    [string] $OrderAttachmentShare,
    [switch] $DisableOrderAttachments,
    [string] $BrowsersPath = 'C:\ProgramData\ms-playwright',
    [string] $LibreOfficePath
)

$ErrorActionPreference = 'Stop'

$ServiceName = 'MabaReportArchiveSync'
$DisplayName = 'Maba Report Archive Sync'
$Description = 'Mirrors calibration report PDFs from the Priority Tomax archive into S3 and indexes them for the web app.'

$Root       = Split-Path $PSScriptRoot -Parent
$Project    = Join-Path $Root 'Systems\ReportArchiveSync\Maba.VCT.ReportArchiveSync.csproj'
$PublishDir = Join-Path $Root 'Systems\ReportArchiveSync\publish'
$BinaryPath = Join-Path $PublishDir 'Maba.VCT.ReportArchiveSync.exe'

Write-Host '=== Maba Report Archive Sync - Service Installer ===' -ForegroundColor Cyan

if (-not $SkipPublish -and -not (Test-Path $Project)) { Write-Error "Project not found at $Project"; exit 1 }

# -- Secrets and the account, settled before anything on the machine changes ----------------------
function ConvertFrom-SecureText([System.Security.SecureString] $Secure) {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

if ($PromptForSecrets) {
    # Masked, and never in the history. Empty keeps the machine's current value.
    if (-not $ConnectionString) {
        $ConnectionString = ConvertFrom-SecureText (Read-Host -Prompt 'Calibrator connection string (empty = keep current)' -AsSecureString)
    }
    if (-not $AwsAccessKeyId) {
        $AwsAccessKeyId = ConvertFrom-SecureText (Read-Host -Prompt 'AWS access key id (empty = keep current)' -AsSecureString)
    }
    if (-not $AwsSecretAccessKey) {
        $AwsSecretAccessKey = ConvertFrom-SecureText (Read-Host -Prompt 'AWS secret access key (empty = keep current)' -AsSecureString)
    }
}

$Credential = $null
if ($LogOnAccount) {
    if ($LogOnAccount -notmatch '^[^\\]+\\[^\\]+$') {
        Write-Host "ERROR: -LogOnAccount '$LogOnAccount' must be DOMAIN\user." -ForegroundColor Red
        exit 1
    }
    if (-not $LogOnPassword) {
        $LogOnPassword = Read-Host -Prompt "Password for $LogOnAccount" -AsSecureString
    }
    $Credential = New-Object System.Management.Automation.PSCredential($LogOnAccount, $LogOnPassword)

    # A mistyped password into a masked prompt otherwise surfaces three steps later as a vague
    # logon failure. Check it now, against the domain, while nothing has changed yet.
    $domain, $user = $LogOnAccount.Split('\', 2)
    try {
        Add-Type -AssemblyName System.DirectoryServices.AccountManagement
        $context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('Domain', $domain)
        $isValid = $context.ValidateCredentials($user, $Credential.GetNetworkCredential().Password)
    } catch {
        Write-Host "WARNING: could not check the password against domain '$domain': $($_.Exception.Message)" -ForegroundColor Yellow
        $isValid = $null
    }
    if ($isValid -eq $false) {
        Write-Host "ERROR: the domain rejected the password for $LogOnAccount (wrong, expired, locked or disabled)." -ForegroundColor Red
        exit 1
    }
    if ($isValid) { Write-Host "  password for $LogOnAccount checked against the domain" -ForegroundColor Gray }
}

# Omitted means "keep the machine's value"; a first install with none starts in DryRun.
$EffectiveDryRun = if ($DryRun) { $DryRun }
    elseif ([Environment]::GetEnvironmentVariable('ReportArchiveSync__DryRun', 'Machine')) {
        [Environment]::GetEnvironmentVariable('ReportArchiveSync__DryRun', 'Machine') }
    else { 'true' }

# No defaults for these two (MBA-1028): a value that is neither passed nor already on the machine
# would otherwise point a STAGE install at production's archive or bucket.
foreach ($required in @(
        @{ Param = 'ArchiveRoot'; Var = 'ReportArchiveSync__ArchiveRoot'; Value = $ArchiveRoot },
        @{ Param = 'BucketName';  Var = 'ReportArchiveSync__BucketName';  Value = $BucketName })) {
    if (-not $required.Value -and -not [Environment]::GetEnvironmentVariable($required.Var, 'Machine')) {
        Write-Host "ERROR: -$($required.Param) is required: $($required.Var) is not set on this machine yet." -ForegroundColor Red
        exit 1
    }
}

# An omitted value keeps the machine's current one; check and report that one, not an empty string.
$EffectiveArchiveRoot = if ($ArchiveRoot) { $ArchiveRoot } else { [Environment]::GetEnvironmentVariable('ReportArchiveSync__ArchiveRoot', 'Machine') }
$EffectiveBucketName  = if ($BucketName)  { $BucketName }  else { [Environment]::GetEnvironmentVariable('ReportArchiveSync__BucketName', 'Machine') }

if ($EffectiveArchiveRoot -match '^[A-Za-z]:') {
    $ArchiveRoot = $EffectiveArchiveRoot
    Write-Host "ERROR: ArchiveRoot '$ArchiveRoot' is a drive letter." -ForegroundColor Red
    Write-Host '       Drive mappings are per-user and do not exist in a service session, so the' -ForegroundColor Red
    Write-Host '       worker would find no reports and report success. Use the UNC path.' -ForegroundColor Red
    exit 1
}

if ($DisableInvoices -and $InvoiceRoot) {
    Write-Host 'ERROR: -DisableInvoices and -InvoiceRoot cannot be used together.' -ForegroundColor Red
    exit 1
}

$EffectiveInvoiceRoot = if ($DisableInvoices) { '' }
    elseif ($InvoiceRoot) { $InvoiceRoot }
    else { [Environment]::GetEnvironmentVariable('ReportArchiveSync__InvoiceRoot', 'Machine') }

# The service refuses anything but \\server\share at startup; fail here instead, before publishing.
if ($EffectiveInvoiceRoot -and -not $EffectiveInvoiceRoot.StartsWith('\\')) {
    Write-Host "ERROR: InvoiceRoot '$EffectiveInvoiceRoot' is not a UNC path (\\server\share)." -ForegroundColor Red
    exit 1
}

if ($DisableOrderAttachments -and $OrderAttachmentShare) {
    Write-Host 'ERROR: -DisableOrderAttachments and -OrderAttachmentShare cannot be used together.' -ForegroundColor Red
    exit 1
}

$EffectiveAttachmentShare = if ($DisableOrderAttachments) { '' }
    elseif ($OrderAttachmentShare) { $OrderAttachmentShare.TrimEnd('\') }
    else { [Environment]::GetEnvironmentVariable('ReportArchiveSync__OrderAttachmentShare', 'Machine') }

if ($EffectiveAttachmentShare -and -not $EffectiveAttachmentShare.StartsWith('\\')) {
    Write-Host "ERROR: OrderAttachmentShare '$EffectiveAttachmentShare' is not a UNC path (\\server\share)." -ForegroundColor Red
    exit 1
}

# A running instance locks the executable the publish step wants to overwrite.
$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq 'Running') {
    Write-Host 'Stopping existing service...' -ForegroundColor Yellow
    Stop-Service -Name $ServiceName -Force
    Start-Sleep -Seconds 3
}
Get-Process -Name 'Maba.VCT.ReportArchiveSync' -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "  stopping stray console instance (pid $($_.Id))" -ForegroundColor DarkGray
    Stop-Process -Id $_.Id -Force
}

# Who the service will run as: the account given now, or, on a re-run that keeps the registration,
# the one it already has. Every grant below goes to this account.
$existing = if ($svc) { Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" }
$ServiceAccount = if ($LogOnAccount) { $LogOnAccount }
    elseif ($existing -and $existing.StartName -and $existing.StartName -ne 'LocalSystem') { $existing.StartName }
    else { $null }

if ($SkipPublish) {
    # A package built elsewhere (scripts\New-ReportArchiveSyncPackage.ps1): self-contained, so this
    # machine needs neither the .NET SDK nor the runtime.
    Write-Host "Using the pre-built binaries in $PublishDir" -ForegroundColor Yellow
} else {
    Write-Host "Publishing to $PublishDir ..." -ForegroundColor Yellow
    dotnet publish $Project -c Release -o $PublishDir --nologo | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Error "dotnet publish failed (exit $LASTEXITCODE)"; exit 1 }
}
if (-not (Test-Path $BinaryPath)) { Write-Error "Published executable not found at $BinaryPath"; exit 1 }

# -- Chromium for the order attachments (MBA-930) -------------------------------------------------
# PLAYWRIGHT_BROWSERS_PATH is set for THIS script's child only, so the install lands in the
# machine-wide directory. The service points itself there from ReportArchiveSync__BrowsersPath.
if ($EffectiveAttachmentShare) {
    $node = Get-ChildItem (Join-Path $PublishDir '.playwright\node') -Recurse -Filter node.exe -ErrorAction SilentlyContinue |
            Select-Object -First 1
    $cli  = Join-Path $PublishDir '.playwright\package\cli.js'
    if (-not $node -or -not (Test-Path $cli)) {
        Write-Host "ERROR: Playwright's driver is missing from $PublishDir\.playwright - check the Microsoft.Playwright package." -ForegroundColor Red
        exit 1
    }
    Write-Host "Installing Chromium into $BrowsersPath (about 300 MB the first time)..." -ForegroundColor Yellow
    $previous = $env:PLAYWRIGHT_BROWSERS_PATH
    $env:PLAYWRIGHT_BROWSERS_PATH = $BrowsersPath
    & $node.FullName $cli install chromium
    $code = $LASTEXITCODE
    $env:PLAYWRIGHT_BROWSERS_PATH = $previous
    if ($code -ne 0) { Write-Error "Chromium install failed (exit $code)"; exit 1 }
    if (@(Get-ChildItem $BrowsersPath -Directory -Filter 'chromium*' -ErrorAction SilentlyContinue).Count -eq 0) {
        Write-Host "ERROR: no Chromium under $BrowsersPath after the install - mail bodies cannot be rendered." -ForegroundColor Red
        exit 1
    }
    if ($ServiceAccount) {
        icacls $BrowsersPath /grant "${ServiceAccount}:(OI)(CI)RX" /T /Q | Out-Null
    }
}

function Set-MachineVar {
    param([string] $Name, [string] $Value, [switch] $Secret)
    if (-not $Value) { return }
    [Environment]::SetEnvironmentVariable($Name, $Value, 'Machine')
    $shown = if ($Secret) { '***' } else { $Value }
    Write-Host "  $Name = $shown" -ForegroundColor Gray
}

Write-Host 'Applying machine-scope configuration...' -ForegroundColor Yellow

Set-MachineVar 'ReportArchiveSync__ConnectionString' $ConnectionString -Secret
Set-MachineVar 'ReportArchiveSync__BucketName'       $BucketName
Set-MachineVar 'ReportArchiveSync__ArchiveRoot'      $ArchiveRoot
Set-MachineVar 'ReportArchiveSync__InvoiceRoot'      $InvoiceRoot
if ($DisableInvoices) {
    [Environment]::SetEnvironmentVariable('ReportArchiveSync__InvoiceRoot', $null, 'Machine')
    Write-Host '  ReportArchiveSync__InvoiceRoot removed (invoice copying off)' -ForegroundColor Gray
}
Set-MachineVar 'ReportArchiveSync__OrderAttachmentShare' $(if ($OrderAttachmentShare) { $EffectiveAttachmentShare })
if ($DisableOrderAttachments) {
    [Environment]::SetEnvironmentVariable('ReportArchiveSync__OrderAttachmentShare', $null, 'Machine')
    Write-Host '  ReportArchiveSync__OrderAttachmentShare removed (order attachments off)' -ForegroundColor Gray
}
if ($EffectiveAttachmentShare) {
    Set-MachineVar 'ReportArchiveSync__BrowsersPath' $BrowsersPath
}
Set-MachineVar 'ReportArchiveSync__LibreOfficePath' $LibreOfficePath
Set-MachineVar 'ReportArchiveSync__SourceId'         "$SourceId"
Set-MachineVar 'ReportArchiveSync__DryRun'           $EffectiveDryRun
Set-MachineVar 'AWS_ACCESS_KEY_ID'                   $AwsAccessKeyId -Secret
Set-MachineVar 'AWS_SECRET_ACCESS_KEY'               $AwsSecretAccessKey -Secret

# The Event Log is the only log a service has here, and its source (the assembly name) can only be
# registered by an administrator, which the service account is not (seen on priority-test,
# 24/11/2026). Register it now. The Information level is set in the service's own appsettings.json:
# a machine-wide Logging__ variable would raise the level of every .NET service on the box.
$EventSource = 'Maba.VCT.ReportArchiveSync'
if (-not [Diagnostics.EventLog]::SourceExists($EventSource)) {
    New-EventLog -LogName Application -Source $EventSource
    Write-Host "  event source $EventSource registered" -ForegroundColor Gray
}
if ([Environment]::GetEnvironmentVariable('Logging__EventLog__LogLevel__Default', 'Machine')) {
    # Left by an earlier version of this script; it reached every .NET service on the machine.
    [Environment]::SetEnvironmentVariable('Logging__EventLog__LogLevel__Default', $null, 'Machine')
    Write-Host '  Logging__EventLog__LogLevel__Default removed (now set in appsettings.json)' -ForegroundColor Gray
}

if (-not [Environment]::GetEnvironmentVariable('ReportArchiveSync__ConnectionString', 'Machine')) {
    Write-Host 'WARNING: no connection string - the worker cannot find anything to sync.' -ForegroundColor Yellow
}
if ($EffectiveDryRun -eq 'false' -and -not [Environment]::GetEnvironmentVariable('AWS_ACCESS_KEY_ID', 'Machine')) {
    Write-Host 'WARNING: DryRun is off but no AWS credentials are configured - uploads will fail.' -ForegroundColor Yellow
}

# A domain account cannot run a service without "Log on as a service". Without it the service is
# created happily and then refuses to start with 1069, which reads like a password problem and is
# not one. There is no cmdlet for this; secedit is the supported route.
# '*S-1-5-...' or 'S-1-5-...' -> the SID; 'DOMAIN\user' -> its SID; unresolvable -> as given.
function ConvertTo-Sid([string] $Entry) {
    $bare = $Entry.TrimStart('*')
    if ($bare -match '^S-1-') { return $bare }
    try { (New-Object System.Security.Principal.NTAccount($bare)).Translate([System.Security.Principal.SecurityIdentifier]).Value }
    catch { $bare }
}

function Grant-LogonAsService {
    param([string] $Account)

    $sid = (New-Object System.Security.Principal.NTAccount($Account)
           ).Translate([System.Security.Principal.SecurityIdentifier]).Value

    $export = Join-Path $env:TEMP 'maba-rights-export.inf'
    $import = Join-Path $env:TEMP 'maba-rights-import.inf'
    $sdb    = Join-Path $env:TEMP 'maba-rights.sdb'
    # A stale .sdb from an aborted run would be merged into by /configure /db.
    Remove-Item $export, $import, $sdb -ErrorAction SilentlyContinue
    try {
        secedit /export /cfg $export /areas USER_RIGHTS | Out-Null

        $line    = Get-Content $export | Where-Object { $_ -like 'SeServiceLogonRight*' }
        $current = if ($line) { ($line -split '=', 2)[1].Trim() } else { '' }

        # Entries are usually *S-1-..., but secedit lists an account it cannot resolve to a SID by
        # name; compare SIDs either way.
        $grantedSids = $current -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } |
                       ForEach-Object { ConvertTo-Sid $_ }

        if ($grantedSids -contains $sid) {
            Write-Host '  log on as a service: already granted' -ForegroundColor Gray
        } else {
            $updated = if ($current) { "$current,*$sid" } else { "*$sid" }
            @(
                '[Unicode]'
                'Unicode=yes'
                '[Version]'
                'signature="$CHICAGO$"'
                'Revision=1'
                '[Privilege Rights]'
                "SeServiceLogonRight = $updated"
            ) | Set-Content $import -Encoding Unicode
            secedit /configure /db $sdb /cfg $import /areas USER_RIGHTS | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "secedit could not grant Log on as a service (exit $LASTEXITCODE)" }
            Write-Host "  log on as a service: granted to $Account" -ForegroundColor Gray
        }
    } finally {
        Remove-Item $export, $import, $sdb -ErrorAction SilentlyContinue
    }

    # secedit writes LOCAL policy. When a domain GPO defines this right, the next policy refresh
    # (about 90 minutes) replaces the local list, and the service fails with 1069 on its next start.
    # Only IT can fix that, in the GPO.
    $fromGpo = $null
    try {
        $fromGpo = Get-CimInstance -Namespace 'root\rsop\computer' -ClassName RSOP_UserPrivilegeRight `
                       -Filter "UserRight='SeServiceLogonRight' AND precedence=1" -ErrorAction Stop
    } catch { }
    if ($fromGpo) {
        $gpoSids = @($fromGpo.AccountList | ForEach-Object { ConvertTo-Sid $_ })
        if ($gpoSids -notcontains $sid) {
            Write-Host 'WARNING: "Log on as a service" is set by a domain Group Policy that does not list' -ForegroundColor Yellow
            Write-Host "         $Account. The local grant works until the next policy refresh (about" -ForegroundColor Yellow
            Write-Host '         90 minutes); after that the service fails to start with 1069. Ask IT to' -ForegroundColor Yellow
            Write-Host '         add the account to that GPO (docs\IT-REQUEST-service-account.md).' -ForegroundColor Yellow
        }
    }
}

if ($svc -and -not $Credential) {
    # A re-run without -LogOnAccount (e.g. only to turn DryRun off) used to delete the service and
    # recreate it as LocalSystem, which cannot read the share. Keep the account, but point the
    # service at these binaries: they may have moved (a git clone before, an unzipped package now).
    Write-Host "Keeping the existing service registration (runs as $($existing.StartName))." -ForegroundColor Yellow
    $wantedPath = "`"$BinaryPath`""
    if ($existing.PathName -ne $wantedPath) {
        # Win32_Service.Change, not sc.exe binPath=: Windows PowerShell mangles the embedded quotes
        # on a native command line.
        $result = Invoke-CimMethod -InputObject $existing -MethodName Change -Arguments @{ PathName = $wantedPath }
        if ($result.ReturnValue -ne 0) { Write-Error "Could not change the binary path (Win32_Service.Change returned $($result.ReturnValue))"; exit 1 }
        Write-Host "  binary path changed: $($existing.PathName) -> $wantedPath" -ForegroundColor Gray
    }
    if ($ServiceAccount) {
        icacls $PublishDir /grant "${ServiceAccount}:(OI)(CI)RX" /T /Q | Out-Null
    }
} else {
    if ($svc) {
        Write-Host 'Removing existing service registration...' -ForegroundColor Yellow
        sc.exe delete $ServiceName | Out-Null
        Start-Sleep -Seconds 2
    }

    Write-Host "Creating Windows Service '$ServiceName'..." -ForegroundColor Yellow
    # New-Service, never sc.exe password=: a password holding a character the native-argument parser
    # treats specially fails with 1639 (ERROR_INVALID_COMMAND_LINE), which names nothing useful.
    $newServiceArgs = @{
        Name           = $ServiceName
        BinaryPathName = "`"$BinaryPath`""
        DisplayName    = $DisplayName
        Description    = $Description
        StartupType    = 'Automatic'
        ErrorAction    = 'Stop'
    }
    if ($Credential) {
        Grant-LogonAsService -Account $LogOnAccount
        # The service reads its own binaries; a clone under an admin's profile is not readable.
        icacls $PublishDir /grant "${LogOnAccount}:(OI)(CI)RX" /T /Q | Out-Null
        $newServiceArgs.Credential = $Credential
    }
    try {
        New-Service @newServiceArgs | Out-Null
    } catch {
        Write-Host "ERROR: Failed to create service: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    if ($Credential) {
        Write-Host "  running as $LogOnAccount" -ForegroundColor Gray
    } else {
        Write-Host '  running as LocalSystem' -ForegroundColor Gray
        Write-Host 'WARNING: LocalSystem reaches other machines as the COMPUTER account, which' -ForegroundColor Yellow
        Write-Host "         \\maba-priority will usually refuse. The worker would then log" -ForegroundColor Yellow
        Write-Host '         "could not be listed" every cycle and sync nothing. Prefer -LogOnAccount.' -ForegroundColor Yellow
    }
}

# Restart on failure: 1st and 2nd after 30s, subsequent after 60s; counter resets daily.
sc.exe failure $ServiceName reset= 86400 actions= restart/30000/restart/30000/restart/60000 | Out-Null

Write-Host 'Starting service...' -ForegroundColor Yellow
Start-Service -Name $ServiceName
Start-Sleep -Seconds 5

$svc = Get-Service -Name $ServiceName
if ($svc.Status -ne 'Running') {
    Write-Host "WARNING: service installed but status is: $($svc.Status)" -ForegroundColor Yellow
    Write-Host 'Check Event Viewer > Windows Logs > Application.' -ForegroundColor Yellow
    exit 1
}

Write-Host "Service '$ServiceName' is running." -ForegroundColor Green
Write-Host "  archive : $EffectiveArchiveRoot" -ForegroundColor Gray
Write-Host "  bucket  : $EffectiveBucketName" -ForegroundColor Gray
Write-Host "  invoices: $(if ($EffectiveInvoiceRoot) { $EffectiveInvoiceRoot } else { 'off (no -InvoiceRoot)' })" -ForegroundColor Gray
Write-Host "  attachments: $(if ($EffectiveAttachmentShare) { $EffectiveAttachmentShare } else { 'off (no -OrderAttachmentShare)' })" -ForegroundColor Gray
Write-Host "  source  : $SourceId $(if ($SourceId -eq 1) { '(MABA)' } else { '(SEPHARM)' })" -ForegroundColor Gray
Write-Host "  dry run : $EffectiveDryRun" -ForegroundColor $(if ($EffectiveDryRun -eq 'true') { 'Yellow' } else { 'Gray' })

# The worker has no HTTP endpoint, so "is it running" is not the same as "is it working".
Write-Host ''
Write-Host 'It syncs on a one-hour cycle. To confirm the first cycle actually did something:' -ForegroundColor Cyan
Write-Host "  Get-EventLog -LogName Application -Source $EventSource -Newest 30 | ft TimeGenerated, EntryType, Message -Wrap" -ForegroundColor Gray
Write-Host '  ...or query the index directly:' -ForegroundColor Gray
Write-Host '  SELECT COUNT(*) FROM dbo.CalibrationReportFile WHERE IsDeleted = 0;' -ForegroundColor Gray
if ($EffectiveAttachmentShare) {
    Write-Host '  SELECT Outcome, COUNT(*) FROM dbo.CrmOrderAttachmentConversion GROUP BY Outcome;' -ForegroundColor Gray
}
if ($EffectiveDryRun -eq 'true') {
    Write-Host ''
    Write-Host 'DryRun is ON: nothing will be uploaded or written until you re-run with -DryRun false.' -ForegroundColor Yellow
}
