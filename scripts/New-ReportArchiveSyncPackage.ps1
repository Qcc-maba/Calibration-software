<#
.SYNOPSIS
    Builds a self-contained ReportArchiveSync package for a server without the .NET SDK or git
    (priority-test, maba-priority).

.DESCRIPTION
    Publishes Systems/ReportArchiveSync self-contained for win-x64 and zips it with the installer,
    laid out the way the installer expects:

        scripts\Install-ReportArchiveSync-Service.ps1
        Systems\ReportArchiveSync\publish\...

    On the server: unzip to C:\Maba\ReportArchiveSync and run
        .\scripts\Install-ReportArchiveSync-Service.ps1 -SkipPublish ...

    The package holds no secrets: the connection string and AWS keys are given to the installer on
    the server (-PromptForSecrets). Playwright's driver (and its node.exe) is inside, so the
    installer can still fetch Chromium on the server.

.PARAMETER OutFile
    Where to write the zip. Default: ReportArchiveSync-<short sha>.zip in the repo root's parent.

.EXAMPLE
    .\scripts\New-ReportArchiveSyncPackage.ps1
#>
param(
    [string] $OutFile
)
$ErrorActionPreference = 'Stop'

$Root    = Split-Path $PSScriptRoot -Parent
$Project = Join-Path $Root 'Systems\ReportArchiveSync\Maba.VCT.ReportArchiveSync.csproj'
$sha     = (git -C $Root rev-parse --short HEAD).Trim()
if (-not $OutFile) { $OutFile = Join-Path (Split-Path $Root -Parent) "ReportArchiveSync-$sha.zip" }

$stage = Join-Path ([IO.Path]::GetTempPath()) "ras-package-$sha"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
$publish = Join-Path $stage 'Systems\ReportArchiveSync\publish'

Write-Host "Publishing self-contained (win-x64) at $sha ..." -ForegroundColor Yellow
dotnet publish $Project -c Release -r win-x64 --self-contained true -o $publish --nologo | Out-Null
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed (exit $LASTEXITCODE)" }
if (-not (Test-Path (Join-Path $publish 'Maba.VCT.ReportArchiveSync.exe'))) { throw 'published executable missing' }
if (-not (Test-Path (Join-Path $publish '.playwright\package\cli.js'))) { throw "Playwright's driver is missing from the publish output" }

New-Item -ItemType Directory -Path (Join-Path $stage 'scripts') | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'Install-ReportArchiveSync-Service.ps1') (Join-Path $stage 'scripts')

if (Test-Path $OutFile) { Remove-Item $OutFile }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $OutFile
Remove-Item $stage -Recurse -Force

$size = [math]::Round((Get-Item $OutFile).Length / 1MB)
Write-Host "Package: $OutFile ($size MB)" -ForegroundColor Green
