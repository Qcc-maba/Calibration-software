<#
.SYNOPSIS
    Deploys the MBA-943 portal customer-scope change (18 objects) to one environment.

.DESCRIPTION
    A portal login is an e-mail address, and an e-mail address is not one customer. Every
    GetCustomer* procedure used to collapse that to the lowest CustomerContactId, which for a
    contact serving several companies routinely landed on a company record holding no devices.
    This deploys the replacement: dbo.GetPortalCustomerIds plus the 17 objects that consume it.

    THE SCRIPT BACKS UP FIRST. Every object's current definition is written to a timestamped
    .sql file before anything is changed, so a rollback is running that one file.

    TWO TRAPS THIS SCRIPT EXISTS TO AVOID
    -------------------------------------
    1. sqlcmd -i reads a UTF-8 file in the CONSOLE CODEPAGE unless told otherwise, which stores
       Hebrew literals as mojibake. The deploy SUCCEEDS and the damage only shows when a screen
       renders the literal. Hence -f 65001 on every call, and a verification pass afterwards.

    2. Order matters. dbo.GetPortalCustomerIds must exist before the procedures that reference
       it, so it is first in the list and a failure there aborts the run.

    Hebrew is deliberately absent from this file: console output is ASCII so it stays readable
    on a Windows Server console, and the one Hebrew string needed for verification is built from
    NCHAR codes rather than a literal - which also means this script cannot itself fall into
    trap 1.

.PARAMETER Environment
    Stage or Prod. Selects the connection from the repo's existing config files.

.PARAMETER WhatIf
    Back up and validate connectivity, then stop without deploying.

.EXAMPLE
    .\scripts\Deploy-PortalCustomerScope.ps1 -Environment Stage
    .\scripts\Deploy-PortalCustomerScope.ps1 -Environment Prod -WhatIf
    .\scripts\Deploy-PortalCustomerScope.ps1 -Environment Prod
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Stage', 'Prod')]
    [string]$Environment
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

# Deployment order: the function first, everything that calls it after.
$objects = @(
    'dbo.GetPortalCustomerIds'
    'dbo.GetCustomerDeviceList'
    'dbo.GetCustomerDeviceDetail'
    'dbo.GetCustomerDashboardData'
    'dbo.GetCustomerCalibrationReports'
    'dbo.GetCustomerRequests'
    'dbo.GetCustomerPortalRequestList'
    'dbo.GetCustomerShipments'
    'dbo.GetCustomerInvoicesQuotes'
    'dbo.GetCustomerUpcommingCalibrationInfo'
    'dbo.GetCustomerContacts'
    'dbo.GetCustomerSites'
    'dbo.GetCustomerProfile'
    'dbo.GetCustomerSupportData'
    'dbo.GetCustomerInvoicesFromPriority'
    'dbo.GetCustomerQuotesFromPriority'
    'dbo.GetCustomerPortalContactByEmail'
    'dbo.CreateCustomerPortalOtp'
)

function Get-Target {
    param([string]$Env)

    if ($Env -eq 'Stage') {
        $path = Join-Path $repo 'Systems\CustomerPortalApi\appsettings.Development.json'
        if (-not (Test-Path $path)) { throw "Stage config not found: $path" }
        $cs = (Get-Content $path -Raw | ConvertFrom-Json).CustomerPortal.ConnectionString
        return [pscustomobject]@{
            Server   = ([regex]::Match($cs, 'Server=([^;]*)')).Groups[1].Value
            Database = ([regex]::Match($cs, 'Database=([^;]*)')).Groups[1].Value
            User     = ([regex]::Match($cs, 'User Id=([^;]*)')).Groups[1].Value
            Password = ([regex]::Match($cs, 'Password=([^;]*)')).Groups[1].Value
        }
    }

    $path = Join-Path $repo 'app\.env'
    if (-not (Test-Path $path)) { throw "Prod config not found: $path" }
    $line = Get-Content $path | Where-Object { $_ -match 'REMOTE_DATABASE_URL_PROD' } | Select-Object -First 1
    if (-not $line) { throw 'REMOTE_DATABASE_URL_PROD not found in app/.env' }
    $url = ($line -replace '^[^=]*=', '') -replace '"', ''
    return [pscustomobject]@{
        Server   = ($url -replace '^sqlserver://', '') -split ';' | Select-Object -First 1
        Database = ([regex]::Match($url, 'database=([^;]*)')).Groups[1].Value
        User     = ([regex]::Match($url, 'user=([^;]*)')).Groups[1].Value
        Password = ([regex]::Match($url, 'password=([^;]*)')).Groups[1].Value
    }
}

function Invoke-Sql {
    param($Target, [string]$Query)
    # No 2>&1: under $ErrorActionPreference='Stop' PS 5.1 turns a native command's stderr into a
    # terminating error, so our own handling never runs. stderr is captured for us already.
    return sqlcmd -S $Target.Server -d $Target.Database -U $Target.User -P $Target.Password `
                  -C -W -s '|' -h -1 -Q $Query
}

$target = Get-Target -Env $Environment
Write-Output "Target      : $($target.Server) / $($target.Database) as $($target.User)"
Write-Output "Objects     : $($objects.Count)"

# ---- connectivity ------------------------------------------------------------------------
$probe = Invoke-Sql -Target $target -Query "SET NOCOUNT ON; SELECT 'ok';"
if ($probe -notcontains 'ok') { throw "Cannot reach $($target.Server)/$($target.Database)" }
Write-Output 'Connectivity: ok'

# ---- backup ------------------------------------------------------------------------------
$stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $repo 'database\_rollback'
# -WhatIf:$false because SupportsShouldProcess propagates $WhatIfPreference to child cmdlets, so
# under -WhatIf the directory would not be created and the backup write below would fail. The
# backup is the whole point of a dry run, so it must happen in both modes.
if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force -WhatIf:$false | Out-Null }
$backup = Join-Path $backupDir "portal-scope-$($Environment.ToLower())-$stamp.sql"

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("/* Rollback for MBA-943 on $Environment, captured $stamp.")
[void]$sb.AppendLine("   Run this whole file with:  sqlcmd -S <srv> -d <db> -U <u> -P <p> -C -I -f 65001 -i <this file>")
[void]$sb.AppendLine("   Objects that did not exist before the deploy appear here as a DROP. */")
[void]$sb.AppendLine('SET ANSI_NULLS ON;')
[void]$sb.AppendLine('GO')
[void]$sb.AppendLine('SET QUOTED_IDENTIFIER ON;')
[void]$sb.AppendLine('GO')

foreach ($o in $objects) {
    # -y 0 (unlimited width, needed for a full definition) cannot be combined with -h; sqlcmd
    # rejects the pair outright. SET NOCOUNT ON plus trimming the header below does the same job.
    $def = (sqlcmd -S $target.Server -d $target.Database -U $target.User -P $target.Password `
                   -C -y 0 -Q "SET NOCOUNT ON; SELECT OBJECT_DEFINITION(OBJECT_ID('$o'));") -join "`n"
    $def = ($def -split "`n" | Select-Object -Skip 2) -join "`n"   # drop sqlcmd's column header + rule
    if ([string]::IsNullOrWhiteSpace($def) -or $def.Trim() -eq 'NULL') {
        [void]$sb.AppendLine("/* $o did not exist before this deploy */")
        [void]$sb.AppendLine("DROP $(if ($o -eq 'dbo.GetPortalCustomerIds') { 'FUNCTION' } else { 'PROCEDURE' }) IF EXISTS $o;")
        [void]$sb.AppendLine('GO')
    }
    else {
        # OBJECT_DEFINITION returns the original "CREATE PROCEDURE" text. Replayed as-is against a
        # database where the object still exists, every batch fails with "already an object named".
        # A rollback file that cannot run is not a rollback file, so rewrite the verb.
        $runnable = [regex]::Replace($def.Trim(),
                                     '^(\s*)CREATE\s+(PROCEDURE|FUNCTION|VIEW|TRIGGER)\b',
                                     '$1CREATE OR ALTER $2',
                                     'Multiline')
        [void]$sb.AppendLine($runnable)
        [void]$sb.AppendLine('GO')
    }
}

# UTF-8 WITH BOM: the rollback file carries Hebrew literals, and this is what makes it survive
# a later -f 65001 read as well as an editor round-trip.
[IO.File]::WriteAllText($backup, $sb.ToString(), (New-Object Text.UTF8Encoding $true))
Write-Output "Backup      : $backup"

if ($WhatIfPreference) {
    Write-Output 'WhatIf      : backup written, nothing deployed.'
    return
}

if (-not $PSCmdlet.ShouldProcess("$($target.Database) on $($target.Server)", "deploy $($objects.Count) objects")) {
    return
}

# ---- deploy ------------------------------------------------------------------------------
$failed = @()
foreach ($o in $objects) {
    $file = Join-Path $repo "database\procedures\$o.sql"
    if (-not (Test-Path $file)) { throw "Missing source file: $file" }

    # -f 65001 is not optional. See the header.
    $out = sqlcmd -S $target.Server -d $target.Database -U $target.User -P $target.Password `
                  -C -I -f 65001 -i $file
    if ($LASTEXITCODE -ne 0 -or $out) {
        $failed += $o
        Write-Output "FAIL  $o"
        $out | ForEach-Object { "      $_" }
        if ($o -eq 'dbo.GetPortalCustomerIds') {
            throw 'GetPortalCustomerIds failed to deploy; everything else depends on it. Aborting before any procedure is changed.'
        }
    }
    else {
        Write-Output "ok    $o"
    }
}

# ---- verify ------------------------------------------------------------------------------
# 'lakoach' built from code points, so this check cannot itself be corrupted by an encoding slip.
$lakoach = 'NCHAR(1500)+NCHAR(1511)+NCHAR(1493)+NCHAR(1495)'
$verify = @"
SET NOCOUNT ON;
DECLARE @needle NVARCHAR(10) = $lakoach;
SELECT CASE WHEN COUNT(*) = 0 THEN 'HEBREW-OK' ELSE 'HEBREW-CORRUPTED' END
FROM sys.objects o
WHERE o.name IN ('GetCustomerDeviceList','GetCustomerDeviceDetail','GetCustomerDashboardData')
  AND OBJECT_DEFINITION(o.object_id) NOT LIKE N'%' + @needle + N'%';

SELECT CASE WHEN COUNT(*) = 0 THEN 'PARAM-OK' ELSE 'STALE-SelectedCustomerId' END
FROM sys.parameters pa
JOIN sys.procedures pr ON pr.object_id = pa.object_id
WHERE pa.name = '@SelectedCustomerId';

SELECT CASE WHEN COUNT(*) = $($objects.Count - 1) THEN 'WIRED-OK'
            ELSE CONCAT('ONLY ', COUNT(*), ' of $($objects.Count - 1) use the function') END
FROM sys.objects o
WHERE o.type IN ('P','FN','IF','TF')
  AND OBJECT_DEFINITION(o.object_id) LIKE '%GetPortalCustomerIds%'
  AND o.name <> 'GetPortalCustomerIds';
"@

Write-Output '--- verification ---'
Invoke-Sql -Target $target -Query $verify | Where-Object { $_ -and $_ -notmatch '^-+$' }

if ($failed.Count -gt 0) {
    Write-Output ''
    Write-Output "FAILED objects: $($failed -join ', ')"
    Write-Output "Roll back with: sqlcmd -S $($target.Server) -d $($target.Database) -U $($target.User) -P <password> -C -I -f 65001 -i `"$backup`""
    exit 1
}

Write-Output ''
Write-Output "Done. Rollback file: $backup"
