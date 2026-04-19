<#
.SYNOPSIS
  Stops existing Com Server + web dev processes, then starts the VCT ConsoleHost and the Next.js app.

.DESCRIPTION
  - Tries to stop Windows service MabaCalibrationServer (needs elevation if it was started as a service).
  - Force-stops Maba.VCT.CommServer.Hosts.ConsoleHost.exe (Debug console or stray instances).
  - Frees TCP port 3000 (typical Next.js dev).
  - Starts Com Server from bin\Debug (preferred for local dev), then opens a new window running pnpm dev in .\app

.PARAMETER BuildServer
  Run dotnet msbuild on ComServer.Hosts.ConsoleHost (Debug) before starting the exe.

.PARAMETER NoBrowser
  Do not open http://localhost:3000 after the web command starts.

.PARAMETER UseWindowsService
  After cleanup, start MabaCalibrationServer instead of the Debug exe (installed layout).

.EXAMPLE
  .\Start-Calibration-Stack.ps1

.EXAMPLE
  .\Start-Calibration-Stack.ps1 -BuildServer
#>
[CmdletBinding()]
param(
    [switch] $BuildServer,
    [switch] $NoBrowser,
    [switch] $UseWindowsService
)

$ErrorActionPreference = "Continue"
$root = $PSScriptRoot

function Stop-ListenerOnPort {
    param([int] $Port)
    $conns = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    if (-not $conns) { return }
    $pids = $conns | Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($procId in $pids) {
        if ($procId -lt 1) { continue }
        try {
            Stop-Process -Id $procId -Force -ErrorAction Stop
            Write-Host "Stopped process $procId (was listening on port $Port)." -ForegroundColor Yellow
        }
        catch {
            Write-Host "Could not stop PID $procId on port $Port : $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
    }
}

Write-Host "`n=== Calibration stack: stop previous, then start ===" -ForegroundColor Cyan

# --- 1) Stop Windows service (best effort; admin required if service is running elevated) ---
$svc = Get-Service -Name "MabaCalibrationServer" -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq "Running") {
    Write-Host "Stopping Windows service MabaCalibrationServer..." -ForegroundColor Yellow
    try {
        Stop-Service -Name "MabaCalibrationServer" -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Host "Stop-Service failed (try Administrator: net stop MabaCalibrationServer): $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}

# --- 2) Kill any ConsoleHost exe (covers Debug runs after service stopped) ---
Write-Host "Stopping Maba.VCT.CommServer.Hosts.ConsoleHost.exe (if any)..." -ForegroundColor Yellow
$null = & taskkill.exe /F /IM "Maba.VCT.CommServer.Hosts.ConsoleHost.exe" 2>&1
Start-Sleep -Seconds 1

# --- 3) Free web dev port ---
Write-Host "Freeing port 3000 (Next dev)..." -ForegroundColor Yellow
Stop-ListenerOnPort -Port 3000
Start-Sleep -Milliseconds 500

# --- 4) Optional build ---
$csproj = Join-Path $root "Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\ComServer.Hosts.ConsoleHost.csproj"
$debugExe = Join-Path $root "Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Debug\Maba.VCT.CommServer.Hosts.ConsoleHost.exe"
$releaseExe = Join-Path $root "Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Release\Maba.VCT.CommServer.Hosts.ConsoleHost.exe"
$installedExe = Join-Path $root "consolehost\Maba.VCT.CommServer.Hosts.ConsoleHost.exe"

if ($BuildServer) {
    if (-not (Test-Path $csproj)) {
        Write-Error "Project not found: $csproj"
        exit 1
    }
    Write-Host "Building ConsoleHost (Debug)..." -ForegroundColor Cyan
    & dotnet msbuild $csproj /p:Configuration=Debug /v:m
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed."
        exit $LASTEXITCODE
    }
}

# --- 5) Start Com Server ---
if ($UseWindowsService) {
    if (-not $svc) {
        Write-Error "Service MabaCalibrationServer not found."
        exit 1
    }
    Write-Host "Starting Windows service MabaCalibrationServer..." -ForegroundColor Cyan
    Start-Service -Name "MabaCalibrationServer"
    Start-Sleep -Seconds 3
}
else {
    $exePath = $null
    if (Test-Path $debugExe) { $exePath = $debugExe }
    elseif (Test-Path $releaseExe) { $exePath = $releaseExe }
    elseif (Test-Path $installedExe) { $exePath = $installedExe }

    if (-not $exePath) {
        Write-Error "Com Server exe not found. Build first or run with -BuildServer. Expected under:`n  $debugExe"
        exit 1
    }

    Write-Host "Starting Com Server: $exePath" -ForegroundColor Cyan
    Start-Process -FilePath $exePath -WorkingDirectory (Split-Path $exePath) -WindowStyle Normal
    Start-Sleep -Seconds 4
}

# --- 6) Start web app (pnpm preferred) ---
$appDir = Join-Path $root "app"
$standalone = Join-Path $root "webapp\server.js"

if (Test-Path $standalone) {
    Write-Host "Starting standalone web (node server.js)..." -ForegroundColor Cyan
    $webappDir = Join-Path $root "webapp"
    $cmdArgs = @("/k", "cd /d `"$webappDir`" && node server.js")
    Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArgs
}
elseif (Test-Path $appDir) {
    $mgr = if (Get-Command pnpm -ErrorAction SilentlyContinue) { "pnpm" }
           elseif (Get-Command npm -ErrorAction SilentlyContinue) { "npm" }
           else { $null }
    if (-not $mgr) {
        Write-Error "Neither pnpm nor npm found in PATH."
        exit 1
    }

    if (-not (Test-Path (Join-Path $appDir "node_modules"))) {
        Write-Host "Installing app dependencies ($mgr install)..." -ForegroundColor Yellow
        Push-Location $appDir
        & $mgr install
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            Write-Error "Dependency install failed."
            exit $LASTEXITCODE
        }
        Pop-Location
    }

    Write-Host "Starting web app in new window: $mgr dev" -ForegroundColor Cyan
    $cmdArgs = @("/k", "cd /d `"$appDir`" && $mgr dev")
    Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArgs
}
else {
    Write-Error "Web app not found. Expected .\app or .\webapp\server.js"
    exit 1
}

if (-not $NoBrowser) {
    Start-Sleep -Seconds 2
    Write-Host "Opening http://localhost:3000 ..." -ForegroundColor Cyan
    Start-Process "http://localhost:3000"
}

Write-Host "`nDone." -ForegroundColor Green
Write-Host "  Web:        http://localhost:3000" -ForegroundColor White
Write-Host "  WebSocket:  ws://localhost:5001/ws/  (match NEXT_PUBLIC_WEBSOCKET_URL in app\.env.local)" -ForegroundColor White
Write-Host "  Server log: Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\logs\server.log" -ForegroundColor DarkGray
