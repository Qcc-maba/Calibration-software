<#
.SYNOPSIS
    Keeps the logger's USB-serial adapter powered, and keeps enough of the Kernel-PnP log to see a
    USB drop afterwards (MBA-987, motivated by MBA-967).

.DESCRIPTION
    On station NOFAR the logger's Prolific adapter dropped off the USB bus twice mid-run with USB
    selective suspend enabled, and the event that would have proved it (Kernel-PnP/Device Management
    1010, "surprise removed") had already been overwritten by a flapping monitor. This script:

      1. Turns USB selective suspend off, AC and DC, in every power scheme on the machine (not only
         the active one - an operator or an OEM tool can switch plans), then re-applies the active
         scheme so the change takes effect now.
      2. Turns off "Allow the computer to turn off this device to save power" for USB-serial
         adapters (Prolific VID_067B, FTDI VID_0403, CH340 VID_1A86, CP210x VID_10C4), USB hubs,
         root hubs and the xHCI host controllers:
           - present devices: WMI root\wmi MSPower_DeviceEnable.Enable = false. This is exactly what
             the Device Manager checkbox does; the driver itself persists the choice.
           - KMDF drivers (Prolific ser2pl, USBHUB3, ...), present or not: the framework keeps that
             choice in the device's Device Parameters\WDF\IdleInWorkingState and reads it each time
             the device starts, so writing 0 there also covers an adapter that is unplugged now.
             WDM drivers (FTDI, CH340) have no such value; they are covered only while present.
      3. Makes the Kernel-PnP/Device Management log (and System) at least -EventLogMB, never
         smaller than it already is, and enabled.

    Every setting is logged before and after, prefixed [USB-POWER], so install.log answers "was this
    applied". Best effort throughout: nothing here throws, and the exit code is always 0 - a station
    must still install and calibrate if Windows refuses one of these.

    With -RegisterTask it also registers a scheduled task (SYSTEM, at startup, at logon, and when
    Windows configures a new device instance) that re-runs this script into logs\usb-power.log. That
    is what covers an adapter plugged in after install or into another port: it is a new device
    instance, which an install-time change cannot reach.

.PARAMETER LogPath
    File to append the [USB-POWER] lines to (Setup passes install.log, the task logs\usb-power.log).

.PARAMETER RegisterTask
    Also (re)register the scheduled task. Setup passes it on every install and upgrade.

.PARAMETER ReportOnly
    Read and log the current values, change nothing. Works without elevation, except that the
    per-device WMI values need Administrator.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Set-StationUsbPower.ps1 -LogPath C:\temp\usb.log -ReportOnly
#>
param(
    [string]$LogPath,
    [switch]$RegisterTask,
    [switch]$ReportOnly,
    [int]$EventLogMB = 50
)

$ErrorActionPreference = 'Continue'

$TaskName = 'MabaCalibration-UsbPower'
$SuspendSubgroup = '2a737441-1930-4402-8d77-b2bebba308a3'
$SuspendSetting = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
$AdapterPattern = 'VID_067B|VID_0403|VID_1A86|VID_10C4'
# Hubs and root hubs, and the xHCI host controller above them: a controller that powers down takes
# every port with it, and it carries the same Device Manager checkbox.
$HubServices = @('USBHUB3', 'usbhub', 'usbhub3', 'USBXHCI')
$EventLogs = @('Microsoft-Windows-Kernel-PnP/Device Management', 'System')

$script:changes = 0
$script:warnings = 0

# Console and log are ASCII: install.log is written by Setup, and Windows consoles render Hebrew as
# mojibake. A non-ASCII scheme name (a Hebrew Windows) is logged with '?'.
function Write-Log([string]$Message) {
    $line = '[{0}] [USB-POWER] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Write-Host $line
    if ($LogPath) {
        try { Add-Content -LiteralPath $LogPath -Value $line -Encoding ASCII -ErrorAction Stop } catch { }
    }
}
function Write-Warn([string]$Message) { $script:warnings++; Write-Log "WARNING: $Message" }

# The task appends to the same file on every boot, logon and new device; keep it bounded.
if ($LogPath -and (Test-Path -LiteralPath $LogPath)) {
    try {
        if ((Get-Item -LiteralPath $LogPath).Length -gt 1MB -and $LogPath -notlike '*install.log') {
            Move-Item -LiteralPath $LogPath -Destination "$LogPath.old" -Force -ErrorAction Stop
        }
    }
    catch { }
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
$mode = if ($ReportOnly) { 'report only' } else { 'apply' }
Write-Log ("start ({0}; user={1}; admin={2}; computer={3})" -f $mode, [Security.Principal.WindowsIdentity]::GetCurrent().Name, $isAdmin, $env:COMPUTERNAME)
if (-not $isAdmin -and -not $ReportOnly) {
    Write-Warn 'not running as Administrator - nothing changed. Run Setup, or this script, elevated.'
    exit 0
}
$apply = -not $ReportOnly

# ---------------------------------------------------------------------------------------------
# 1. USB selective suspend, every power scheme, AC and DC.
# ---------------------------------------------------------------------------------------------
# powercfg's text is localised, so nothing here matches on its words: schemes are found by their
# GUID pattern, and the two 0x values in /q output are the current AC and DC index, in that order.
function Get-SuspendValues([string]$Scheme) {
    $out = & powercfg /q $Scheme $SuspendSubgroup $SuspendSetting 2>&1
    $hex = @([regex]::Matches(($out -join "`n"), '0x([0-9a-fA-F]{8})') | ForEach-Object { [Convert]::ToInt32($_.Groups[1].Value, 16) })
    if ($hex.Count -lt 2) { return $null }
    # The last two: an index setting prints no other 0x value, but a future Windows might.
    return @{ AC = $hex[$hex.Count - 2]; DC = $hex[$hex.Count - 1] }
}

function Set-SelectiveSuspendOff {
    $schemes = @(& powercfg /list 2>&1 | ForEach-Object {
            if ("$_" -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\s*(\((.*)\))?\s*(\*)?\s*$') {
                [pscustomobject]@{ Guid = $Matches[1]; Name = $Matches[3]; Active = [bool]$Matches[4] }
            }
        })
    if ($schemes.Count -eq 0) { Write-Warn 'powercfg /list returned no power schemes - selective suspend not checked'; return }

    foreach ($s in $schemes) {
        $label = "scheme {0} ({1}){2}" -f $s.Guid, $s.Name, $(if ($s.Active) { ' [active]' } else { '' })
        $before = Get-SuspendValues $s.Guid
        if (-not $before) { Write-Warn "$label - USB selective suspend setting not readable"; continue }
        if (-not $apply -or ($before.AC -eq 0 -and $before.DC -eq 0)) {
            Write-Log ("USB selective suspend {0}: AC={1} DC={2} (0 = disabled){3}" -f $label, $before.AC, $before.DC, $(if ($apply) { ' - already off' } else { '' }))
            continue
        }
        & powercfg /setacvalueindex $s.Guid $SuspendSubgroup $SuspendSetting 0 2>&1 | Out-Null
        $acExit = $LASTEXITCODE
        & powercfg /setdcvalueindex $s.Guid $SuspendSubgroup $SuspendSetting 0 2>&1 | Out-Null
        $dcExit = $LASTEXITCODE
        $after = Get-SuspendValues $s.Guid
        if ($after -and $after.AC -eq 0 -and $after.DC -eq 0) {
            $script:changes++
            Write-Log ("USB selective suspend {0}: AC {1} -> 0, DC {2} -> 0" -f $label, $before.AC, $before.DC)
        }
        else {
            Write-Warn ("USB selective suspend {0}: could not turn off (powercfg exit AC={1} DC={2}; now AC={3} DC={4})" -f $label, $acExit, $dcExit, $after.AC, $after.DC)
        }
    }

    # The index change is stored at once, but Windows applies it to the running system only when
    # the active scheme is (re)set.
    $active = $schemes | Where-Object Active | Select-Object -First 1
    if ($apply -and $active) {
        & powercfg /setactive $active.Guid 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Log "re-applied active scheme $($active.Guid)" }
        else { Write-Warn "powercfg /setactive $($active.Guid) failed (exit $LASTEXITCODE) - takes effect after the next plan change or reboot" }
    }

    # A domain or local policy overrides the plan. Say so, rather than report a setting that is not in force.
    $policy = "HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\$SuspendSetting"
    if (Test-Path $policy) {
        $p = Get-ItemProperty $policy -ErrorAction SilentlyContinue
        Write-Warn ("a power policy sets USB selective suspend and overrides the plan: ACSettingIndex={0} DCSettingIndex={1}" -f $p.ACSettingIndex, $p.DCSettingIndex)
    }
}

# ---------------------------------------------------------------------------------------------
# 2. Per-device "Allow the computer to turn off this device to save power".
# ---------------------------------------------------------------------------------------------
function Get-DeviceLabel($d) { "{0} [{1}]" -f ($(if ($d.FriendlyName) { $d.FriendlyName } else { '?' }) -replace '[^\x20-\x7E]', '?'), $d.InstanceId }

function Test-Kmdf($d) {
    # KMDF keeps the user's choice under Device Parameters\WDF; a KMDF driver also has Parameters\Wdf
    # under its service key. Either is proof enough.
    $enum = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($d.InstanceId)"
    if (Test-Path -LiteralPath "$enum\Device Parameters\WDF") { return $true }
    if ($d.Service -and (Test-Path -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$($d.Service)\Parameters\Wdf")) { return $true }
    return $false
}

function Set-DevicePowerOff {
    $all = @(Get-PnpDevice -ErrorAction SilentlyContinue)
    $targets = @($all | Where-Object {
            $_.InstanceId -match $AdapterPattern -or $_.Service -in $HubServices -or $_.InstanceId -match '^USB\\ROOT_HUB'
        })
    $present = @($targets | Where-Object { $_.Present })
    Write-Log ("devices: {0} USB-serial adapter / hub / host controller instances known, {1} present" -f $targets.Count, $present.Count)

    # 2a. Present devices, through the driver's own power-management WMI - the Device Manager checkbox.
    $enables = $null
    try { $enables = @(Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable -OperationTimeoutSec 60 -ErrorAction Stop) }
    catch {
        if ($isAdmin) { Write-Warn "MSPower_DeviceEnable not readable: $($_.Exception.Message)" }
        else { Write-Log 'per-device WMI power settings: skipped (needs Administrator)' }
    }
    if ($enables) {
        foreach ($d in $present) {
            $label = Get-DeviceLabel $d
            $m = $enables | Where-Object {
                $_.InstanceName.StartsWith($d.InstanceId + '_', [StringComparison]::OrdinalIgnoreCase) -or
                $_.InstanceName.Equals($d.InstanceId, [StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
            $isAdapter = $d.InstanceId -match $AdapterPattern
            if (-not $m) {
                # Hubs without the checkbox are common and not worth a line each; an adapter is.
                if ($isAdapter) { Write-Log "turn-off-to-save-power: $label - driver offers no setting (no Power Management tab)" }
                continue
            }
            if (-not $m.Enable) { if ($isAdapter -or -not $apply) { Write-Log "turn-off-to-save-power: $label = False - already off" }; continue }
            if (-not $apply) { Write-Log "turn-off-to-save-power: $label = True (Windows may power it down)"; continue }
            try {
                Set-CimInstance -InputObject $m -Property @{ Enable = $false } -ErrorAction Stop
                $now = Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable -ErrorAction Stop |
                    Where-Object { $_.InstanceName -eq $m.InstanceName } | Select-Object -First 1
                if ($now -and -not $now.Enable) { $script:changes++; Write-Log "turn-off-to-save-power: $label True -> False" }
                else { Write-Warn "turn-off-to-save-power: $label - set to False, but it still reads True" }
            }
            catch { Write-Warn "turn-off-to-save-power: $label - could not set: $($_.Exception.Message)" }
        }
    }

    # 2b. KMDF drivers, present or not: the stored choice the framework reads at the next device start.
    foreach ($d in $targets) {
        if (-not (Test-Kmdf $d)) {
            if (-not $d.Present -and $d.InstanceId -match $AdapterPattern) {
                Write-Log ("not present, non-KMDF driver ({0}): {1} - covered when it is next plugged in (task)" -f $d.Service, (Get-DeviceLabel $d))
            }
            continue
        }
        $key = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($d.InstanceId)\Device Parameters\WDF"
        $before = (Get-ItemProperty -LiteralPath $key -Name IdleInWorkingState -ErrorAction SilentlyContinue).IdleInWorkingState
        $label = Get-DeviceLabel $d
        if ($null -ne $before -and $before -eq 0) { continue }
        if (-not $apply) {
            Write-Log ("WDF IdleInWorkingState {0}: {1}" -f $label, $(if ($null -eq $before) { 'unset (driver default: may power down)' } else { $before }))
            continue
        }
        try {
            if (-not (Test-Path -LiteralPath $key)) { New-Item -Path $key -Force -ErrorAction Stop | Out-Null }
            New-ItemProperty -LiteralPath $key -Name IdleInWorkingState -PropertyType DWord -Value 0 -Force -ErrorAction Stop | Out-Null
            $script:changes++
            Write-Log ("WDF IdleInWorkingState {0}: {1} -> 0{2}" -f $label, $(if ($null -eq $before) { 'unset' } else { $before }), $(if ($d.Present) { '' } else { ' (not present; applies when plugged in)' }))
        }
        catch {
            # The Enum tree is SYSTEM-owned on some machines; the task runs as SYSTEM and retries.
            Write-Warn ("WDF IdleInWorkingState {0}: could not write ({1}) - the SYSTEM task retries at the next startup or logon" -f $label, $_.Exception.Message)
        }
    }
}

# ---------------------------------------------------------------------------------------------
# 3. Event logs big enough to still hold a USB drop days later.
# ---------------------------------------------------------------------------------------------
function Set-EventLogSize {
    $min = [long]$EventLogMB * 1MB
    foreach ($name in $EventLogs) {
        try {
            $log = Get-WinEvent -ListLog $name -ErrorAction Stop
            $beforeSize = $log.MaximumSizeInBytes
            $beforeEnabled = $log.IsEnabled
            if (-not $apply -or ($beforeSize -ge $min -and $beforeEnabled)) {
                Write-Log ("event log {0}: maxSize={1} enabled={2}{3}" -f $name, $beforeSize, $beforeEnabled, $(if ($apply) { ' - already large enough' } else { '' }))
                continue
            }
            if ($beforeSize -lt $min) { $log.MaximumSizeInBytes = $min }
            if (-not $beforeEnabled) { $log.IsEnabled = $true }
            $log.SaveChanges()
            $after = Get-WinEvent -ListLog $name -ErrorAction Stop
            $script:changes++
            Write-Log ("event log {0}: maxSize {1} -> {2}, enabled {3} -> {4}" -f $name, $beforeSize, $after.MaximumSizeInBytes, $beforeEnabled, $after.IsEnabled)
        }
        catch { Write-Warn "event log ${name}: $($_.Exception.Message)" }
    }
}

# ---------------------------------------------------------------------------------------------
# 4. The scheduled task that covers adapters plugged in later.
# ---------------------------------------------------------------------------------------------
function Register-UsbPowerTask {
    $script = $PSCommandPath
    $appDir = Split-Path -Parent (Split-Path -Parent $script)
    $taskLog = Join-Path (Join-Path $appDir 'logs') 'usb-power.log'
    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $taskArgs = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -LogPath "{1}"' -f $script, $taskLog
    $esc = { param($s) [Security.SecurityElement]::Escape($s) }

    # Event 400 in Kernel-PnP/Configuration is "Device ... was configured": Windows writes it when it
    # sets up a device instance it has not seen before - a new adapter, or a known one in a new port.
    # It is rare (a few hundred in six months on a dev laptop), unlike the Device Management log,
    # which a flapping monitor fills every few seconds. The delay lets the device finish starting.
    $subscription = '<QueryList><Query Id="0" Path="Microsoft-Windows-Kernel-PnP/Configuration"><Select Path="Microsoft-Windows-Kernel-PnP/Configuration">*[System[(EventID=400)]]</Select></Query></QueryList>'
    $xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Author>Calibration Software (MBA)</Author>
    <Description>Keeps USB-serial adapters and USB hubs from being powered down (MBA-987). Re-applies at startup, at logon and when Windows configures a new device. Log: $(& $esc $taskLog)</Description>
  </RegistrationInfo>
  <Triggers>
    <BootTrigger><Enabled>true</Enabled><Delay>PT1M</Delay></BootTrigger>
    <LogonTrigger><Enabled>true</Enabled><Delay>PT30S</Delay></LogonTrigger>
    <EventTrigger><Enabled>true</Enabled><Delay>PT20S</Delay><Subscription>$(& $esc $subscription)</Subscription></EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="System"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings><StopOnIdleEnd>false</StopOnIdleEnd><RestartOnIdle>false</RestartOnIdle></IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <ExecutionTimeLimit>PT5M</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="System">
    <Exec><Command>$(& $esc $ps)</Command><Arguments>$(& $esc $taskArgs)</Arguments></Exec>
  </Actions>
</Task>
"@
    try {
        Register-ScheduledTask -TaskName $TaskName -Xml $xml -Force -ErrorAction Stop | Out-Null
        $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        Write-Log ("scheduled task '{0}': registered, state={1}, runs as SYSTEM at startup, at logon and on Kernel-PnP/Configuration event 400; log {2}" -f $TaskName, $t.State, $taskLog)
    }
    catch { Write-Warn "scheduled task '$TaskName' could not be registered: $($_.Exception.Message) - adapters plugged in later are not covered" }
}

foreach ($step in @(
        @{ Name = 'selective suspend'; Run = { Set-SelectiveSuspendOff } },
        @{ Name = 'device power'; Run = { Set-DevicePowerOff } },
        @{ Name = 'event logs'; Run = { Set-EventLogSize } })) {
    try { & $step.Run } catch { Write-Warn "$($step.Name): $($_.Exception.Message)" }
}
if ($RegisterTask) {
    if ($apply) { try { Register-UsbPowerTask } catch { Write-Warn "scheduled task: $($_.Exception.Message)" } }
    else {
        $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        Write-Log ("scheduled task '{0}': {1}" -f $TaskName, $(if ($t) { "present, state=$($t.State)" } else { 'not registered' }))
    }
}

Write-Log ("done ({0}): {1} change(s), {2} warning(s)" -f $mode, $script:changes, $script:warnings)
exit 0
