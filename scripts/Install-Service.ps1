#Requires -RunAsAdministrator
# Install-Service.ps1 - Installs the Maba Calibration Server as a Windows Service
# Works from both the development folder and the installed folder

$ServiceName    = "MabaCalibrationServer"
$DisplayName    = "Maba Calibration Server"
$WsUrl          = "http://localhost:8765/"

# Resolve root: installed layout & legacy dev keep it at $PSScriptRoot (has consolehost\ or Systems\);
# when this script runs from a dev scripts\ folder, step up one level. Installed behavior unchanged.
$Root = $PSScriptRoot
if (-not (Test-Path (Join-Path $Root 'consolehost')) -and -not (Test-Path (Join-Path $Root 'Systems'))) {
    $Root = Split-Path $PSScriptRoot -Parent
}

# Auto-detect installed vs development path
$InstalledExe = Join-Path $Root "consolehost\Maba.VCT.CommServer.Hosts.ConsoleHost.exe"
$DevExe       = Join-Path $Root "Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Release\Maba.VCT.CommServer.Hosts.ConsoleHost.exe"

if (Test-Path $InstalledExe) {
    $BinaryPath = $InstalledExe
} elseif (Test-Path $DevExe) {
    $BinaryPath = $DevExe
} else {
    Write-Error "Executable not found. Build the project (Release) first."
    exit 1
}

Write-Host "=== Maba Calibration Server - Service Installer ===" -ForegroundColor Cyan
Write-Host "  Binary: $BinaryPath" -ForegroundColor Gray

# Register WebSocket URL for HttpListener
Write-Host "Registering WebSocket URL reservation..." -ForegroundColor Yellow
netsh http add urlacl url=$WsUrl user=Everyone | Out-Null

# Stop and remove existing service if present
$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($svc) {
    if ($svc.Status -eq 'Running') {
        Write-Host "Stopping existing service..." -ForegroundColor Yellow
        Stop-Service -Name $ServiceName -Force
        Start-Sleep -Seconds 3
    }
    Write-Host "Removing existing service registration..." -ForegroundColor Yellow
    sc.exe delete $ServiceName | Out-Null
    Start-Sleep -Seconds 2
}

# Create the service
Write-Host "Creating Windows Service '$ServiceName'..." -ForegroundColor Yellow
sc.exe create $ServiceName binPath= "`"$BinaryPath`"" start= auto DisplayName= "$DisplayName" | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to create service (exit $LASTEXITCODE)" -ForegroundColor Red
    exit 1
}

sc.exe description $ServiceName "Maba VCT Calibration Server - manages device connections and WebSocket communication" | Out-Null

# Start the service
Write-Host "Starting service..." -ForegroundColor Yellow
Start-Service -Name $ServiceName
Start-Sleep -Seconds 3

$svc = Get-Service -Name $ServiceName
if ($svc.Status -eq 'Running') {
    Write-Host "Service '$ServiceName' installed and running successfully." -ForegroundColor Green
} else {
    Write-Host "WARNING: Service installed but status is: $($svc.Status)" -ForegroundColor Yellow
    Write-Host "Check Windows Event Viewer > Windows Logs > Application for errors." -ForegroundColor Yellow
}
