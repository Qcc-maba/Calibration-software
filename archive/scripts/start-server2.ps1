$releaseDir = "c:\Users\eliran_ha\OneDrive - MBA\Documents\Eliran\MBA\Calibration-software\Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Release"
$exePath = "$releaseDir\Maba.VCT.CommServer.Hosts.ConsoleHost.exe"

Set-Location $releaseDir

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exePath
$psi.WorkingDirectory = $releaseDir
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $psi
$proc.Start() | Out-Null

Start-Sleep -Seconds 2

if ($proc.HasExited) {
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    Write-Host "Process exited with code: $($proc.ExitCode)"
    Write-Host "STDOUT: $stdout"
    Write-Host "STDERR: $stderr"
} else {
    Write-Host "Server running - PID $($proc.Id)"
    # Don't kill it, let it keep running
    $proc.Dispose()
}
