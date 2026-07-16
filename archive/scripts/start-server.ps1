$releaseDir = "c:\Users\eliran_ha\OneDrive - MBA\Documents\Eliran\MBA\Calibration-software\Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Release"
$exePath = "$releaseDir\Maba.VCT.CommServer.Hosts.ConsoleHost.exe"
Start-Process -FilePath $exePath -WorkingDirectory $releaseDir
Start-Sleep -Seconds 3
$proc = Get-Process -Name "Maba.VCT.CommServer.Hosts.ConsoleHost" -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "Server started OK - PID $($proc.Id)"
} else {
    Write-Host "Server did NOT start"
}
