<#
    Upgrades an existing QCC Analytics installation to the merged build
    (dashboard + product pricing).

    Run on the SERVER, from an ELEVATED PowerShell:
        powershell -ExecutionPolicy Bypass -File .\Install-QCCAnalytics.ps1 -WhatIf
        powershell -ExecutionPolicy Bypass -File .\Install-QCCAnalytics.ps1

    The app may run either as an NSSM windows service or as a scheduled task -
    the IT installer (2-install-service.ps1) falls back to a task when NSSM is
    missing, and both are named QCCAnalytics. This script finds either one by
    looking for whatever runs dist\index.cjs. Override with -Name / -Target.

    Output is ASCII on purpose - Windows Server consoles render Hebrew as mojibake.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $Name,
    [string] $Target,
    [switch] $SkipEnv
)

$ErrorActionPreference = 'Stop'
# Load these up front with -WhatIf off: auto-loading a module under -WhatIf
# prints a dozen "What if: Set Alias" lines that clutter the preview.
$prevWhatIf = $WhatIfPreference
$WhatIfPreference = $false
Import-Module CimCmdlets, ScheduledTasks -ErrorAction SilentlyContinue
$WhatIfPreference = $prevWhatIf

$root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$payload = Join-Path $root 'payload'
$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'

function Step($t) { Write-Host "`n==> $t" -ForegroundColor Cyan }
function Info($t) { Write-Host "    $t" }
function Warn($t) { Write-Host "    ! $t" -ForegroundColor Yellow }

# Stopping and starting a service or a SYSTEM-owned scheduled task both need
# elevation. Without it the run gets half way: the files are replaced (node does
# not hold them open) while the old process keeps serving from memory, which
# looks like "the deploy did nothing". Refuse up front instead.
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'must run as Administrator (right-click PowerShell -> Run as administrator).'
}

# ------------------------------------------------------------------ payload
Step 'Pre-flight'
foreach ($p in @('dist\index.cjs', 'dist\public\index.html',
                 'data\pricing\pricelist.xlsx', 'data\pricing\customer-overrides.json')) {
    if (-not (Test-Path (Join-Path $payload $p))) { throw "payload is incomplete, missing: $p" }
}
Info 'payload OK'

$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if ($node) {
    $ver = (& $node --version).TrimStart('v')
    Info "node on PATH: v$ver"
    if ([int]($ver -split '\.')[0] -lt 20) { Warn 'node older than 20 - this build expects 20 or newer' }
} else {
    Warn 'node is not on PATH here; that is fine if the runner points at a specific node.exe'
}

# --------------------------------------------------- find the existing install
function Get-Installations {
    # 1. NSSM-wrapped or plain windows services
    foreach ($svc in Get-CimInstance Win32_Service) {
        $dir = $null
        $params = "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.Name)\Parameters"
        if (Test-Path $params) {
            $p = Get-ItemProperty $params -ErrorAction SilentlyContinue
            if ($p.AppParameters -match 'index\.cjs' -and $p.AppDirectory) { $dir = $p.AppDirectory }
        }
        if (-not $dir -and $svc.PathName -match '"?([A-Za-z]:\\[^"]*?)\\dist\\index\.cjs') { $dir = $Matches[1] }
        if ($dir -and (Test-Path (Join-Path $dir 'dist\index.cjs'))) {
            [pscustomobject]@{ Kind = 'Service'; Name = $svc.Name; State = $svc.State; Directory = $dir }
        }
    }
    # 2. scheduled task - what the IT installer creates when NSSM is absent
    foreach ($task in (Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        foreach ($a in $task.Actions) {
            $args = [string]$a.Arguments
            $wd   = [string]$a.WorkingDirectory
            if ($args -notmatch 'index\.cjs') { continue }
            $dir = $wd
            if (-not $dir -and $args -match '"?([A-Za-z]:\\[^"]*?)\\dist\\index\.cjs') { $dir = $Matches[1] }
            if ($dir -and (Test-Path (Join-Path $dir 'dist\index.cjs'))) {
                [pscustomobject]@{
                    Kind = 'Task'; Name = $task.TaskName
                    State = (Get-ScheduledTask -TaskName $task.TaskName).State; Directory = $dir
                }
            }
        }
    }
}

Step 'Locating the existing installation'
$install = $null
if ($Name -and $Target) {
    $kind = if (Get-Service -Name $Name -ErrorAction SilentlyContinue) { 'Service' } else { 'Task' }
    $install = [pscustomobject]@{ Kind = $kind; Name = $Name; State = 'unknown'; Directory = $Target }
} else {
    $found = @(Get-Installations)
    if ($found.Count -eq 0) {
        throw "could not find a service or scheduled task running dist\index.cjs. Pass -Name <name> -Target <install dir> explicitly."
    }
    if ($found.Count -gt 1) {
        $found | ForEach-Object { Warn "candidate: [$($_.Kind)] $($_.Name) -> $($_.Directory)" }
        throw 'more than one candidate found. Pass -Name to choose.'
    }
    $install = $found[0]
}
$Target = $install.Directory
if (-not (Test-Path (Join-Path $Target 'dist\index.cjs'))) { throw "no build found under: $Target" }
Info "runs as:   $($install.Kind) '$($install.Name)' ($($install.State))"
Info "directory: $Target"
Info ('current build: {0:N0} bytes, {1}' -f (Get-Item (Join-Path $Target 'dist\index.cjs')).Length,
      (Get-Item (Join-Path $Target 'dist\index.cjs')).LastWriteTime)

# ------------------------------------------------------------------- .env read
$envPath = Join-Path $Target '.env'
$port = 5000
$envText = ''
if (Test-Path $envPath) {
    $envText = Get-Content $envPath -Raw
    $m = [regex]::Match($envText, '(?m)^\s*PORT\s*=\s*(\d+)')
    if ($m.Success) { $port = [int]$m.Groups[1].Value }
    Info "port from .env: $port"
    # The pricing screen reads Priority through the same credentials the dashboard
    # already uses. Without them there are no MABA numbers - the point of the screen.
    if ($envText -match '(?m)^\s*SQL_UID\s*=\s*\S' -and $envText -match '(?m)^\s*SQL_PWD\s*=\s*\S') {
        Info 'Priority credentials (SQL_UID/SQL_PWD): present'
    } else {
        Warn 'SQL_UID/SQL_PWD are empty - pricing will load, but with no MABA numbers'
    }
} else {
    Warn "no .env in $Target - the app needs at least DATABASE_URL there"
}

# ------------------------------------------------------------------- stop
function Stop-App($inst, $port) {
    if ($inst.Kind -eq 'Service') {
        Stop-Service -Name $inst.Name -Force
        (Get-Service $inst.Name).WaitForStatus('Stopped', '00:01:00')
    } else {
        Stop-ScheduledTask -TaskName $inst.Name
    }
    # The only trustworthy proof that the app is down is that the port is free.
    # A task stop returns immediately, and a stop that silently fails used to let
    # the deploy continue against a live process - replacing files under it while
    # it kept serving the old build from memory.
    foreach ($i in 1..30) {
        Start-Sleep -Seconds 1
        if (-not (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)) { return }
    }
    # not $pid - that is PowerShell's own process id and is read-only
    $holder = (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue |
               Select-Object -First 1).OwningProcess
    throw ("port $port is still in use by process $holder after 30s - the app did not stop. " +
           "Nothing was changed. Stop it manually (Stop-Process -Id $holder -Force) and run again.")
}
function Start-App($inst) {
    if ($inst.Kind -eq 'Service') {
        Start-Service -Name $inst.Name
        (Get-Service $inst.Name).WaitForStatus('Running', '00:01:00')
    } else {
        Start-ScheduledTask -TaskName $inst.Name
    }
}

Step "Stopping $($install.Kind.ToLower()) '$($install.Name)'"
if ($PSCmdlet.ShouldProcess($install.Name, 'Stop')) { Stop-App $install $port; Info 'stopped' }

try {
    # --------------------------------------------------------------- backup
    Step 'Backing up the current build'
    $backup = Join-Path $Target "dist_bak_$stamp"
    if ($PSCmdlet.ShouldProcess($backup, 'Copy current dist')) {
        Copy-Item (Join-Path $Target 'dist') $backup -Recurse -Force
        Info "saved to $backup"
    }

    # ----------------------------------------------------------------- dist
    Step 'Installing the new build'
    if ($PSCmdlet.ShouldProcess((Join-Path $Target 'dist'), 'Replace dist')) {
        Remove-Item (Join-Path $Target 'dist') -Recurse -Force
        Copy-Item (Join-Path $payload 'dist') (Join-Path $Target 'dist') -Recurse -Force
        Info ('installed {0:N0} bytes' -f (Get-Item (Join-Path $Target 'dist\index.cjs')).Length)
        Info 'this build is self-contained - node_modules is no longer required'
    }

    # ----------------------------------------------------------------- data
    # Written at runtime: every match a user confirms is stored here. Existing
    # files are never overwritten, or a deploy would erase the learning.
    Step 'Installing the pricing data'
    $targetData = Join-Path $Target 'data\pricing'
    if (Test-Path $targetData) {
        Warn 'data\pricing already exists - keeping it, adding only missing files'
        if ($PSCmdlet.ShouldProcess($targetData, 'Add missing files only')) {
            Get-ChildItem (Join-Path $payload 'data\pricing') -File | ForEach-Object {
                $dest = Join-Path $targetData $_.Name
                if (Test-Path $dest) { Info "kept   $($_.Name)" }
                else { Copy-Item $_.FullName $dest; Info "added  $($_.Name)" }
            }
        }
    } elseif ($PSCmdlet.ShouldProcess($targetData, 'Copy data\pricing')) {
        New-Item -ItemType Directory -Path (Join-Path $Target 'data') -Force | Out-Null
        Copy-Item (Join-Path $payload 'data\pricing') $targetData -Recurse -Force
        Info "copied $((Get-ChildItem $targetData -File).Count) files"
    }

    # ------------------------------------------------------------------ env
    if (-not $SkipEnv) {
        Step 'Updating .env'
        $additions = @(Get-Content (Join-Path $root 'env-additions.txt'))
        # The pricing data folder is resolved from the process working directory.
        # A runner whose working directory is not the install folder would look in
        # the wrong place, so the path is pinned explicitly.
        $additions += "PRICING_DATA_DIR=$targetData"

        # Credentials are REPLACED, not merely added: this server already has a
        # DASHBOARD_USER/PASSWORD from the IT install, and the point of setting
        # them here is to hand everyone one known pair.
        $replaceKeys = @('DASHBOARD_USER', 'DASHBOARD_PASSWORD')
        $existing = if (Test-Path $envPath) { @(Get-Content $envPath) } else { @() }
        $toAdd = @(); $toReplace = @{}
        foreach ($line in $additions) {
            if ($line -notmatch '^\s*([A-Z_]+)=') { continue }
            $key = $Matches[1]
            $present = @($existing | Where-Object { $_ -match "^\s*$key=" }).Count -gt 0
            if ($present -and $replaceKeys -contains $key) { $toReplace[$key] = $line }
            elseif ($present) { Info "kept existing $key" }
            else { $toAdd += $line }
        }
        if ($toAdd.Count -eq 0 -and $toReplace.Count -eq 0) { Info 'nothing to change' }
        elseif ($PSCmdlet.ShouldProcess($envPath, "Append $($toAdd.Count), replace $($toReplace.Count)")) {
            if (Test-Path $envPath) { Copy-Item $envPath (Join-Path $Target ".env.bak_$stamp") -Force }
            if ($toReplace.Count -gt 0) {
                $lines = $existing | ForEach-Object {
                    if ($_ -match '^\s*([A-Z_]+)=' -and $toReplace.ContainsKey($Matches[1])) { $toReplace[$Matches[1]] }
                    else { $_ }
                }
                Set-Content -Path $envPath -Value $lines -Encoding ascii
                Info ('replaced: ' + ($toReplace.Keys -join ', '))
            }
            if ($toAdd.Count -gt 0) {
                Add-Content $envPath ''
                Add-Content $envPath '# --- added by Install-QCCAnalytics.ps1 (product pricing) ---'
                $toAdd | ForEach-Object { Add-Content $envPath $_ }
                Info ('added: ' + (($toAdd | ForEach-Object { ($_ -split '=')[0] }) -join ', '))
            }
        }
    }
}
finally {
    Step "Starting $($install.Kind.ToLower()) '$($install.Name)'"
    if ($PSCmdlet.ShouldProcess($install.Name, 'Start')) { Start-App $install; Info 'started' }
}

# --------------------------------------------------------------- verify
Step 'Verifying'
if ($PSCmdlet.ShouldProcess("http://localhost:$port", 'Health checks')) {
    $ok = $true
    $up = $false
    foreach ($i in 1..30) {
        Start-Sleep -Seconds 2
        try { if ((Invoke-WebRequest "http://localhost:$port/" -TimeoutSec 10 -UseBasicParsing).StatusCode -eq 200) { $up = $true; break } } catch { }
    }
    if ($up) { Info 'dashboard: HTTP 200' } else { Warn 'the dashboard did not answer within 60s - check logs\service.err.log'; $ok = $false }

    if ($up) {
        try {
            $h = Invoke-RestMethod "http://localhost:$port/api/pricing/health" -TimeoutSec 30
            if ($h.itemsLoaded -gt 0) { Info "pricing:   $($h.itemsLoaded) price list items" }
            else { Warn 'the price list is EMPTY - check data\pricing and PRICING_DATA_DIR'; $ok = $false }
        } catch { Warn "pricing health check failed: $($_.Exception.Message)"; $ok = $false }

        try {
            $s = Invoke-RestMethod "http://localhost:$port/api/pricing/source-status" -TimeoutSec 60
            if ($s.priorityConnected) { Info "priority:  connected, $($s.modelsInIndex) models" }
            else { Warn 'Priority NOT connected - there will be no MABA numbers. Check SQL_UID/SQL_PWD in .env'; $ok = $false }
        } catch { Warn "source-status failed: $($_.Exception.Message)"; $ok = $false }

        try {
            $c = Invoke-WebRequest "http://localhost:$port/api/customers/list" -TimeoutSec 90 -UseBasicParsing
            Info "database:  /api/customers/list HTTP $($c.StatusCode)"
        } catch { Warn "database-backed endpoint failed: $($_.Exception.Message)"; $ok = $false }
    }

    $user = ''
    if (Test-Path $envPath) {
        $m = [regex]::Match((Get-Content $envPath -Raw), '(?m)^\s*DASHBOARD_USER\s*=\s*(\S+)')
        if ($m.Success) { $user = $m.Groups[1].Value }
    }
    Write-Host ''
    if ($ok) {
        Write-Host 'DEPLOY OK' -ForegroundColor Green
        Write-Host "  local:   http://localhost:$port/pricing"
        Write-Host "  network: http://$($env:COMPUTERNAME):$port/pricing"
        Write-Host "  sign in: user '$user', password as set in $envPath"
    } else {
        Write-Host 'DEPLOY FINISHED WITH WARNINGS - see above' -ForegroundColor Yellow
        Write-Host "  roll back with: .\Rollback-QCCAnalytics.ps1 -Name $($install.Name) -Target `"$Target`""
    }
}
