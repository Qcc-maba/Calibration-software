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
    Connection string to the Calibrator database. Omit to keep the one already configured.

.PARAMETER ServiceAccount
    Domain account to run as, e.g. MBA\svc-attachments. Strongly recommended: LocalSystem cannot
    read \\maba-priority. Omit to keep the current account (LocalSystem on a fresh install).

.PARAMETER ServiceAccountPassword
    Password for -ServiceAccount.

.PARAMETER Port
    TCP port. Default 5312.

.PARAMETER CacheDirectory
    Where converted PDFs are kept. Default C:\ProgramData\Maba\OrderAttachments\pdf-cache.

.PARAMETER LibreOfficePath
    soffice.exe. Default C:\Program Files\LibreOffice\program\soffice.exe.

.PARAMETER SkipBrowserInstall
    Do not download Chromium. Only when it is already present at the machine-wide path.

.EXAMPLE
    .\Install-OrderAttachments-Service.ps1 -CalibratorConnectionString "Server=...;Database=Calibrator;..." -ServiceAccount 'MBA\svc-attachments' -ServiceAccountPassword (Read-Host -AsSecureString)

.EXAMPLE
    # Upgrade the binaries only; everything already configured
    .\Install-OrderAttachments-Service.ps1
#>
param(
    [string] $CalibratorConnectionString,
    [string] $ServiceAccount,
    [System.Security.SecureString] $ServiceAccountPassword,
    [int]    $Port = 5312,
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
# Set the variable for THIS process too: playwright.ps1 below reads it from the environment, and
# a machine-scope variable is not visible to an already-running shell.
[Environment]::SetEnvironmentVariable('PLAYWRIGHT_BROWSERS_PATH', $BrowsersPath, 'Machine')
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

Write-Host 'Applying machine-scope configuration...' -ForegroundColor Yellow
Set-MachineVar 'ConnectionStrings__Calibrator' $CalibratorConnectionString -Secret
Set-MachineVar 'OrderAttachments__CacheDirectory' $CacheDirectory
Set-MachineVar 'OrderAttachments__LibreOfficePath' $LibreOfficePath
Set-MachineVar 'ASPNETCORE_URLS' "http://localhost:$Port"

$effectiveConn = [Environment]::GetEnvironmentVariable('ConnectionStrings__Calibrator', 'Machine')
if (-not $effectiveConn) {
    Write-Host 'ERROR: no machine-scope Calibrator connection string. The service will not start.' -ForegroundColor Red
    Write-Host '       Pass -CalibratorConnectionString.' -ForegroundColor Red
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

Write-Host "Creating Windows Service '$ServiceName'..." -ForegroundColor Yellow
if ($ServiceAccount) {
    if (-not $ServiceAccountPassword) {
        Write-Host 'ERROR: -ServiceAccount needs -ServiceAccountPassword.' -ForegroundColor Red
        exit 1
    }
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringUni(
        [Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($ServiceAccountPassword))
    sc.exe create $ServiceName binPath= "`"$BinaryPath`"" start= auto `
        DisplayName= "$DisplayName" obj= "$ServiceAccount" password= "$plain" | Out-Null
    $createExit = $LASTEXITCODE
    $plain = $null
    Write-Host "  running as: $ServiceAccount" -ForegroundColor Gray
} else {
    sc.exe create $ServiceName binPath= "`"$BinaryPath`"" start= auto DisplayName= "$DisplayName" | Out-Null
    $createExit = $LASTEXITCODE
    Write-Host '  running as: LocalSystem' -ForegroundColor Yellow
    Write-Host '  WARNING: LocalSystem cannot read \\maba-priority. Every conversion will fail.' -ForegroundColor Yellow
    Write-Host '           Re-run with -ServiceAccount <domain user>, or set the account in' -ForegroundColor Yellow
    Write-Host '           services.msc > Log On.' -ForegroundColor Yellow
}
if ($createExit -ne 0) { Write-Host "ERROR: Failed to create service (exit $createExit)" -ForegroundColor Red; exit 1 }

sc.exe description $ServiceName $Description | Out-Null
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
