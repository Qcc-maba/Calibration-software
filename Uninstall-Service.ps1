$ServiceName = "MabaCalibrationServer"

if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
    Write-Host "Stopping service $ServiceName..."
    Stop-Service -Name $ServiceName -ErrorAction SilentlyContinue
    
    Write-Host "Uninstalling service $ServiceName..."
    # Using sc.exe for more reliable removal if Remove-Service is not available (older PowerShell)
    sc.exe delete $ServiceName
    
    Write-Host "Service $ServiceName uninstalled."
} else {
    Write-Host "Service $ServiceName not found."
}
