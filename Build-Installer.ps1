# Calibration Software - Installer Builder
# Builds Next.js app + ConsoleHost, then compiles an Inno Setup .exe installer
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File Build-Installer.ps1
#   powershell -ExecutionPolicy Bypass -File Build-Installer.ps1 -Version 1.2.3

param(
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Definition

function Write-Step([int]$N, [int]$Total, [string]$Msg) {
    Write-Host "`n[$N/$Total] $Msg" -ForegroundColor Cyan
}
function Write-OK([string]$Msg)   { Write-Host "  OK  $Msg" -ForegroundColor Green }
function Write-Fail([string]$Msg) { Write-Host "  FAIL $Msg" -ForegroundColor Red; exit 1 }

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host "  Calibration Software - Installer Builder v$Version" -ForegroundColor Cyan
Write-Host "======================================================`n" -ForegroundColor Cyan

# ─── Step 1: Locate tools ────────────────────────────────────────────────────

Write-Step 1 5 "Locating build tools..."

# pnpm
$PnpmCmd = Get-Command pnpm -ErrorAction SilentlyContinue
$PnpmCandidates = @(
    "C:\Users\$env:USERNAME\AppData\Local\pnpm\pnpm.CMD",
    "C:\Users\$env:USERNAME\AppData\Local\pnpm\pnpm.cmd",
    (Get-ChildItem "C:\Users\$env:USERNAME\AppData\Local\pnpm\.tools\pnpm" -Filter "pnpm.CMD" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName),
    $(if ($PnpmCmd) { $PnpmCmd.Source } else { $null })
)
$Pnpm = $PnpmCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $Pnpm) { Write-Fail "pnpm not found. Install with: npm i -g pnpm" }
Write-OK "pnpm: $Pnpm"

# MSBuild
$MsbuildCmd = Get-Command msbuild -ErrorAction SilentlyContinue
$MsbuildCandidates = @(
    "C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files\Microsoft Visual Studio\18\Professional\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files\Microsoft Visual Studio\18\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe",
    $(if ($MsbuildCmd) { $MsbuildCmd.Source } else { $null })
)
$MSBuild = $MsbuildCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $MSBuild) { Write-Fail "MSBuild.exe not found. Install Visual Studio Build Tools." }
Write-OK "MSBuild: $MSBuild"

# ─── Step 2: Build Next.js (standalone) ───────────────────────────────────────

Write-Step 2 5 "Building Next.js app (standalone output)..."
$AppDir = Join-Path $Root "app"
if (-not (Test-Path $AppDir)) { Write-Fail "app directory not found at: $AppDir" }

Push-Location $AppDir
try {
    $env:SKIP_ENV_VALIDATION = "1"
    # Run pnpm build - temporarily allow stderr without halting
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    cmd /c "`"$Pnpm`" build" 2>&1
    $buildExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
    if ($buildExit -ne 0) {
        Write-Fail "pnpm build failed (exit $buildExit)"
    }
} finally {
    Pop-Location
    Remove-Item Env:\SKIP_ENV_VALIDATION -ErrorAction SilentlyContinue
}

$StandaloneDir = Join-Path $AppDir ".next\standalone"
if (-not (Test-Path $StandaloneDir)) {
    Write-Fail "Standalone output not found at $StandaloneDir. Ensure output:'standalone' is set in next.config.js"
}
Write-OK "Next.js standalone build complete"

# ─── Step 3: Build ConsoleHost (Release) ──────────────────────────────────────

Write-Step 3 5 "Building VCT Console Host + CalibrationLauncher (Release)..."
$CsProjPath = Join-Path $Root "Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\ComServer.Hosts.ConsoleHost.csproj"
if (-not (Test-Path $CsProjPath)) { Write-Fail "ConsoleHost .csproj not found at: $CsProjPath" }

$result = & $MSBuild $CsProjPath /p:Configuration=Release /t:Build /v:quiet 2>&1
if ($LASTEXITCODE -ne 0) {
    $result | Where-Object { $_ -match "error" } | ForEach-Object { Write-Host $_ }
    Write-Fail "MSBuild failed (exit $LASTEXITCODE)"
}

$ReleaseDir = Join-Path $Root "Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Release"
if (-not (Test-Path "$ReleaseDir\Maba.VCT.CommServer.Hosts.ConsoleHost.exe")) {
    Write-Fail "ConsoleHost.exe not found in Release output: $ReleaseDir"
}
Write-OK "ConsoleHost Release build complete"

$LauncherProj = Join-Path $Root "Installer\CalibrationLauncher\CalibrationLauncher.csproj"
if (-not (Test-Path $LauncherProj)) { Write-Fail "CalibrationLauncher .csproj not found at: $LauncherProj" }
$result = & $MSBuild $LauncherProj /p:Configuration=Release /t:Build /v:quiet 2>&1
if ($LASTEXITCODE -ne 0) {
    $result | Where-Object { $_ -match "error" } | ForEach-Object { Write-Host $_ }
    Write-Fail "CalibrationLauncher MSBuild failed (exit $LASTEXITCODE)"
}
$LauncherExe = Join-Path $Root "Installer\CalibrationLauncher\bin\Release\CalibrationLauncher.exe"
if (-not (Test-Path $LauncherExe)) { Write-Fail "CalibrationLauncher.exe not found: $LauncherExe" }
Write-OK "CalibrationLauncher Release build complete"

# ─── Step 4: Ensure Inno Setup is installed ───────────────────────────────────

Write-Step 4 5 "Checking for Inno Setup..."

$IsccCandidates = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
)
$Iscc = $IsccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $Iscc) {
    Write-Host "  Inno Setup not found. Downloading..." -ForegroundColor Yellow
    $InnoInstaller = Join-Path $env:TEMP "innosetup.exe"
    $InnoUrl = "https://files.jrsoftware.org/is/6/innosetup-6.7.1.exe"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $InnoUrl -OutFile $InnoInstaller -UseBasicParsing
        Write-Host "  Installing Inno Setup silently..." -ForegroundColor Yellow
        Start-Process -FilePath $InnoInstaller -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait
        Remove-Item $InnoInstaller -ErrorAction SilentlyContinue
    } catch {
        Write-Fail "Failed to download/install Inno Setup: $_`nPlease install manually from https://jrsoftware.org/isdl.php"
    }
    $Iscc = $IsccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $Iscc) { Write-Fail "Inno Setup installation failed. Please install manually." }
}
Write-OK "Inno Setup: $Iscc"

# ─── Step 5: Compile installer ────────────────────────────────────────────────

Write-Step 5 5 "Compiling installer with Inno Setup..."
$IssFile = Join-Path $Root "Installer\setup.iss"
if (-not (Test-Path $IssFile)) { Write-Fail "setup.iss not found at: $IssFile" }

# Patch version in .iss
(Get-Content $IssFile) -replace '#define AppVersion ".*"', "#define AppVersion `"$Version`"" |
    Set-Content $IssFile -Encoding UTF8

Push-Location (Join-Path $Root "Installer")
try {
    $result = & $Iscc "setup.iss" 2>&1
    if ($LASTEXITCODE -ne 0) {
        $result | ForEach-Object { Write-Host $_ }
        Write-Fail "ISCC compilation failed (exit $LASTEXITCODE)"
    }
} finally {
    Pop-Location
}

$OutputExe = Join-Path $Root "Installer\CalibrationSoftware-Setup-v$Version.exe"
if (-not (Test-Path $OutputExe)) {
    Write-Fail "Expected installer not found: $OutputExe"
}

$SizeMB = [math]::Round((Get-Item $OutputExe).Length / 1MB, 1)

Write-Host "`n======================================================" -ForegroundColor Green
Write-Host "  BUILD SUCCESSFUL" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  Installer: $OutputExe" -ForegroundColor White
Write-Host "  Size:      $SizeMB MB" -ForegroundColor White
Write-Host "======================================================`n" -ForegroundColor Green
