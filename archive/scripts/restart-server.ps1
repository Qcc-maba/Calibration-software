$logFile = "c:\Users\eliran_ha\OneDrive - MBA\Documents\Eliran\MBA\Calibration-software\restart-debug.log"
$releaseDir = "c:\Users\eliran_ha\OneDrive - MBA\Documents\Eliran\MBA\Calibration-software\Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Release"
$exePath = "$releaseDir\Maba.VCT.CommServer.Hosts.ConsoleHost.exe"

# Kill any running ConsoleHost
$procs = Get-Process -Name "Maba.VCT.CommServer.Hosts.ConsoleHost" -ErrorAction SilentlyContinue
"Found $($procs.Count) running ConsoleHost process(es)" | Out-File $logFile
foreach ($p in $procs) {
    "Killing PID $($p.Id)" | Out-File $logFile -Append
    $p | Stop-Process -Force
}

Start-Sleep -Seconds 2
"Killed old processes, now starting new one" | Out-File $logFile -Append

# Start new instance
Start-Process -FilePath $exePath -WorkingDirectory $releaseDir
Start-Sleep -Seconds 4

# Verify
$newProcs = Get-Process -Name "Maba.VCT.CommServer.Hosts.ConsoleHost" -ErrorAction SilentlyContinue
if ($newProcs) {
    "SUCCESS: Server running with PID(s): $(($newProcs | ForEach-Object { $_.Id }) -join ',')" | Out-File $logFile -Append
} else {
    "FAILED: No ConsoleHost process found after restart" | Out-File $logFile -Append
}
