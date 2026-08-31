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

.PARAMETER LogOnPassword
    Password for -LogOnAccount.

.PARAMETER ConnectionString
    Calibrator database (CalibratorProd or Calibrator). Omit to keep the current one.

.PARAMETER BucketName
    S3 bucket the app reads reports from. Default calibrationsoftware.

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

.EXAMPLE
    # First install: observe only
    .\Install-ReportArchiveSync-Service.ps1 -LogOnAccount MABA\svc-reportsync -LogOnPassword *** -ConnectionString "Server=...;Database=CalibratorProd;..."

.EXAMPLE
    # Let it act, after reviewing the dry-run log
    .\Install-ReportArchiveSync-Service.ps1 -DryRun false -AwsAccessKeyId AKIA... -AwsSecretAccessKey ***
#>
param(
    [string] $LogOnAccount,
    [string] $LogOnPassword,
    [string] $ConnectionString,
    [string] $BucketName = 'calibrationsoftware',
    [string] $AwsAccessKeyId,
    [string] $AwsSecretAccessKey,
    [ValidateSet(1, 2)]
    [int]    $SourceId = 1,
    [ValidateSet('true', 'false')]
    [string] $DryRun = 'true',
    [string] $ArchiveRoot = '\\maba-priority\priority\Tomax\Archives\DOC_Q\Out'
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

if (-not (Test-Path $Project)) { Write-Error "Project not found at $Project"; exit 1 }

if ($ArchiveRoot -match '^[A-Za-z]:') {
    Write-Host "ERROR: ArchiveRoot '$ArchiveRoot' is a drive letter." -ForegroundColor Red
    Write-Host '       Drive mappings are per-user and do not exist in a service session, so the' -ForegroundColor Red
    Write-Host '       worker would find no reports and report success. Use the UNC path.' -ForegroundColor Red
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

Write-Host "Publishing to $PublishDir ..." -ForegroundColor Yellow
dotnet publish $Project -c Release -o $PublishDir --nologo | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "dotnet publish failed (exit $LASTEXITCODE)"; exit 1 }
if (-not (Test-Path $BinaryPath)) { Write-Error "Published executable not found at $BinaryPath"; exit 1 }

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
Set-MachineVar 'ReportArchiveSync__SourceId'         "$SourceId"
Set-MachineVar 'ReportArchiveSync__DryRun'           $DryRun
Set-MachineVar 'AWS_ACCESS_KEY_ID'                   $AwsAccessKeyId -Secret
Set-MachineVar 'AWS_SECRET_ACCESS_KEY'               $AwsSecretAccessKey -Secret

if (-not [Environment]::GetEnvironmentVariable('ReportArchiveSync__ConnectionString', 'Machine')) {
    Write-Host 'WARNING: no connection string - the worker cannot find anything to sync.' -ForegroundColor Yellow
}
if ($DryRun -eq 'false' -and -not [Environment]::GetEnvironmentVariable('AWS_ACCESS_KEY_ID', 'Machine')) {
    Write-Host 'WARNING: DryRun is off but no AWS credentials are configured - uploads will fail.' -ForegroundColor Yellow
}

if ($svc) {
    Write-Host 'Removing existing service registration...' -ForegroundColor Yellow
    sc.exe delete $ServiceName | Out-Null
    Start-Sleep -Seconds 2
}

Write-Host "Creating Windows Service '$ServiceName'..." -ForegroundColor Yellow
if ($LogOnAccount) {
    sc.exe create $ServiceName binPath= "`"$BinaryPath`"" start= auto DisplayName= "$DisplayName" `
        obj= "$LogOnAccount" password= "$LogOnPassword" | Out-Null
    Write-Host "  running as $LogOnAccount" -ForegroundColor Gray
} else {
    sc.exe create $ServiceName binPath= "`"$BinaryPath`"" start= auto DisplayName= "$DisplayName" | Out-Null
    Write-Host '  running as LocalSystem' -ForegroundColor Gray
    Write-Host 'WARNING: LocalSystem reaches other machines as the COMPUTER account, which' -ForegroundColor Yellow
    Write-Host "         \\maba-priority will usually refuse. The worker would then log" -ForegroundColor Yellow
    Write-Host '         "could not be listed" every cycle and sync nothing. Prefer -LogOnAccount.' -ForegroundColor Yellow
}
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: Failed to create service (exit $LASTEXITCODE)" -ForegroundColor Red; exit 1 }

sc.exe description $ServiceName $Description | Out-Null
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
Write-Host "  archive : $ArchiveRoot" -ForegroundColor Gray
Write-Host "  bucket  : $BucketName" -ForegroundColor Gray
Write-Host "  source  : $SourceId $(if ($SourceId -eq 1) { '(MABA)' } else { '(SEPHARM)' })" -ForegroundColor Gray
Write-Host "  dry run : $DryRun" -ForegroundColor $(if ($DryRun -eq 'true') { 'Yellow' } else { 'Gray' })

# The worker has no HTTP endpoint, so "is it running" is not the same as "is it working".
Write-Host ''
Write-Host 'It syncs on a one-hour cycle. To confirm the first cycle actually did something:' -ForegroundColor Cyan
Write-Host '  Get-EventLog -LogName Application -Source .NET* -Newest 20' -ForegroundColor Gray
Write-Host '  ...or query the index directly:' -ForegroundColor Gray
Write-Host '  SELECT COUNT(*) FROM dbo.CalibrationReportFile WHERE IsDeleted = 0;' -ForegroundColor Gray
if ($DryRun -eq 'true') {
    Write-Host ''
    Write-Host 'DryRun is ON: nothing will be uploaded or written until you re-run with -DryRun false.' -ForegroundColor Yellow
}
