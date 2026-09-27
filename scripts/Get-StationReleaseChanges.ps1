# Lists what was merged since the last station installer release, in both repositories the
# installer is built from - the input for the next release's START-HERE.txt.
#
# The last release is the highest station-v<version> tag (Tag-StationRelease.ps1). Everything on
# the first-parent history of develop (Calibration-software) and stg (app) after it is listed: one
# line per merged PR, plus any commit that reached the branch without one. For Calibration-software
# each entry says whether it touches what the installer ships - a skill or a database procedure
# does not reach a station. Everything in app ships, since the station runs the whole web app.
#
# Console output is ASCII: Windows Server consoles render Hebrew as mojibake.

param(
    # The web app checkout. Defaults to <root>\app, then the sibling GIT_ROOT\app.
    [string]$AppRepo,
    [string]$ServerRef = 'origin/develop',
    [string]$AppRef    = 'origin/stg',
    # Start from these refs instead of the latest tag - to look at a range by hand.
    [string]$ServerSince,
    [string]$AppSince
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

if (-not $AppRepo) {
    $AppRepo = @((Join-Path $root 'app'), (Join-Path (Split-Path -Parent $root) 'app')) |
        Where-Object { Test-Path (Join-Path $_ 'package.json') } | Select-Object -First 1
    if (-not $AppRepo) { throw 'Web app checkout not found in <root>\app or GIT_ROOT\app - pass -AppRepo.' }
}

# What reaches a station from Calibration-software: the code the ComServer is compiled from, the
# installer itself, and the three scripts setup.iss copies onto the machine. Build tooling under
# scripts\ and Markdown anywhere change nothing an operator sees.
$stationPaths = @('Systems/VCT/', 'Systems/Hydra-Group/', 'Libraries/', 'Installer/',
    'scripts/Install-Service.ps1', 'scripts/Uninstall-Service.ps1', 'scripts/run-project.ps1')
function Test-ReachesStation([string]$Path) {
    if ($Path -like '*.md') { return $false }
    foreach ($p in $stationPaths) { if ($Path.StartsWith($p)) { return $true } }
    return $false
}

function Show-Changes([string]$Name, [string]$Repo, [string]$Ref, [string]$Since, [string]$GitHubRepo, [bool]$ClassifyPaths) {
    git -C $Repo fetch --quiet --tags origin
    if ($LASTEXITCODE -ne 0) { throw "git fetch failed in $Repo" }
    if (-not $Since) {
        $Since = git -C $Repo tag --list 'station-v*' --sort=-v:refname | Select-Object -First 1
        if (-not $Since) { throw "$Name has no station-v* tag yet - tag the last release with Tag-StationRelease.ps1, or pass -ServerSince/-AppSince." }
    }
    $branch = $Ref -replace '^origin/', ''

    Write-Host ""
    Write-Host "=== $Name  $Since..$Ref"
    Write-Host "    https://github.com/$GitHubRepo/compare/$Since...$branch"

    # One record per first-parent commit: hash, date, subject, body. \x1e ends a record, \x1f a field.
    $raw = git -C $Repo log --first-parent --date=short "--format=%H%x1f%ad%x1f%s%x1f%b%x1e" "$Since..$Ref"
    if ($LASTEXITCODE -ne 0) { throw "git log $Since..$Ref failed in $Repo" }
    $records = ($raw -join "`n") -split "\x1e" | Where-Object { $_.Trim() }
    if (-not $records) { Write-Host "    nothing merged since $Since"; return }

    foreach ($rec in $records) {
        $f = $rec.Trim() -split "\x1f"
        $hash = $f[0]; $date = $f[1]; $subject = $f[2]
        $body = if ($f.Count -gt 3) { $f[3] } else { '' }

        if ($subject -match '^Merge pull request #(\d+) from \S+?/(\S+)') {
            $title = ($body -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
            $label = "PR #$($Matches[1])  $(if ($title) { $title.Trim() } else { $Matches[2] })"
        }
        elseif ($subject -match '^(.*\S)\s+\(#(\d+)\)$') {
            # A squash merge: GitHub puts the PR number at the end of the subject.
            $label = "PR #$($Matches[2])  $($Matches[1])"
        }
        else {
            $label = "(no PR)  $subject"
        }

        $where = ''
        if ($ClassifyPaths) {
            # A merge's own change is its diff against the first parent.
            $files = @(git -C $Repo diff --name-only "$hash^1" $hash)
            $touches = @($files | Where-Object { Test-ReachesStation $_ })
            $where = if ($touches.Count -gt 0) { 'station ' } else { '-       ' }
        }
        Write-Host ("    {0} {1} {2}{3}" -f $date, $hash.Substring(0, 7), $where, $label)
    }
}

Show-Changes 'Calibration-software' $root $ServerRef $ServerSince 'Qcc-maba/Calibration-software' $true
Show-Changes 'app' $AppRepo $AppRef $AppSince 'Qcc-maba/app' $false
Write-Host ""
Write-Host "For Calibration-software, 'station' marks changes to what the installer ships; '-' ones stay off the stations."
