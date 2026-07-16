<#
.SYNOPSIS
  Stops the MabaCalibrationServer Windows service so the GUI/dev host can bind the ports.
  Self-elevates (one UAC prompt). Optionally sets the service to Manual start so it stops
  auto-grabbing the ports on every reboot during development.

.EXAMPLE
  .\Stop-CalibrationService.ps1
  .\Stop-CalibrationService.ps1 -SetManual      # also switch Automatic -> Manual
#>
[CmdletBinding()]
param([switch] $SetManual)

$ServiceName = "MabaCalibrationServer"

# --- self-elevate if not running as Administrator ---
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Elevating (accept the UAC prompt)..." -ForegroundColor Yellow
    $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    if ($SetManual) { $psArgs += "-SetManual" }
    Start-Process -FilePath "powershell.exe" -ArgumentList $psArgs -Verb RunAs
    return
}

# --- elevated from here ---
$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if (-not $svc) {
    Write-Host "Service '$ServiceName' not found." -ForegroundColor Red
    Start-Sleep -Seconds 3; return
}

if ($svc.Status -eq 'Running') {
    Write-Host "Stopping $ServiceName..." -ForegroundColor Cyan
    Stop-Service -Name $ServiceName -Force
    Start-Sleep -Seconds 2
    $svc.Refresh()
}
Write-Host "Status: $($svc.Status)" -ForegroundColor Green

if ($SetManual) {
    Write-Host "Setting start type to Manual..." -ForegroundColor Cyan
    Set-Service -Name $ServiceName -StartupType Manual
    Write-Host "Done. It will no longer start automatically (start it with: Start-Service $ServiceName)."
}

Write-Host "`nPorts 5001 / 50000 / 50050 are now free for the GUI. You can Start Server in the app." -ForegroundColor Green
Write-Host "Press Enter to close..."; Read-Host | Out-Null
