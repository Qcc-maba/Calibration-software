$logFile = "c:\Users\eliran_ha\OneDrive - MBA\Documents\Eliran\MBA\Calibration-software\start-debug.log"
$releaseDir = "c:\Users\eliran_ha\OneDrive - MBA\Documents\Eliran\MBA\Calibration-software\Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Release"
$exePath = "$releaseDir\Maba.VCT.CommServer.Hosts.ConsoleHost.exe"

"Starting at $(Get-Date)" | Out-File $logFile
"ExePath: $exePath" | Out-File $logFile -Append
"Exists: $(Test-Path $exePath)" | Out-File $logFile -Append

Set-Location $releaseDir

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exePath
$psi.WorkingDirectory = $releaseDir
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $psi

try {
    $proc.Start() | Out-Null
    "PID: $($proc.Id)" | Out-File $logFile -Append
    Start-Sleep -Seconds 3
    if ($proc.HasExited) {
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        "EXITED with code: $($proc.ExitCode)" | Out-File $logFile -Append
        "STDOUT: $stdout" | Out-File $logFile -Append
        "STDERR: $stderr" | Out-File $logFile -Append
    } else {
        "RUNNING OK - PID $($proc.Id)" | Out-File $logFile -Append
        $proc.Dispose()
    }
} catch {
    "EXCEPTION: $_" | Out-File $logFile -Append
}
