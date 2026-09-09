# Copies this station's logs to the shared investigation folder, one subfolder per machine.
#
# The destination is written as a UNC path on purpose. F:\Eliran\... is that same folder on the
# bench, but a drive letter is per-user and per-machine: on a customer station F: may be absent or
# mapped somewhere else entirely, and the copy would then either fail or - worse - land somewhere
# unexpected. \\maba-srv\maba2000 is the same on every machine that can see it at all.
#
# Best effort by design: a station with no route to the share must still start and calibrate. Every
# failure here is logged locally and swallowed.
#
# Called at launch by start-webapp.ps1 (which ships the PREVIOUS run's logs - the crash case), and
# safe to run by hand at any time.
#
# Console output is ASCII: Windows Server consoles render Hebrew as mojibake.

param(
    # ASCII on purpose. The folder was renamed from a Hebrew name, and a Hebrew literal here only
    # survives if this file keeps its UTF-8 BOM - one save without it and every station silently
    # stops publishing.
    [string]$Destination = '\\maba-srv\maba2000\Eliran\NOFAR',
    [string]$AppDir,
    # A wedged device can grow server.log to tens of MB in a session; the bench produced 53 MB.
    # Copying that over a WAN link on every launch is not worth it, so oversized files are skipped
    # and named in the local log - they can still be fetched by hand when a case needs them.
    [int]$MaxFileMB = 20
)

$ErrorActionPreference = 'Stop'

if (-not $AppDir) { $AppDir = Split-Path -Parent $PSScriptRoot }

$localLog = Join-Path (Join-Path $AppDir 'logs') 'publish-logs.log'

function Write-Local([string]$Message) {
    try {
        $dir = Split-Path -Parent $localLog
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Add-Content -Path $localLog -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message) -Encoding utf8
    }
    catch { }
}

try {
    if (-not (Test-Path -LiteralPath $Destination)) {
        Write-Local "Share not reachable: $Destination - skipping."
        return
    }

    # One folder per machine, or stations overwrite each other's logs.
    $target = Join-Path $Destination $env:COMPUTERNAME
    if (-not (Test-Path -LiteralPath $target)) {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
    }

    # Both halves of the system, plus the install folder itself - install.log lives there, not
    # under logs\, and it is the file that answers "which build is this and did Setup succeed".
    # Having to ask for it by hand is what made the first station take a whole afternoon.
    $sources = @(
        (Join-Path $AppDir 'logs'),
        (Join-Path $AppDir 'consolehost'),
        $AppDir
    )

    $patterns = @('*.log', 'crash.log', 'console-out.txt')
    $copied = 0

    foreach ($source in $sources) {
        if (-not (Test-Path -LiteralPath $source)) { continue }

        foreach ($pattern in $patterns) {
            Get-ChildItem -LiteralPath $source -Filter $pattern -File -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    if ($_.Length -gt ($MaxFileMB * 1MB)) {
                        Write-Local ("Skipped {0} - {1} MB exceeds the {2} MB limit." -f `
                            $_.Name, [math]::Round($_.Length / 1MB, 1), $MaxFileMB)
                        return
                    }

                    # Prefix with the source folder so consolehost\server.log and logs\server.log
                    # cannot collide, and stamp the copy so successive runs do not overwrite.
                    $stamp = $_.LastWriteTime.ToString('yyyyMMdd-HHmmss')
                    $name = '{0}_{1}_{2}' -f (Split-Path -Leaf $source), $stamp, $_.Name
                    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $target $name) -Force -ErrorAction Stop
                    $copied++
                }
                catch {
                    Write-Local ("Could not copy {0}: {1}" -f $_.FullName, $_.Exception.Message)
                }
            }
        }
    }

    Write-Local "Published $copied file(s) to $target"
}
catch {
    Write-Local ("Publish failed: {0}" -f $_.Exception.Message)
}
