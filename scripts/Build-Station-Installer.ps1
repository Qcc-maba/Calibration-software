# Builds CalibrationSoftware-Setup-v<version>.exe for a calibration station, pointing both the
# ComServer and the webapp at one database. Defaults are AWS CalibratorProd: the topology is
# Priority -> on-prem (kyulan) -> AWS -> station, so the station reads from AWS. The database
# parameters exist because an on-prem copy (CalibratorLocal on MABA-PRIORITY\PRI) was tried on
# 2026-09-07 and abandoned - nothing fed it and nothing read it back.
#
# What it does, in order (each step stops the script if it fails):
#   0. Records the Calibration-software and web app commits, and refuses to build from a checkout
#      with uncommitted changes (-AllowDirty overrides it and marks the build dirty) - a recorded
#      commit only describes the build if nothing else went into it.
#   1. Points the ComServer's App.config at the database (the .exe.config in bin\Release is
#      regenerated from it by the build, so editing the built copy would not survive).
#   2. Regenerates Installer\assets\.env.station with the matching Prisma URL.
#   3. Rebuilds ComServer.Hosts.ConsoleHost (Release) so the shipped .exe.config carries step 1.
#   4. Compiles the installer with ISCC, taking the webapp from the standalone build.
#   5. Checks the payload size: a good build compresses ~2,400+ files; ~18 means the webapp
#      silently did not make it in.
#
# The commits go into {app}\build-info.json on the station, and into
# Installer\CalibrationSoftware-Setup-v<version>.build-info.json beside the exe, together with its
# SHA-256. scripts\Tag-StationRelease.ps1 tags a shipped release from that file, and
# scripts\Get-StationReleaseChanges.ps1 lists what was merged since the last tag.
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
    [string]$WebAppRoot = 'C:\tmp\maba-app',
    # Build from checkouts with uncommitted changes anyway. The build is marked dirty, and
    # Tag-StationRelease.ps1 refuses to tag it: for trying something out, never for shipping.
    [switch]$AllowDirty
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$msbuild = 'C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe'
# Not every build machine has Community: ask vswhere for any VS 18 edition (BuildTools included).
# Pinned to 18 because SSMS registers its own MSBuild with vswhere, and -latest would pick it.
$vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path $msbuild) -and (Test-Path $vswhere)) {
    $found = & $vswhere -version '[18.0,19.0)' -products '*' -requires Microsoft.Component.MSBuild -latest -find 'MSBuild\Current\Bin\MSBuild.exe' | Select-Object -First 1
    if ($found) { $msbuild = $found }
}
$iscc    = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
# `winget install JRSoftware.InnoSetup` without admin rights installs per user, under LocalAppData.
$isccUser = Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'
if (-not (Test-Path $iscc) -and (Test-Path $isccUser)) { $iscc = $isccUser }
foreach ($tool in @($msbuild, $iscc)) {
    if (-not (Test-Path $tool)) { throw "Missing tool: $tool" }
}

$standalone = Join-Path $WebAppRoot '.next\standalone'
$static     = Join-Path $WebAppRoot '.next\static'
$public     = Join-Path $WebAppRoot 'public'
# Files that exist only to make a build and carry secrets. Deleted once ISCC has packed what it needs,
# or as soon as the build fails - they are all gitignored, so nothing else would ever flag them.
$builtConfigPath = Join-Path $root 'Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Release\Maba.VCT.CommServer.Hosts.ConsoleHost.exe.config'
function Remove-BuildSecrets {
    $paths = @(
        (Join-Path $root 'Installer\assets\.env.station'),   # production DB password
        $builtConfigPath                                      # production DB password
    )
    # The web app's .env is only a build-time copy in a throwaway clone. Never delete it from a
    # developer's own checkout, in case -WebAppRoot points at one.
    $webAppRootFull = [IO.Path]::GetFullPath($WebAppRoot).TrimEnd('\')
    $devCheckouts = @((Join-Path $root 'app'), (Join-Path (Split-Path -Parent $root) 'app')) |
        ForEach-Object { [IO.Path]::GetFullPath($_).TrimEnd('\') }
    if ($devCheckouts -notcontains $webAppRootFull) { $paths += Join-Path $WebAppRoot '.env' }

    foreach ($p in $paths) {
        if (Test-Path $p) { Remove-Item $p -Force; Write-Host "      removed $p" }
    }
}

if (-not (Test-Path (Join-Path $standalone 'server.js'))) {
    throw "No standalone webapp build at $standalone - run BUILD_STANDALONE=true SKIP_ENV_VALIDATION=1 npx next build there first."
}

$iss = Join-Path $root 'Installer\setup.iss'
$version = (Select-String -Path $iss -Pattern '^#define AppVersion "([^"]+)"').Matches[0].Groups[1].Value

# ---------------------------------------------------------------------------
# 0. Where the build comes from
# ---------------------------------------------------------------------------
# $Paths limits the check to what the build consumes; $Ignore lists files the build itself rewrites.
function Get-SourceState([string]$Repo, [string[]]$Paths, [string[]]$Ignore = @()) {
    if (-not (Test-Path (Join-Path $Repo '.git'))) {
        return [ordered]@{ commit = $null; branch = $null; dirty = $true; changes = @("$Repo is not a git checkout") }
    }
    $commit = git -C $Repo rev-parse HEAD
    $branch = git -C $Repo rev-parse --abbrev-ref HEAD
    $status = @(git -C $Repo status --porcelain --untracked-files=all -- @Paths)
    if ($LASTEXITCODE -ne 0) { throw "git status failed in $Repo" }
    $changes = @($status | Where-Object { $_ } | Where-Object { $Ignore -notcontains $_.Substring(3) })
    return [ordered]@{ commit = $commit; branch = $branch; dirty = ($changes.Count -gt 0); changes = $changes }
}

Write-Host "[0/5] source commits"
# The server side is whatever the installer compiles or copies; other folders do not reach a station.
$serverSource = Get-SourceState $root @('Systems', 'Libraries', 'Installer', 'scripts')
# `next build` rewrites next-env.d.ts in place, so it is always modified after a build.
$appSource = Get-SourceState $WebAppRoot @('.') @('next-env.d.ts')
foreach ($s in @(@('Calibration-software', $serverSource), @('web app', $appSource))) {
    Write-Host ("      {0,-20} {1} ({2})" -f $s[0], $s[1].commit, $s[1].branch)
    foreach ($c in $s[1].changes) { Write-Host "        uncommitted: $c" }
}
$dirty = $serverSource.dirty -or $appSource.dirty
if ($dirty -and -not $AllowDirty) {
    throw 'Uncommitted changes (listed above) would go into this build, so its commits would not describe it. Commit them, or pass -AllowDirty for a build that will not be shipped.'
}

$buildInfo = [ordered]@{
    version             = $version
    builtAt             = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
    builtOn             = $env:COMPUTERNAME
    database            = "$DbServer,$DbPort/$DbName"
    dirty               = $dirty
    calibrationSoftware = [ordered]@{ commit = $serverSource.commit; branch = $serverSource.branch }
    app                 = [ordered]@{ commit = $appSource.commit; branch = $appSource.branch }
}
function Write-Json([string]$Path, $Object) {
    [IO.File]::WriteAllText($Path, ($Object | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding $false))
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

# From here until the restore, App.config holds the target password in a tracked file. Restore it
# on failure too - an early throw used to leave the production password sitting in the work tree.
try {
    # -----------------------------------------------------------------------
    # 2. Station .env
    # -----------------------------------------------------------------------
    Write-Host "[2/5] Installer\assets\.env.station"
    $encLower = if ($Encrypt) { 'true' } else { 'false' }
    $prismaUrl = "sqlserver://${DbServer}:${DbPort};database=$DbName;user=$DbUser;password=$DbPassword;encrypt=$encLower;trustServerCertificate=true"
    & (Join-Path $PSScriptRoot 'New-StationEnv.ps1') -DatabaseUrl $prismaUrl

    # -----------------------------------------------------------------------
    # 3. ComServer build
    # -----------------------------------------------------------------------
    Write-Host "[3/5] MSBuild ComServer.Hosts.ConsoleHost (Release)"
    & $msbuild (Join-Path $root 'Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\ComServer.Hosts.ConsoleHost.csproj') `
        -restore -p:Configuration=Release -t:Build -v:minimal -nologo
    if ($LASTEXITCODE -ne 0) { throw "MSBuild failed ($LASTEXITCODE)" }

    $builtConfig = Join-Path $root 'Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Release\Maba.VCT.CommServer.Hosts.ConsoleHost.exe.config'
    if ((Get-Content $builtConfig -Raw) -notmatch [regex]::Escape("Database=$DbName")) {
        throw 'Built .exe.config does not carry the target database - App.config edit did not propagate.'
    }

    # setup.iss ships the launcher too. Build-Installer.ps1 always built it; this script used to rely
    # on a copy left in bin\Release by an earlier build, which a fresh machine does not have.
    Write-Host "      MSBuild CalibrationLauncher (Release)"
    & $msbuild (Join-Path $root 'Installer\CalibrationLauncher\CalibrationLauncher.csproj') `
        -restore -p:Configuration=Release -t:Build -v:minimal -nologo
    if ($LASTEXITCODE -ne 0) { throw "CalibrationLauncher MSBuild failed ($LASTEXITCODE)" }
    $binariesBuilt = $true
}
finally {
    # The build has what it needs in bin\Release; put the developer default back in the source tree.
    Set-Content -Path $appConfig -Value $appConfigOriginal -Encoding utf8 -NoNewline
    Write-Host "      App.config restored to its committed (STAGE) default"
    if (-not $binariesBuilt) { Remove-BuildSecrets }
}

# Next copies the web app's .env into the standalone output, and setup.iss packs standalone\* - so
# without this the developer .env (staging passwords, SQL admin string) rides inside the installer.
$standaloneEnv = Join-Path $standalone '.env'
if (Test-Path $standaloneEnv) { Remove-Item $standaloneEnv -Force; Write-Host "      removed $standaloneEnv" }

# ---------------------------------------------------------------------------
# 4. Installer
# ---------------------------------------------------------------------------
Write-Host "[4/5] ISCC"
# Packed as {app}\build-info.json, so an installed station can say which commits it runs.
$packedInfo = Join-Path $root 'Installer\assets\build-info.json'
Write-Json $packedInfo $buildInfo
Push-Location (Join-Path $root 'Installer')
try {
    & $iscc $iss "/DWebAppStandalone=$standalone" "/DWebAppStatic=$static" "/DWebAppPublic=$public" "/DWebAppEnvExample=$(Join-Path $WebAppRoot '.env.example')" | Tee-Object -Variable isccOut | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $isccOut | Select-Object -Last 15
        throw "ISCC failed ($LASTEXITCODE)"
    }
}
finally {
    Pop-Location
    # Packed or failed, nothing needs these any more; the next build regenerates them.
    Remove-BuildSecrets
    # Not a secret, but a stale copy would be packed by a later hand-run ISCC and misname its commits.
    Remove-Item $packedInfo -Force -ErrorAction SilentlyContinue
}

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

# Beside the exe: what Tag-StationRelease.ps1 tags from, and what to copy to the share with it.
$buildInfo.installer = [ordered]@{
    file         = Split-Path $exe -Leaf
    sha256       = (Get-FileHash $exe -Algorithm SHA256).Hash
    sizeBytes    = (Get-Item $exe).Length
    payloadFiles = $compressed
}
$infoFile = [IO.Path]::ChangeExtension($exe, '.build-info.json')
Write-Json $infoFile $buildInfo
Write-Host "Info   : $infoFile"
if ($dirty) { Write-Host "DIRTY  : built with uncommitted changes (-AllowDirty) - not for shipping" }
Write-Host "OK"
