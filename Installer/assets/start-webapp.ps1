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
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
# node's stdout redirect truncates its target, so the launcher keeps its own log.
$log = Join-Path $logDir 'webapp-launcher.log'
$nodeLog = Join-Path $logDir 'webapp.log'

function Write-Log([string]$Message) {
    Add-Content -Path $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message) -Encoding utf8
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

Write-Log '===== WEBAPP SESSION STARTED ====='

$errLog = Join-Path $logDir 'webapp-error.log'
Start-Process -FilePath 'node' -ArgumentList 'server.js' -WorkingDirectory $webapp `
    -WindowStyle Hidden -RedirectStandardOutput $nodeLog -RedirectStandardError $errLog
