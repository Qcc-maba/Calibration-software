<#
    Unattended updater. Runs on the server as a scheduled task under SYSTEM,
    compares the build published on the share with the installed one, and
    upgrades only when they differ.

    It is deliberately conservative:
      - does nothing at all when the share is unreachable or the build matches
      - refuses to touch files unless the app is really stopped (port is free)
      - rolls back automatically if the new build fails its health check

    Installed by Install-AutoUpdater.ps1; not meant to be run by hand, though
    -CheckOnly is a safe way to see what it would do.

    Output is ASCII on purpose - Windows Server consoles render Hebrew as mojibake.
#>
[CmdletBinding()]
param(
    [string] $Share   = '\\maba-srv\maba2000\Eliran\qcc-latest',
    [string] $Target  = 'C:\apps\qcc-analytics-deploy\app',
    [string] $AppTask = 'QCCAnalytics',
    [string] $LogFile = 'C:\apps\qcc-updater\update.log',
    [int]    $KeepBackups = 3,
    [switch] $CheckOnly
)

$ErrorActionPreference = 'Stop'

# Anything that escapes gets written to the log before the process dies. Without
# this a failure inside a scheduled task leaves no trace anywhere the operator
# would think to look.
trap {
    try { Log "FATAL: $($_.Exception.Message)" } catch { }
    exit 1
}

function Log($text) {
    $line = "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $text
    Write-Host $line
    try {
        $dir = Split-Path -Parent $LogFile
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt 1MB) {
            Move-Item $LogFile "$LogFile.old" -Force
        }
        Add-Content -Path $LogFile -Value $line -Encoding ascii
    } catch { }
}

function Get-Port {
    $envPath = Join-Path $Target '.env'
    if (Test-Path $envPath) {
        $m = [regex]::Match((Get-Content $envPath -Raw), '(?m)^\s*PORT\s*=\s*(\d+)')
        if ($m.Success) { return [int]$m.Groups[1].Value }
    }
    5000
}

function Stop-App($port) {
    Stop-ScheduledTask -TaskName $AppTask -ErrorAction SilentlyContinue
    Stop-Service -Name $AppTask -Force -ErrorAction SilentlyContinue
    foreach ($i in 1..30) {
        Start-Sleep -Seconds 1
        if (-not (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)) { return $true }
    }
    $false
}

function Start-App($port) {
    if (Get-Service -Name $AppTask -ErrorAction SilentlyContinue) { Start-Service -Name $AppTask }
    else { Start-ScheduledTask -TaskName $AppTask }
    foreach ($i in 1..30) {
        Start-Sleep -Seconds 2
        try { if ((Invoke-WebRequest "http://localhost:$port/" -TimeoutSec 10 -UseBasicParsing).StatusCode -eq 200) { return $true } } catch { }
    }
    $false
}

# ------------------------------------------------------------------ compare
$sharedBuild    = Join-Path $Share 'payload\dist\index.cjs'
$installedBuild = Join-Path $Target 'dist\index.cjs'

# Test-Path on a UNC path THROWS on a permission error instead of returning
# false, and with ErrorActionPreference=Stop that killed the run before a single
# line was logged - the failure looked like the task never started at all.
$shareOk = $false
$shareErr = ''
try { $shareOk = Test-Path $Share -ErrorAction Stop } catch { $shareErr = $_.Exception.Message }

if (-not $shareOk) {
    # The task runs as SYSTEM, i.e. the machine account. If the share does not
    # grant it read access this is where it shows up, every time, harmlessly.
    Log "share not reachable ($Share) - nothing to do$(if ($shareErr) { ": $shareErr" })"
    Log "running as: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    exit 0
}
if (-not (Test-Path $sharedBuild))    { Log "no build published at $sharedBuild - nothing to do"; exit 0 }
if (-not (Test-Path $installedBuild)) { Log "no installed build at $installedBuild - aborting"; exit 1 }

$new = (Get-FileHash $sharedBuild -Algorithm MD5).Hash
$cur = (Get-FileHash $installedBuild -Algorithm MD5).Hash
if ($new -eq $cur) { Log "up to date ($cur)"; exit 0 }

Log "update available: installed $cur -> published $new"
if ($CheckOnly) { Log 'CheckOnly - stopping here'; exit 0 }

# ------------------------------------------------------------------ apply
$port  = Get-Port
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $Target "dist_bak_$stamp"

Log "stopping $AppTask (port $port)"
if (-not (Stop-App $port)) {
    $holder = (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -First 1).OwningProcess
    Log "ABORT: port $port still held by process $holder - nothing was changed"
    Start-App $port | Out-Null
    exit 1
}

try {
    Copy-Item (Join-Path $Target 'dist') $backup -Recurse -Force
    Log "backed up to $backup"

    Remove-Item (Join-Path $Target 'dist') -Recurse -Force
    Copy-Item (Join-Path $Share 'payload\dist') (Join-Path $Target 'dist') -Recurse -Force
    Log ('installed {0:N0} bytes' -f (Get-Item $installedBuild).Length)

    # Seed data only: never overwrite, the learned matches live here.
    $sharedData = Join-Path $Share 'payload\data\pricing'
    $localData  = Join-Path $Target 'data\pricing'
    if (Test-Path $sharedData) {
        if (-not (Test-Path $localData)) { New-Item -ItemType Directory -Path $localData -Force | Out-Null }
        Get-ChildItem $sharedData -File | ForEach-Object {
            $dest = Join-Path $localData $_.Name
            if (-not (Test-Path $dest)) { Copy-Item $_.FullName $dest; Log "added data file $($_.Name)" }
        }
    }

    # New settings only. Existing values are left alone - an unattended job must
    # not silently change a password or a connection string someone else set.
    $additions = Join-Path $Share 'env-additions.txt'
    $envPath   = Join-Path $Target '.env'
    if ((Test-Path $additions) -and (Test-Path $envPath)) {
        $existing = @(Get-Content $envPath)
        $toAdd = @()
        foreach ($line in (Get-Content $additions)) {
            if ($line -notmatch '^\s*([A-Z_]+)=') { continue }
            $key = $Matches[1]
            if (-not ($existing -match "^\s*$key=")) { $toAdd += $line }
        }
        if ($toAdd.Count -gt 0) {
            Copy-Item $envPath (Join-Path $Target ".env.bak_$stamp") -Force
            Add-Content $envPath ''
            Add-Content $envPath "# --- added by the updater $stamp ---"
            $toAdd | ForEach-Object { Add-Content $envPath $_ }
            Log ('added settings: ' + (($toAdd | ForEach-Object { ($_ -split '=')[0] }) -join ', '))
        }
    }
}
catch {
    Log "ERROR while installing: $($_.Exception.Message)"
    if (Test-Path $backup) {
        Remove-Item (Join-Path $Target 'dist') -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item $backup (Join-Path $Target 'dist') -Recurse -Force
        Log 'rolled back to the previous build'
    }
    Start-App $port | Out-Null
    exit 1
}

# ------------------------------------------------------------------ verify
Log 'starting'
$up = Start-App $port
$ok = $up
if ($up) {
    try {
        $h = Invoke-RestMethod "http://localhost:$port/api/pricing/health" -TimeoutSec 30
        if ($h.itemsLoaded -gt 0) { Log "pricing: $($h.itemsLoaded) price list items" }
        else { Log 'WARN: the price list is empty'; $ok = $false }
    } catch { Log "WARN: pricing health check failed: $($_.Exception.Message)"; $ok = $false }
} else {
    Log 'the app did not answer after the update'
}

if (-not $ok) {
    Log 'health check failed - rolling back'
    Stop-App $port | Out-Null
    Remove-Item (Join-Path $Target 'dist') -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item $backup (Join-Path $Target 'dist') -Recurse -Force
    if (Start-App $port) { Log 'rolled back and running the previous build' }
    else { Log 'ROLLBACK DID NOT COME UP - manual attention needed' }
    exit 1
}

# keep the last few backups only
Get-ChildItem $Target -Directory -Filter 'dist_bak_*' |
    Sort-Object Name -Descending | Select-Object -Skip $KeepBackups |
    ForEach-Object { Remove-Item $_.FullName -Recurse -Force; Log "removed old backup $($_.Name)" }

Log "UPDATE OK - now running $new"
exit 0
