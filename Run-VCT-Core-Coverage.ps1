#Requires -Version 5.1
<#
.SYNOPSIS
  Runs Galcon.VCT.Core.Tests with Coverlet (Cobertura) and fails if line or branch coverage is below 95%.

.DESCRIPTION
  Use this in CI/local verification; VSTest does not always enforce Coverlet Threshold in runsettings.

.EXAMPLE
  .\Run-VCT-Core-Coverage.ps1
#>
$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot
$testDir = Join-Path $repoRoot 'Systems\VCT\VCT\VCT.Core.Tests'
$proj = Join-Path $testDir 'VCT.Core.Tests.csproj'
$minCoverage = 0.95

if (-not (Test-Path -LiteralPath $proj)) {
    Write-Error "Test project not found: $proj"
    exit 1
}

Push-Location $testDir
try {
    dotnet test .\VCT.Core.Tests.csproj --settings .\coverlet.runsettings --collect:"XPlat Code Coverage" -v q
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}

$coverageFile = Get-ChildItem -Path (Join-Path $testDir 'TestResults') -Recurse -Filter 'coverage.cobertura.xml' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $coverageFile) {
    Write-Error "coverage.cobertura.xml not found under TestResults. Run from repo root; ensure tests produced coverage."
    exit 2
}

[xml]$covXml = Get-Content -LiteralPath $coverageFile.FullName -Raw
$lineRate = [double]$covXml.coverage.'line-rate'
$branchRate = [double]$covXml.coverage.'branch-rate'

Write-Host ("Maba.VCT.Core | Line: {0:p2} | Branch: {1:p2} | {2}" -f $lineRate, $branchRate, $coverageFile.FullName)

if ($lineRate -lt $minCoverage -or $branchRate -lt $minCoverage) {
    Write-Error ("Coverage below {0:p0}: line={1:p4} branch={2:p4}" -f $minCoverage, $lineRate, $branchRate)
    exit 3
}

Write-Host "OK: line and branch coverage are at or above 95%."
exit 0
