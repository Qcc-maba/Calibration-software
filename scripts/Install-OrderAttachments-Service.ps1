#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs the Order Attachments service (Systems/OrderAttachments) as a Windows Service.

.DESCRIPTION
    Publishes the net10 service, installs the Chromium build it renders with, registers the
    service with the SCM and starts it. MBA-930.

    Secrets and paths are MACHINE-scope environment variables, deliberately: a Windows Service
    cannot see the User-scope variables of the person who installed it.

    TWO THINGS THIS SERVICE NEEDS THAT THE OTHERS DO NOT
    ----------------------------------------------------
    1. A BROWSER, IN A PLACE THE SERVICE ACCOUNT CAN READ.
       Playwright looks for Chromium under PLAYWRIGHT_BROWSERS_PATH and defaults to the CURRENT
       USER's LocalAppData. Install it as yourself and a LocalSystem service will not find it.
       This script pins a machine-wide path (C:\ProgramData\ms-playwright) and installs there.

    2. READ ACCESS TO \\maba-priority.
       The documents live on that share. LocalSystem is a machine account and has no rights to
       it - this is the same wall the Instruction Assistant hit against \\maba-dc. Pass
       -ServiceAccount with a domain user that can read the share, or expect every conversion to
       fail. The script checks and says so rather than leaving you to find out from a user.

    LibreOffice is needed only for Word and Excel attachments, which are a small minority. The
    service starts without it and reports those specific files as unconvertible.

.PARAMETER CalibratorConnectionString
    Connection string to the Calibrator database.

    Omit it and the script reads app\.env itself - REMOTE_DATABASE_URL_PROD for -Environment
    Prod, REMOTE_DATABASE_URL_STAGE for Stage - and builds the connection string from it. That is
    the normal case; pass this only to point somewhere else. Nothing has to be typed or pasted,
    which is the point: a half-pasted placeholder is a service that starts and cannot read
    anything.

.PARAMETER Environment
    Which database app\.env entry to read when -CalibratorConnectionString is omitted.
    Prod (default) or Stage.

.PARAMETER ServiceAccount
    Domain account to run as, e.g. MBA\svc-attachments. Strongly recommended: LocalSystem cannot
    read \\maba-priority. Omit to keep the current account (LocalSystem on a fresh install).

.PARAMETER ServiceAccountPassword
    Password for -ServiceAccount.

.PARAMETER Port
    TCP port. Default 5313.

    NOT 5312 - that belongs to Maba.VCT.CustomerPortalApi, which is installed on the same machines.
    Both services grabbing one port means whichever starts second dies on "address already in use",
    and the survivor answers /health for a request meant for the other. That happened on 07/09.

.PARAMETER CacheDirectory
    Where converted PDFs are kept. Default C:\ProgramData\Maba\OrderAttachments\pdf-cache.

.PARAMETER LibreOfficePath
    soffice.exe. Default C:\Program Files\LibreOffice\program\soffice.exe.

.PARAMETER SkipBrowserInstall
    Do not download Chromium. Only when it is already present at the machine-wide path.

.EXAMPLE
    # Normal install. The connection string comes from app\.env; nothing to paste.
    .\Install-OrderAttachments-Service.ps1 -ServiceAccount 'MBA\<account>' -ServiceAccountPassword (Read-Host -AsSecureString)

.EXAMPLE
    # Upgrade the binaries only; everything already configured
    .\Install-OrderAttachments-Service.ps1
#>
param(
    [string] $CalibratorConnectionString,
    [ValidateSet('Prod', 'Stage')]
    [string] $Environment = 'Prod',
    [string] $ServiceAccount,
    [System.Security.SecureString] $ServiceAccountPassword,
    [int]    $Port = 5313,
    [string] $CacheDirectory = 'C:\ProgramData\Maba\OrderAttachments\pdf-cache',
    [string] $LibreOfficePath = 'C:\Program Files\LibreOffice\program\soffice.exe',
    [switch] $SkipBrowserInstall
)

$ErrorActionPreference = 'Stop'

$ServiceName = 'MabaOrderAttachments'
$DisplayName = 'Maba Order Attachments'
$Description = 'Serves the documents Priority attaches to an order to the calibrator, converted to PDF.'

# A machine-wide browser location. The whole point: a service account must be able to read it.
$BrowsersPath = 'C:\ProgramData\ms-playwright'

# scripts\ lives directly under the repo root.
$Root       = Split-Path $PSScriptRoot -Parent
$Project    = Join-Path $Root 'Systems\OrderAttachments\Maba.VCT.OrderAttachments.csproj'
$PublishDir = Join-Path $Root 'Systems\OrderAttachments\publish'
$BinaryPath = Join-Path $PublishDir 'Maba.VCT.OrderAttachments.exe'

Write-Host '=== Maba Order Attachments - Service Installer ===' -ForegroundColor Cyan

if (-not (Test-Path $Project)) {
    Write-Error "Project not found at $Project"
    exit 1
}

# -- Stop first: publish cannot overwrite a running executable -------------------------------
$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq 'Running') {
    Write-Host 'Stopping existing service...' -ForegroundColor Yellow
    Stop-Service -Name $ServiceName -Force
    Start-Sleep -Seconds 3
}

# -- Publish ----------------------------------------------------------------------------------
Write-Host "Publishing to $PublishDir ..." -ForegroundColor Yellow
dotnet publish $Project -c Release -o $PublishDir --nologo | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "dotnet publish failed (exit $LASTEXITCODE)"; exit 1 }
if (-not (Test-Path $BinaryPath)) { Write-Error "Published executable not found at $BinaryPath"; exit 1 }
Write-Host "  Binary: $BinaryPath" -ForegroundColor Gray

# -- Chromium, machine-wide -------------------------------------------------------------------
# Only for THIS process, so playwright.ps1 below installs into the machine-wide directory.
#
# Deliberately NOT a machine-scope variable. PLAYWRIGHT_BROWSERS_PATH is read by every Playwright
# on the box: setting it machine-wide sent the frontend's own e2e Playwright - which pins a
# different Chromium build - looking in a directory that does not hold it, and it could not launch
# at all. The service points itself at this directory from its own configuration instead
# (OrderAttachments:BrowsersPath, applied in Program.cs).
$env:PLAYWRIGHT_BROWSERS_PATH = $BrowsersPath

if ($SkipBrowserInstall) {
    Write-Host "Skipping browser install (-SkipBrowserInstall)." -ForegroundColor Yellow
} else {
    $pw = Join-Path $PublishDir 'playwright.ps1'
    if (-not (Test-Path $pw)) {
        Write-Host "ERROR: playwright.ps1 not found at $pw" -ForegroundColor Red
        Write-Host '       The publish output should contain it. Check the Microsoft.Playwright package.' -ForegroundColor Red
        exit 1
    }
    Write-Host "Installing Chromium into $BrowsersPath ..." -ForegroundColor Yellow
    Write-Host '  (about 300 MB on a first run)' -ForegroundColor DarkGray
    & $pw install chromium
    if ($LASTEXITCODE -ne 0) { Write-Error "playwright install failed (exit $LASTEXITCODE)"; exit 1 }
}

$chromiumPresent = (Test-Path $BrowsersPath) -and
                   @(Get-ChildItem $BrowsersPath -Directory -Filter 'chromium*' -ErrorAction SilentlyContinue).Count -gt 0
if (-not $chromiumPresent) {
    Write-Host "ERROR: no Chromium found under $BrowsersPath - the service cannot render anything." -ForegroundColor Red
    exit 1
}
Write-Host "  Chromium: present under $BrowsersPath" -ForegroundColor Gray

# -- Machine-scope configuration --------------------------------------------------------------
function Set-MachineVar {
    param([string] $Name, [string] $Value, [switch] $Secret)
    if (-not $Value) { return }
    [Environment]::SetEnvironmentVariable($Name, $Value, 'Machine')
    $shown = if ($Secret) { '***' } else { $Value }
    Write-Host "  $Name = $shown" -ForegroundColor Gray
}

# Derive the connection string from app\.env unless one was supplied. app\.env stores it in
# Prisma's URL form; SqlClient needs the key/value form.
if (-not $CalibratorConnectionString) {
    $envFile = Join-Path $Root 'app\.env'
    $key     = if ($Environment -eq 'Stage') { 'REMOTE_DATABASE_URL_STAGE' } else { 'REMOTE_DATABASE_URL_PROD' }

    if (Test-Path $envFile) {
        $line = (Get-Content $envFile | Where-Object { $_ -match "^$key=" })
        if ($line) {
            $raw    = ($line -replace "^$key=", '') -replace '"', ''
            $srv    = ($raw -split '//')[1].Split(';')[0]
            $dbName = [regex]::Match($raw, 'database=([^;]+)').Groups[1].Value
            $usr    = [regex]::Match($raw, 'user=([^;]+)').Groups[1].Value
            $pwd    = [regex]::Match($raw, 'password=([^;]+)').Groups[1].Value

            if ($srv -and $dbName -and $usr) {
                $CalibratorConnectionString =
                    "Server=$srv;Database=$dbName;User Id=$usr;Password=$pwd;TrustServerCertificate=True;Encrypt=False"
                Write-Host "  (connection string read from app\.env, $key -> $dbName)" -ForegroundColor DarkGray
            }
        }
    }
}

Write-Host 'Applying machine-scope configuration...' -ForegroundColor Yellow
Set-MachineVar 'ConnectionStrings__Calibrator' $CalibratorConnectionString -Secret
Set-MachineVar 'OrderAttachments__BrowsersPath' $BrowsersPath
Set-MachineVar 'OrderAttachments__CacheDirectory' $CacheDirectory
Set-MachineVar 'OrderAttachments__LibreOfficePath' $LibreOfficePath
# Deliberately NOT ASPNETCORE_URLS - it is machine-wide and shared with every other ASP.NET
# service on this box. OrderAttachments__Urls is read only by this service.
Set-MachineVar 'OrderAttachments__Urls' "http://localhost:$Port"

$effectiveConn = [Environment]::GetEnvironmentVariable('ConnectionStrings__Calibrator', 'Machine')
if (-not $effectiveConn) {
    Write-Host 'ERROR: no machine-scope Calibrator connection string. The service will not start.' -ForegroundColor Red
    Write-Host "       Could not read it from app\.env either. Pass -CalibratorConnectionString." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Path $CacheDirectory -Force | Out-Null
Write-Host "  cache directory: $CacheDirectory" -ForegroundColor Gray

if (-not (Test-Path $LibreOfficePath)) {
    Write-Host 'WARNING: LibreOffice not found. Word and Excel attachments will be reported as' -ForegroundColor Yellow
    Write-Host "         unconvertible. Everything else still works. Looked at: $LibreOfficePath" -ForegroundColor Yellow
}

# -- (Re)register with the SCM ------------------------------------------------------------------
if ($svc) {
    Write-Host 'Removing existing service registration...' -ForegroundColor Yellow
    sc.exe delete $ServiceName | Out-Null
    Start-Sleep -Seconds 2
}

# A domain account cannot run a service without the "Log on as a service" right. Without it the
# service is created happily and then refuses to start with 1069, which reads like a password
# problem and is not one. There is no cmdlet for this; secedit is the supported route.
function Grant-LogonAsService {
    param([string] $Account)

    try {
        $sid = (New-Object System.Security.Principal.NTAccount($Account)
               ).Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch {
        Write-Host "  WARNING: could not resolve $Account to a SID: $($_.Exception.Message)" -ForegroundColor Yellow
        return
    }

    $export = Join-Path $env:TEMP "maba-rights-export.inf"
    $import = Join-Path $env:TEMP "maba-rights-import.inf"
    secedit /export /cfg $export /areas USER_RIGHTS | Out-Null

    $line = (Get-Content $export | Where-Object { $_ -like 'SeServiceLogonRight*' })
    $current = if ($line) { ($line -split '=', 2)[1].Trim() } else { '' }

    if (($current -split ',' | ForEach-Object { $_.Trim() }) -contains "*$sid") {
        Write-Host '  log on as a service: already granted' -ForegroundColor Gray
        return
    }

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

    secedit /configure /db secedit.sdb /cfg $import /areas USER_RIGHTS | Out-Null
    Write-Host "  log on as a service: granted to $Account" -ForegroundColor Gray
    Remove-Item $export, $import -ErrorAction SilentlyContinue
}

Write-Host "Creating Windows Service '$ServiceName'..." -ForegroundColor Yellow

# New-Service rather than sc.exe. sc.exe takes the password as a command-line argument, and a
# password holding a character PowerShell's native-argument parser treats specially produces
# "Failed to create service (exit 1639)" - ERROR_INVALID_COMMAND_LINE - which says nothing about
# the real cause. New-Service takes a PSCredential, so the password never reaches a command line.
$newServiceArgs = @{
    Name           = $ServiceName
    BinaryPathName = "`"$BinaryPath`""
    DisplayName    = $DisplayName
    Description    = $Description
    StartupType    = 'Automatic'
    ErrorAction    = 'Stop'
}

if ($ServiceAccount) {
    if (-not $ServiceAccountPassword) {
        Write-Host 'ERROR: -ServiceAccount needs -ServiceAccountPassword.' -ForegroundColor Red
        exit 1
    }
    Grant-LogonAsService -Account $ServiceAccount
    $newServiceArgs.Credential =
        New-Object System.Management.Automation.PSCredential($ServiceAccount, $ServiceAccountPassword)
    Write-Host "  running as: $ServiceAccount" -ForegroundColor Gray
} else {
    Write-Host '  running as: LocalSystem' -ForegroundColor Yellow
    Write-Host '  WARNING: LocalSystem cannot read \maba-priority. Every conversion will fail.' -ForegroundColor Yellow
    Write-Host '           Re-run with -ServiceAccount <domain user>, or set the account in' -ForegroundColor Yellow
    Write-Host '           services.msc > Log On.' -ForegroundColor Yellow
}

try {
    New-Service @newServiceArgs | Out-Null
} catch {
    Write-Host "ERROR: Failed to create service: $($_.Exception.Message)" -ForegroundColor Red
    if ($ServiceAccount) {
        Write-Host '       If it mentions the account or password, check that the account name is' -ForegroundColor Red
        Write-Host '       fully qualified (DOMAIN\user) and that the password is correct.' -ForegroundColor Red
    }
    exit 1
}

# Restart on failure: 1st and 2nd after 30s, subsequent after 60s; counter resets daily.
sc.exe failure $ServiceName reset= 86400 actions= restart/30000/restart/30000/restart/60000 | Out-Null

# The service account needs to write the PDF cache.
if ($ServiceAccount) {
    Write-Host "Granting $ServiceAccount write access to the cache directory..." -ForegroundColor Yellow
    icacls $CacheDirectory /grant "${ServiceAccount}:(OI)(CI)M" /T /Q | Out-Null
    icacls $BrowsersPath /grant "${ServiceAccount}:(OI)(CI)RX" /T /Q | Out-Null
}

Write-Host 'Starting service...' -ForegroundColor Yellow
Start-Service -Name $ServiceName
Start-Sleep -Seconds 5

$svc = Get-Service -Name $ServiceName
if ($svc.Status -ne 'Running') {
    Write-Host "WARNING: service installed but status is: $($svc.Status)" -ForegroundColor Yellow
    Write-Host 'Check Event Viewer > Windows Logs > Application.' -ForegroundColor Yellow
    exit 1
}

# -- Prove it can actually reach what it needs, not merely that the SCM started it -------------
Write-Host "Verifying http://localhost:$Port/health ..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod "http://localhost:$Port/health" -TimeoutSec 30
} catch {
    Write-Host "WARNING: the service is running but /health did not answer: $($_.Exception.Message)" -ForegroundColor Yellow
    exit 1
}

Write-Host "Service '$ServiceName' is running." -ForegroundColor Green
Write-Host "  identity        : $($health.identity)" -ForegroundColor Gray
Write-Host "  database        : $($health.database)" -ForegroundColor Gray
Write-Host "  attachment share: $(if ($health.attachmentShareReachable) { 'reachable' } else { 'NOT REACHABLE' })" -ForegroundColor Gray
Write-Host "  chromium        : $(if ($health.chromiumInstalled) { 'found' } else { 'NOT FOUND' })" -ForegroundColor Gray
Write-Host "  pdf cache       : $(if ($health.cacheWritable) { 'writable' } else { 'NOT WRITABLE' })" -ForegroundColor Gray
Write-Host "  libreoffice     : $(if ($health.libreOfficeInstalled) { 'found' } else { 'not installed (Office files only)' })" -ForegroundColor Gray

$blocked = $false

if ($health.database -ne 'ok') {
    Write-Host "ERROR: the database is not reachable: $($health.database)" -ForegroundColor Red
    $blocked = $true
}
if (-not $health.attachmentShareReachable) {
    Write-Host 'ERROR: the service cannot read the Priority attachment share, so no document can' -ForegroundColor Red
    Write-Host "       be opened. Share: $($health.attachmentShare)" -ForegroundColor Red
    Write-Host "       Running as '$($health.identity)'. Give the service a domain account with" -ForegroundColor Red
    Write-Host '       read access (services.msc > Log On), then restart it.' -ForegroundColor Red
    $blocked = $true
}
if (-not $health.chromiumInstalled) {
    Write-Host "ERROR: no Chromium under $($health.browsersDirectory) - nothing can be rendered." -ForegroundColor Red
    $blocked = $true
}
if (-not $health.cacheWritable) {
    Write-Host "ERROR: the PDF cache is not writable: $($health.cacheDirectory)" -ForegroundColor Red
    $blocked = $true
}

if ($blocked) {
    Write-Host 'The service is installed but cannot serve documents until the above is fixed.' -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host 'Ready. The work assignment screen can call:' -ForegroundColor Green
Write-Host "  http://localhost:$Port/api/orders/attachments/counts?ids=1,2,3" -ForegroundColor Gray
Write-Host "  http://localhost:$Port/api/orders/<id>/attachments" -ForegroundColor Gray
