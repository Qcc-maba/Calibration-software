<#
    One-time setup, run ONCE on the server with administrator rights.

    Afterwards the server updates itself: a scheduled task checks the shared
    folder on a schedule and installs a new build only when one is published.
    No further access to the server is needed to ship an update - publishing to
    the share is enough.

        powershell -ExecutionPolicy Bypass -File .\Install-AutoUpdater.ps1
        powershell -ExecutionPolicy Bypass -File .\Install-AutoUpdater.ps1 -At 02:30
        powershell -ExecutionPolicy Bypass -File .\Install-AutoUpdater.ps1 -Remove

    The task runs as SYSTEM, which on a domain means the machine account.
    If the share does not grant that account read access, this script says so
    immediately rather than leaving a task that quietly never works - use
    -User / -Password to run it as a named account instead.

    Output is ASCII on purpose - Windows Server consoles render Hebrew as mojibake.
#>
[CmdletBinding()]
param(
    [string] $Share    = '\\maba-srv\maba2000\Eliran\qcc-latest',
    [string] $Target   = 'C:\apps\qcc-analytics-deploy\app',
    [string] $AppTask  = 'QCCAnalytics',
    [string] $TaskName = 'QCCAnalyticsUpdate',
    [string] $WorkDir  = 'C:\apps\qcc-updater',
    [string] $At       = '03:00',
    [string] $User,
    [string] $Password,
    [switch] $Remove
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Step($t) { Write-Host "`n==> $t" -ForegroundColor Cyan }
function Info($t) { Write-Host "    $t" }
function Warn($t) { Write-Host "    ! $t" -ForegroundColor Yellow }

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'must run as Administrator (right-click PowerShell -> Run as administrator).'
}

if ($Remove) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "removed scheduled task '$TaskName'. The app itself is untouched." -ForegroundColor Green
    exit 0
}

# ------------------------------------------------------------------ checks
Step 'Pre-flight'
$worker = Join-Path $here 'Update-QCCAnalytics.ps1'
if (-not (Test-Path $worker))                          { throw "cannot find $worker" }
if (-not (Test-Path (Join-Path $Target 'dist\index.cjs'))) { throw "no installation at $Target" }
if (-not (Get-ScheduledTask -TaskName $AppTask -ErrorAction SilentlyContinue) -and
    -not (Get-Service -Name $AppTask -ErrorAction SilentlyContinue)) {
    throw "cannot find the app runner '$AppTask' (neither a task nor a service)"
}
Info "app:    $AppTask -> $Target"
Info "share:  $Share"
Info ("share reachable as the current user: " + $(if (Test-Path $Share) { 'yes' } else { 'NO' }))

# ------------------------------------------------------------------ install
Step "Installing the updater into $WorkDir"
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
Copy-Item $worker (Join-Path $WorkDir 'Update-QCCAnalytics.ps1') -Force
Info 'worker script copied'

$argLine = '-NoProfile -ExecutionPolicy Bypass -File "{0}\Update-QCCAnalytics.ps1" -Share "{1}" -Target "{2}" -AppTask "{3}"' -f $WorkDir, $Share, $Target, $AppTask
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argLine -WorkingDirectory $WorkDir
# Twice a day plus at boot: a missed window is picked up on the next one, and a
# server that was off during the window catches up when it comes back.
$triggers = @(
    (New-ScheduledTaskTrigger -Daily -At $At),
    (New-ScheduledTaskTrigger -AtStartup)
)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
              -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

if ($User) {
    if (-not $Password) { throw '-User was given without -Password' }
    $principal = $null
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $triggers -Settings $settings `
        -User $User -Password $Password -RunLevel Highest | Out-Null
    Info "registered '$TaskName' running as $User"
} else {
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $triggers -Settings $settings `
        -Principal $principal | Out-Null
    Info "registered '$TaskName' running as SYSTEM"
}
Info "schedule: daily at $At, and at every startup"

# ------------------------------------------------------------------ prove it
# Running as the logged-on admin proves nothing about SYSTEM's access to the
# share, so trigger the task itself and read what it wrote to the log.
Step 'Testing the task (dry run against the share)'
$log = Join-Path $WorkDir 'update.log'
if (Test-Path $log) { Remove-Item $log -Force }
$testArgs = $argLine + ' -CheckOnly'
$test = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $testArgs -WorkingDirectory $WorkDir
Set-ScheduledTask -TaskName $TaskName -Action $test | Out-Null
Start-ScheduledTask -TaskName $TaskName
foreach ($i in 1..30) { Start-Sleep -Seconds 2; if (Test-Path $log) { break } }
Set-ScheduledTask -TaskName $TaskName -Action $action | Out-Null   # restore the real action

Write-Host ''
if (Test-Path $log) {
    Get-Content $log | ForEach-Object { Info $_ }
    if ((Get-Content $log -Raw) -match 'share not reachable') {
        Warn 'SYSTEM cannot read the share.'
        Warn 'Re-run with a named account that can:'
        Warn "  .\Install-AutoUpdater.ps1 -User 'DOMAIN\user' -Password '...'"
        Warn 'or grant the machine account (this server) read access to the share.'
    } else {
        Write-Host 'AUTO-UPDATE READY' -ForegroundColor Green
        Write-Host "  the server will pick up any build published to $Share"
        Write-Host "  log: $log"
        Write-Host "  run it now:    Start-ScheduledTask -TaskName $TaskName"
        Write-Host "  remove it:     .\Install-AutoUpdater.ps1 -Remove"
    }
} else {
    Warn 'the task did not produce a log - check Task Scheduler history'
}
