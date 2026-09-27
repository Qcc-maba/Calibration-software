# Tags a shipped station installer release in both repositories it is built from:
# station-v<version> on the Calibration-software commit and on the web app (Qcc-maba/app) commit.
# Get-StationReleaseChanges.ps1 then lists everything merged since the latest tag, which is what
# the next release's START-HERE.txt is written from.
#
# Run it once the installer has been handed over, not after every build - a tag says "this is what
# the stations got". The commits come from the build-info file Build-Station-Installer.ps1 writes
# beside the exe; -ServerCommit/-AppCommit name them directly for a release built before that
# file existed (1.6.13).
#
# Refuses, before tagging anything, when:
#   - the build was made with uncommitted changes (-AllowDirty),
#   - the tag already exists, locally or on GitHub,
#   - a commit is not on any branch on GitHub - a tag on a commit nobody else has describes nothing,
#   - setup.iss at the server commit does not carry that version.
#
# Console output is ASCII: Windows Server consoles render Hebrew as mojibake.

param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$ServerCommit,
    [string]$AppCommit,
    # The web app checkout to tag in. Defaults to <root>\app, then the sibling GIT_ROOT\app.
    [string]$AppRepo,
    # Show what would be tagged and pushed, and change nothing.
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$tag = "station-v$Version"

if (-not $AppRepo) {
    $AppRepo = @((Join-Path $root 'app'), (Join-Path (Split-Path -Parent $root) 'app')) |
        Where-Object { Test-Path (Join-Path $_ 'package.json') } | Select-Object -First 1
    if (-not $AppRepo) { throw 'Web app checkout not found in <root>\app or GIT_ROOT\app - pass -AppRepo.' }
}

# ---------------------------------------------------------------------------
# Which commits
# ---------------------------------------------------------------------------
$sha256 = $null
if ($ServerCommit -or $AppCommit) {
    if (-not ($ServerCommit -and $AppCommit)) { throw 'Pass both -ServerCommit and -AppCommit, or neither.' }
    Write-Host "Commits given on the command line (no build-info file)."
}
else {
    $infoFile = Join-Path $root "Installer\CalibrationSoftware-Setup-v$Version.build-info.json"
    if (-not (Test-Path $infoFile)) {
        throw "No $infoFile - build with Build-Station-Installer.ps1, or pass -ServerCommit and -AppCommit."
    }
    $info = Get-Content $infoFile -Raw | ConvertFrom-Json
    if ($info.version -ne $Version) { throw "$infoFile is for version $($info.version), not $Version." }
    if ($info.dirty) { throw "Version $Version was built with uncommitted changes (-AllowDirty). Rebuild from clean checkouts before tagging." }
    $ServerCommit = $info.calibrationSoftware.commit
    $AppCommit = $info.app.commit
    $sha256 = $info.installer.sha256
    Write-Host "Commits from $infoFile"
}

$repos = @(
    [ordered]@{ name = 'Calibration-software'; path = $root; commit = $ServerCommit },
    [ordered]@{ name = 'app'; path = $AppRepo; commit = $AppCommit }
)

# ---------------------------------------------------------------------------
# Check everything before tagging anything
# ---------------------------------------------------------------------------
foreach ($r in $repos) {
    Write-Host "[$($r.name)] $($r.path)"
    git -C $r.path fetch --quiet --tags origin
    if ($LASTEXITCODE -ne 0) { throw "git fetch failed in $($r.path)" }

    $full = git -C $r.path rev-parse --verify --quiet "$($r.commit)^{commit}"
    if (-not $full) { throw "$($r.name): commit $($r.commit) not found." }
    $r.commit = $full

    if (git -C $r.path rev-parse --verify --quiet "refs/tags/$tag") { throw "$($r.name): tag $tag already exists locally." }
    if (git -C $r.path ls-remote --tags origin "refs/tags/$tag") { throw "$($r.name): tag $tag already exists on GitHub." }

    $onRemote = @(git -C $r.path branch -r --contains $full)
    if ($onRemote.Count -eq 0) { throw "$($r.name): $full is not on any branch on GitHub. Push it first." }
    Write-Host "      $full  on $(($onRemote | ForEach-Object { $_.Trim() }) -join ', ')"
}

$issAtCommit = git -C $root show "${ServerCommit}:Installer/setup.iss"
if (-not ($issAtCommit -match "^#define AppVersion `"$([regex]::Escape($Version))`"")) {
    throw "Installer\setup.iss at $ServerCommit does not define AppVersion $Version - wrong commit?"
}

# ---------------------------------------------------------------------------
# Tag and push
# ---------------------------------------------------------------------------
$message = "Station installer $Version`n`nCalibration-software $ServerCommit`napp $AppCommit"
if ($sha256) { $message += "`nCalibrationSoftware-Setup-v$Version.exe SHA-256 $sha256" }

foreach ($r in $repos) {
    if ($WhatIf) {
        Write-Host "WhatIf: git tag -a $tag $($r.commit) in $($r.name), then push it to origin"
        continue
    }
    git -C $r.path tag -a $tag $r.commit -m $message
    if ($LASTEXITCODE -ne 0) { throw "$($r.name): git tag failed" }
    git -C $r.path push --quiet origin "refs/tags/$tag"
    if ($LASTEXITCODE -ne 0) { throw "$($r.name): pushing $tag failed - the local tag exists; push it by hand or delete it with git tag -d $tag" }
    Write-Host "Tagged $($r.name) $tag -> $($r.commit)"
}
if (-not $WhatIf) { Write-Host "OK" }
