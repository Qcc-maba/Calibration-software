<#
    Rolls a QCC Analytics installation back to a previous build.

    Run on the SERVER, from an ELEVATED PowerShell:
        powershell -ExecutionPolicy Bypass -File .\Rollback-QCCAnalytics.ps1

    With no arguments it finds the runner the same way the installer does - a
    windows service or a scheduled task running dist\index.cjs - and restores
    the newest dist_bak_* folder next to it.
    data\pricing is never touched: it holds the learned matches, and the older
    build simply ignores it.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $Name,
    [string] $Target,
    [string] $Backup
)

$ErrorActionPreference = 'Stop'
$prevWhatIf = $WhatIfPreference
$WhatIfPreference = $false
Import-Module CimCmdlets, ScheduledTasks -ErrorAction SilentlyContinue
$WhatIfPreference = $prevWhatIf

function Get-Installations {
    foreach ($svc in Get-CimInstance Win32_Service) {
        $dir = $null
        $params = "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.Name)\Parameters"
        if (Test-Path $params) {
            $p = Get-ItemProperty $params -ErrorAction SilentlyContinue
            if ($p.AppParameters -match 'index\.cjs' -and $p.AppDirectory) { $dir = $p.AppDirectory }
        }
        if (-not $dir -and $svc.PathName -match '"?([A-Za-z]:\\[^"]*?)\\dist\\index\.cjs') { $dir = $Matches[1] }
        if ($dir -and (Test-Path (Join-Path $dir 'dist\index.cjs'))) {
            [pscustomobject]@{ Kind = 'Service'; Name = $svc.Name; Directory = $dir }
        }
    }
    foreach ($task in (Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        foreach ($a in $task.Actions) {
            $args = [string]$a.Arguments
            $dir  = [string]$a.WorkingDirectory
            if ($args -notmatch 'index\.cjs') { continue }
            if (-not $dir -and $args -match '"?([A-Za-z]:\\[^"]*?)\\dist\\index\.cjs') { $dir = $Matches[1] }
            if ($dir -and (Test-Path (Join-Path $dir 'dist\index.cjs'))) {
                [pscustomobject]@{ Kind = 'Task'; Name = $task.TaskName; Directory = $dir }
            }
        }
    }
}

if ($Name -and $Target) {
    $kind = if (Get-Service -Name $Name -ErrorAction SilentlyContinue) { 'Service' } else { 'Task' }
    $install = [pscustomobject]@{ Kind = $kind; Name = $Name; Directory = $Target }
} else {
    $found = @(Get-Installations)
    if ($found.Count -ne 1) { throw 'could not determine the installation. Pass -Name and -Target.' }
    $install = $found[0]
}
$Target = $install.Directory

if (-not $Backup) {
    $latest = Get-ChildItem $Target -Directory -Filter 'dist_bak_*' | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $latest) { throw "no dist_bak_* folder found in $Target" }
    $Backup = $latest.FullName
}
if (-not (Test-Path (Join-Path $Backup 'index.cjs'))) { throw "not a valid build backup: $Backup" }

$port = 5000
$envPath = Join-Path $Target '.env'
if (Test-Path $envPath) {
    $m = [regex]::Match((Get-Content $envPath -Raw), '(?m)^\s*PORT\s*=\s*(\d+)')
    if ($m.Success) { $port = [int]$m.Groups[1].Value }
}

Write-Host "==> Runner:   $($install.Kind) '$($install.Name)'"
Write-Host "==> Target:   $Target"
Write-Host "==> Restoring $Backup" -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess($install.Name, 'Stop')) {
    if ($install.Kind -eq 'Service') {
        Stop-Service -Name $install.Name -Force
        (Get-Service $install.Name).WaitForStatus('Stopped', '00:01:00')
    } else {
        Stop-ScheduledTask -TaskName $install.Name -ErrorAction SilentlyContinue
        foreach ($i in 1..30) {
            Start-Sleep -Seconds 1
            if (-not (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)) { break }
        }
    }
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ($PSCmdlet.ShouldProcess((Join-Path $Target 'dist'), 'Restore build')) {
    Move-Item (Join-Path $Target 'dist') (Join-Path $Target "dist_failed_$stamp") -Force
    Copy-Item $Backup (Join-Path $Target 'dist') -Recurse -Force
    Write-Host "    restored; the replaced build was kept as dist_failed_$stamp"
}

if ($PSCmdlet.ShouldProcess($install.Name, 'Start')) {
    if ($install.Kind -eq 'Service') {
        Start-Service -Name $install.Name
        (Get-Service $install.Name).WaitForStatus('Running', '00:01:00')
    } else {
        Start-ScheduledTask -TaskName $install.Name
    }
    $up = $false
    foreach ($i in 1..30) {
        Start-Sleep -Seconds 2
        try { if ((Invoke-WebRequest "http://localhost:$port/" -TimeoutSec 10 -UseBasicParsing).StatusCode -eq 200) { $up = $true; break } } catch { }
    }
    if ($up) { Write-Host 'ROLLBACK OK' -ForegroundColor Green }
    else { Write-Host 'the dashboard did not answer - check logs\service.err.log' -ForegroundColor Yellow }
}
