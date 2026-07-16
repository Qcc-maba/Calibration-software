# Calibration software — build helpers
#
# VCT.Core unit tests + coverage (Cobertura; fails if line/branch < 95%):
#   .\Run-VCT-Core-Coverage.ps1
#
# Manual (from Systems\VCT\VCT\VCT.Core.Tests):
#   dotnet test VCT.Core.Tests.csproj --settings coverlet.runsettings --collect:"XPlat Code Coverage"
#
# Isolated VCT.json in tests: set process env VCT_SETTINGS_FULL_PATH to an absolute path (see VCTSettings.VCT_SETTINGS_FULL_PATH_ENV).

$msbuild = 'C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe'
$proj = 'C:\Users\eliran_ha\OneDrive - MBA\Documents\Eliran\MBA\Calibration-software\Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\ComServer.Hosts.ConsoleHost.csproj'
$result = & $msbuild $proj /p:Configuration=Debug /t:Build /v:quiet 2>&1
$result | Where-Object { $_ -match 'error|succeeded|FAILED' }
Write-Host 'Exit:' $LASTEXITCODE
