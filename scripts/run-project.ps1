$ServiceName = "MabaCalibrationServer"

# Resolve root: installed layout keeps it at $PSScriptRoot (has consolehost\ / webapp\);
# a dev scripts\ folder steps up one level. Installed behavior is unchanged.
$Root = $PSScriptRoot
if (-not (Test-Path (Join-Path $Root 'consolehost')) -and -not (Test-Path (Join-Path $Root 'Systems'))) {
    $Root = Split-Path $PSScriptRoot -Parent
}

Write-Host "--- Maba Calibration Project Starter ---" -ForegroundColor Cyan

# ─── 1. Start the server ────────────────────────────────────────────────────

$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if ($svc) {
    Write-Host "Checking service $ServiceName..."
    if ($svc.Status -ne "Running") {
        Write-Host "Starting service $ServiceName..." -ForegroundColor Yellow
        Start-Service -Name $ServiceName
        Start-Sleep -Seconds 3
    } else {
        Write-Host "Service $ServiceName is already running." -ForegroundColor Green
    }
} else {
    # Service not installed - fall back to running the exe directly
    Write-Host "Service not installed. Starting server directly..." -ForegroundColor Yellow

    # Kill anything already on port 8765
    $port8765 = Get-NetTCPConnection -LocalPort 8765 -ErrorAction SilentlyContinue
    if ($port8765) {
        Stop-Process -Id $port8765.OwningProcess -Force -ErrorAction SilentlyContinue
    }

    # Try installed path first, then dev Release, then dev Debug
    $exePaths = @(
        (Join-Path $Root "consolehost\Maba.VCT.CommServer.Hosts.ConsoleHost.exe"),
        (Join-Path $Root "Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Release\Maba.VCT.CommServer.Hosts.ConsoleHost.exe"),
        (Join-Path $Root "Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Debug\Maba.VCT.CommServer.Hosts.ConsoleHost.exe")
    )
    $exePath = $exePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($exePath) {
        Start-Process $exePath -WindowStyle Normal
        Start-Sleep -Seconds 3
    } else {
        Write-Error "Server binary not found. Build the project first (Release configuration)."
        exit 1
    }
}

# ─── 2. Start the web app ────────────────────────────────────────────────────

# Kill anything already on port 3000
$port3000 = Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue
if ($port3000) {
    Write-Host "Freeing port 3000..." -ForegroundColor Yellow
    Stop-Process -Id $port3000.OwningProcess -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# Installed mode: webapp/server.js (standalone Next.js)
$StandaloneServer = Join-Path $Root "webapp\server.js"
if (Test-Path $StandaloneServer) {
    Write-Host "Starting standalone web app..." -ForegroundColor Cyan
    $cmdArgs = "/k node `"$StandaloneServer`""
    Start-Process "cmd" -ArgumentList $cmdArgs
} else {
    # Dev mode: use pnpm/npm dev server
    $AppFolder = Join-Path $Root "app"
    if (-not (Test-Path $AppFolder)) {
        Write-Error "Web app folder not found at $AppFolder"
        exit 1
    }

    $manager = if (Get-Command pnpm -ErrorAction SilentlyContinue) { "pnpm" } else { "npm" }
    Write-Host "Starting dev web app with $manager..." -ForegroundColor Cyan

    if (-not (Test-Path "$AppFolder\node_modules")) {
        Write-Host "Installing dependencies..."
        Push-Location $AppFolder
        & $manager install
        Pop-Location
    }

    $cmdArgs = "/k cd /d `"$AppFolder`" && $manager dev"
    Start-Process "cmd" -ArgumentList $cmdArgs
}

# ─── 3. Open browser ────────────────────────────────────────────────────────
Start-Sleep -Seconds 2
Write-Host "Opening browser at http://localhost:3000..." -ForegroundColor Cyan
Start-Process "http://localhost:3000"

Write-Host "`nAll components started!" -ForegroundColor Green
Write-Host "  Web App:   http://localhost:3000" -ForegroundColor White
Write-Host "  WebSocket: ws://localhost:8765" -ForegroundColor White
