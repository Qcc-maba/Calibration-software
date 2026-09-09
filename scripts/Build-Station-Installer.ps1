# Builds CalibrationSoftware-Setup-v<version>.exe for a calibration station, pointing both the
# ComServer and the webapp at one database. Defaults are AWS CalibratorProd: the topology is
# Priority -> on-prem (kyulan) -> AWS -> station, so the station reads from AWS. The database
# parameters exist because an on-prem copy (CalibratorLocal on MABA-PRIORITY\PRI) was tried on
# 2026-09-07 and abandoned - nothing fed it and nothing read it back.
#
# What it does, in order (each step stops the script if it fails):
#   1. Points the ComServer's App.config at the database (the .exe.config in bin\Release is
#      regenerated from it by the build, so editing the built copy would not survive).
#   2. Regenerates Installer\assets\.env.station with the matching Prisma URL.
#   3. Rebuilds ComServer.Hosts.ConsoleHost (Release) so the shipped .exe.config carries step 1.
#   4. Compiles the installer with ISCC, taking the webapp from the standalone build.
#   5. Checks the payload size: a good build compresses ~2,400+ files; ~18 means the webapp
#      silently did not make it in.
#
# The webapp itself is NOT built here - it cannot be built under OneDrive (see
# scripts\Build-Installer.ps1 for why) and is expected to be already built in -WebAppRoot.
#
# Console output is ASCII: Windows Server consoles render Hebrew as mojibake.

param(
    [Parameter(Mandatory = $true)]
    [string]$DbPassword,

    [string]$DbServer   = '51.17.121.203',
    [int]$DbPort        = 1433,
    [string]$DbName     = 'CalibratorProd',
    [string]$DbUser     = 'app_prod',
    # AWS presents a certificate the station must encrypt to; a LAN server without one needs $false.
    [bool]$Encrypt      = $true,
    [string]$WebAppRoot = 'C:\tmp\maba-app'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$msbuild = 'C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe'
$iscc    = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
foreach ($tool in @($msbuild, $iscc)) {
    if (-not (Test-Path $tool)) { throw "Missing tool: $tool" }
}

$standalone = Join-Path $WebAppRoot '.next\standalone'
$static     = Join-Path $WebAppRoot '.next\static'
$public     = Join-Path $WebAppRoot 'public'
if (-not (Test-Path (Join-Path $standalone 'server.js'))) {
    throw "No standalone webapp build at $standalone - run BUILD_STANDALONE=true SKIP_ENV_VALIDATION=1 npx next build there first."
}

# ---------------------------------------------------------------------------
# 1. ComServer App.config
# ---------------------------------------------------------------------------
Write-Host "[1/5] App.config -> $DbServer,$DbPort / $DbName as $DbUser"
$appConfig = Join-Path $root 'Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\App.config'
# The committed App.config is the developer default (STAGE) and must stay that way: the target
# below is applied only for the duration of the build and put back afterwards.
$appConfigOriginal = Get-Content $appConfig -Raw -Encoding utf8
$xml = [xml]$appConfigOriginal
$node = $xml.configuration.connectionStrings.add | Where-Object { $_.name -eq 'REMOTE_DATABASE_URL' }
if (-not $node) { throw 'REMOTE_DATABASE_URL entry not found in App.config' }
$enc = if ($Encrypt) { 'True' } else { 'False' }
$node.connectionString = "Server=$DbServer,$DbPort;Database=$DbName;User Id=$DbUser;Password=$DbPassword;Encrypt=$enc;TrustServerCertificate=True;"
$xml.Save($appConfig)

# ---------------------------------------------------------------------------
# 2. Station .env
# ---------------------------------------------------------------------------
Write-Host "[2/5] Installer\assets\.env.station"
$encLower = if ($Encrypt) { 'true' } else { 'false' }
$prismaUrl = "sqlserver://${DbServer}:${DbPort};database=$DbName;user=$DbUser;password=$DbPassword;encrypt=$encLower;trustServerCertificate=true"
& (Join-Path $PSScriptRoot 'New-StationEnv.ps1') -DatabaseUrl $prismaUrl

# ---------------------------------------------------------------------------
# 3. ComServer build
# ---------------------------------------------------------------------------
Write-Host "[3/5] MSBuild ComServer.Hosts.ConsoleHost (Release)"
& $msbuild (Join-Path $root 'Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\ComServer.Hosts.ConsoleHost.csproj') `
    -restore -p:Configuration=Release -t:Build -v:minimal -nologo
if ($LASTEXITCODE -ne 0) { throw "MSBuild failed ($LASTEXITCODE)" }

$builtConfig = Join-Path $root 'Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Release\Maba.VCT.CommServer.Hosts.ConsoleHost.exe.config'
if ((Get-Content $builtConfig -Raw) -notmatch [regex]::Escape("Database=$DbName")) {
    throw 'Built .exe.config does not carry the target database - App.config edit did not propagate.'
}

# The build has what it needs in bin\Release; put the developer default back in the source tree.
Set-Content -Path $appConfig -Value $appConfigOriginal -Encoding utf8 -NoNewline
Write-Host "      App.config restored to its committed (STAGE) default"

# ---------------------------------------------------------------------------
# 4. Installer
# ---------------------------------------------------------------------------
Write-Host "[4/5] ISCC"
$iss = Join-Path $root 'Installer\setup.iss'
$version = (Select-String -Path $iss -Pattern '^#define AppVersion "([^"]+)"').Matches[0].Groups[1].Value
Push-Location (Join-Path $root 'Installer')
try {
    & $iscc $iss "/DWebAppStandalone=$standalone" "/DWebAppStatic=$static" "/DWebAppPublic=$public" | Tee-Object -Variable isccOut | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $isccOut | Select-Object -Last 15
        throw "ISCC failed ($LASTEXITCODE)"
    }
}
finally { Pop-Location }

# ---------------------------------------------------------------------------
# 5. Payload sanity
# ---------------------------------------------------------------------------
Write-Host "[5/5] payload check"
$compressed = ($isccOut | Select-String -Pattern 'Compressing:').Count
$exe = Join-Path $root "Installer\CalibrationSoftware-Setup-v$version.exe"
if (-not (Test-Path $exe)) { throw "Installer not produced: $exe" }
$mb = [math]::Round((Get-Item $exe).Length / 1MB, 1)

Write-Host ""
Write-Host "Built  : $exe  ($mb MB)"
Write-Host "Payload: $compressed file(s) compressed"
if ($compressed -lt 2000) {
    throw "Only $compressed files in the payload - the webapp did not make it in. Do not ship this."
}
Write-Host "OK"
