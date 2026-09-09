# Resolves the database connection for this station, then starts the Next.js standalone server.
#
# app\src\env.js declares REMOTE_DATABASE_URL as required (z.string().min(1)) and reads it straight
# from the process environment, with no fallback. The .env shipped by the installer carries only
# REMOTE_DATABASE_URL_PROD and REMOTE_DATABASE_URL_STAGE - the plain name lives in .env.local, a
# development file the installer does not ship - so a fresh install started a server that threw on
# startup before it could listen.
#
# A calibration station targets production. Set MABA_DB_TARGET=STAGE in the machine environment to
# point a test bench at staging instead.
#
# Console output is ASCII: Windows Server consoles render Hebrew as mojibake.

$ErrorActionPreference = 'Stop'

$appDir = Split-Path -Parent $PSScriptRoot
$webapp = Join-Path $appDir 'webapp'
$logDir = Join-Path $appDir 'logs'

<#  Getting a logger is the FIRST thing this script does, and it must not be able to fail.
    Under Program Files the logs folder can be unwritable, and with ErrorActionPreference=Stop the
    old code died on the New-Item above - before Write-Log existed. The symptom was a station where
    the web app never started and not one line was written anywhere to say why, which cost a long
    afternoon of guessing. If the install folder cannot take the log, fall back to TEMP and say so
    in the first line, so the next person knows where to look.  #>
$logFallbackReason = $null
try {
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $probe = Join-Path $logDir ('.write-probe-{0}' -f $PID)
    Set-Content -LiteralPath $probe -Value 'x' -ErrorAction Stop
    Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
}
catch {
    $logFallbackReason = $_.Exception.Message
    $logDir = Join-Path $env:TEMP 'CalibrationSoftware-logs'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
}

# node's stdout redirect truncates its target, so the launcher keeps its own log.
$log = Join-Path $logDir 'webapp-launcher.log'
$nodeLog = Join-Path $logDir 'webapp.log'

function Write-Log([string]$Message) {
    try {
        Add-Content -Path $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message) -Encoding utf8
    }
    catch { }   # logging must never be the thing that stops the station starting
}

if ($logFallbackReason) {
    Write-Log ("WARNING: {0}\logs is not writable ({1}). Logging to {2} instead." -f $appDir, $logFallbackReason, $logDir)
}

<#  Everything below is written down because it is what we actually had to ask for, one machine at
    a time, when a station would not come up: which build, which node, where it is running from. #>
Write-Log '--------------------------------------------------------------'
Write-Log ("Launcher starting. user={0}  computer={1}" -f $env:USERNAME, $env:COMPUTERNAME)
Write-Log ("App folder: {0}" -f $appDir)
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCmd) {
    $nodeVersion = (& node --version 2>&1) -join ' '
    Write-Log ("node: {0}  ({1})" -f $nodeVersion, $nodeCmd.Source)
}
else {
    Write-Log 'ERROR: node was not found on PATH. The web app cannot start. Install Node.js.'
    exit 1
}

$server = Join-Path $webapp 'server.js'
if (-not (Test-Path $server)) {
    Write-Log 'ERROR: server.js not found; webapp not installed.'
    exit 1
}

if (-not $env:REMOTE_DATABASE_URL) {
    $target = 'PROD'
    if ($env:MABA_DB_TARGET) { $target = $env:MABA_DB_TARGET.ToUpper() }

    $envFile = Join-Path $webapp '.env'
    if (-not (Test-Path $envFile)) {
        Write-Log "ERROR: $envFile is missing; cannot resolve REMOTE_DATABASE_URL."
        exit 1
    }

    # Match REMOTE_DATABASE_URL_<TARGET>, tolerating surrounding quotes. The value is a connection
    # string with a password in it and is never written to the log.
    $pattern = '^\s*REMOTE_DATABASE_URL_' + [regex]::Escape($target) + '\s*=\s*"?([^"\r\n]+)"?\s*$'
    $value = $null
    foreach ($line in (Get-Content -Path $envFile -Encoding utf8)) {
        $m = [regex]::Match($line, $pattern)
        if ($m.Success) { $value = $m.Groups[1].Value; break }
    }

    if (-not $value) {
        Write-Log "ERROR: REMOTE_DATABASE_URL_$target not found in .env; cannot start."
        exit 1
    }

    $env:REMOTE_DATABASE_URL = $value
    Write-Log "Resolved REMOTE_DATABASE_URL from REMOTE_DATABASE_URL_$target."
}

# Ship the PREVIOUS run's logs before this one starts overwriting them - that is the crash case,
# and it is the only moment the files are complete. Best effort: a station with no route to the
# share must still start.
$publishLogs = Join-Path $PSScriptRoot 'publish-logs.ps1'
if (Test-Path $publishLogs) {
    try {
        & $publishLogs -AppDir $appDir
        Write-Log 'Published previous run logs to the shared folder.'
    }
    catch {
        Write-Log ("Log publish skipped: {0}" -f $_.Exception.Message)
    }
}

# A station that already has something on the port starts a server that exits at once, and the
# only trace is a stack in node's own log. Name the holder instead: on a workstation it is usually
# a development server, and on a station a webapp nobody stopped.
$port = 3000
if ($env:PORT) { $port = [int]$env:PORT }

$holder = $null
try {
    $holder = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction Stop |
        Select-Object -First 1 -ExpandProperty OwningProcess
}
catch {
    # No listener, or the cmdlet is unavailable on this Windows build - either way, carry on.
}

if ($holder) {
    $name = (Get-Process -Id $holder -ErrorAction SilentlyContinue).ProcessName
    Write-Log ("ERROR: port {0} is already in use by process {1} ({2}). The web app cannot start." -f $port, $holder, $name)
    Write-Host ("Port {0} is already in use by {1} (PID {2}). Stop it and run this again." -f $port, $name, $holder)
    exit 1
}

Write-Log '===== WEBAPP SESSION STARTED ====='

$errLog = Join-Path $logDir 'webapp-error.log'
$node = Start-Process -FilePath 'node' -ArgumentList 'server.js' -WorkingDirectory $webapp `
    -WindowStyle Hidden -RedirectStandardOutput $nodeLog -RedirectStandardError $errLog -PassThru

<#  Say plainly whether it worked. "Started node" is not the same as "the page is up": node can
    exit a second later on a bad environment, and the old log stopped at the launch line either
    way, so a broken station and a healthy one produced identical logs.  #>
Write-Log ("node started, pid {0}. Waiting for it to listen on {1}..." -f $node.Id, $port)

$listening = $false
for ($i = 0; $i -lt 45; $i++) {
    Start-Sleep -Seconds 2

    if ($node.HasExited) {
        Write-Log ("ERROR: node exited after {0}s with code {1}. See webapp-error.log." -f ($i * 2), $node.ExitCode)
        $firstError = Get-Content -Path $errLog -ErrorAction SilentlyContinue |
            Where-Object { $_ -notmatch '^\s+at ' -and $_.Trim() -ne '' } | Select-Object -First 3
        foreach ($line in $firstError) { Write-Log ("  node said: {0}" -f $line.Trim()) }
        exit 1
    }

    $up = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($up) { $listening = $true; break }
}

if ($listening) {
    Write-Log ("OK: the web app is serving on http://localhost:{0} after {1}s." -f $port, ($i * 2))
}
else {
    Write-Log ("WARNING: node is running (pid {0}) but nothing is listening on {1} after 90s." -f $node.Id, $port)
}
