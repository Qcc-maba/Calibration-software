<#
.SYNOPSIS
  Reports schema drift between Calibrator (STAGE) and CalibratorProd (PROD).

.DESCRIPTION
  Nobody was checking this, and it bit us: dbo.MeasurmentPointsToOrderDetailsItems had 23 columns on
  STAGE and 19 on PROD, and the gap only surfaced when a stored procedure refused to compile on PROD
  with "Invalid column name 'SerialNumber'". The FE feature behind it could never have worked in
  production. This script surfaces that class of difference before a deploy does.

  Compares, in both directions:
    * tables present on one side only
    * columns present on one side only, and columns whose type / nullability differ
    * procedures and functions present on one side only
    * procedures whose parameter list differs (a caller written for one will fail on the other)

  Read-only. Credentials come from app/.env and are never printed.

.EXAMPLE
  .\Compare-Schema.ps1                 # summary
  .\Compare-Schema.ps1 -Detailed       # every differing column and parameter
#>
[CmdletBinding()]
param(
    [switch]$Detailed,
    [string]$EnvPath = 'c:\Users\eliran_ha\OneDrive - MBA\Documents\Eliran\MBA\Calibration-software\app\.env'
)
$ErrorActionPreference = 'Stop'

function Get-Conn([string]$target) {
    $line = Select-String -Path $EnvPath -Pattern "^REMOTE_DATABASE_URL_$target=" | Select-Object -First 1
    if (-not $line) { throw "REMOTE_DATABASE_URL_$target not found in $EnvPath" }
    $url = ($line.Line -replace "^REMOTE_DATABASE_URL_$target=", '').Trim().Trim('"')
    $hostPort = ($url -replace '^sqlserver://', '').Split(';')[0]
    function P([string]$k) { $m = [regex]::Match($url, "(?i);$k=(\{[^}]*\}|[^;]*)"); if ($m.Success) { $m.Groups[1].Value.Trim('{', '}') } }
    "Server=$hostPort;Database=$(P 'database');User ID=$(P 'user');Password=$(P 'password');Encrypt=True;TrustServerCertificate=True;Connect Timeout=30"
}

function Invoke-Q([string]$cs, [string]$sql) {
    $c = New-Object System.Data.SqlClient.SqlConnection $cs
    $c.Open()
    try {
        $cmd = $c.CreateCommand(); $cmd.CommandTimeout = 120; $cmd.CommandText = $sql
        $dt = New-Object System.Data.DataTable
        [void](New-Object System.Data.SqlClient.SqlDataAdapter $cmd).Fill($dt)
        , $dt
    }
    finally { $c.Close() }
}

$Q_COLUMNS = @'
SELECT t.TABLE_NAME + '.' + c.COLUMN_NAME AS k,
       c.DATA_TYPE
         + ISNULL('(' + CASE WHEN c.CHARACTER_MAXIMUM_LENGTH = -1 THEN 'max'
                             ELSE CAST(COALESCE(c.CHARACTER_MAXIMUM_LENGTH,
                                                CAST(c.NUMERIC_PRECISION AS INT)) AS VARCHAR(12))
                                  + ISNULL(',' + CAST(c.NUMERIC_SCALE AS VARCHAR(12)), '') END + ')', '')
         + CASE WHEN c.IS_NULLABLE = 'YES' THEN ' NULL' ELSE ' NOT NULL' END AS v
FROM INFORMATION_SCHEMA.COLUMNS c
JOIN INFORMATION_SCHEMA.TABLES t ON t.TABLE_NAME = c.TABLE_NAME AND t.TABLE_SCHEMA = c.TABLE_SCHEMA
WHERE t.TABLE_TYPE = 'BASE TABLE' AND t.TABLE_SCHEMA IN ('dbo','stg','etl');
'@

$Q_ROUTINES = @'
SELECT s.name + '.' + o.name AS k,
       o.type_desc + ' (' + ISNULL(STUFF((SELECT ', ' + p.name + ' ' + TYPE_NAME(p.user_type_id)
                                          FROM sys.parameters p WHERE p.object_id = o.object_id
                                          ORDER BY p.parameter_id FOR XML PATH('')), 1, 2, ''), '') + ')' AS v
FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE o.type IN ('P','FN','TF','IF','V');
'@

function Compare-Set([string]$label, $stage, $prod) {
    $S = @{}; foreach ($r in $stage.Rows) { $S[$r.k] = $r.v }
    $P = @{}; foreach ($r in $prod.Rows) { $P[$r.k] = $r.v }

    $onlyStage = @($S.Keys | Where-Object { -not $P.ContainsKey($_) } | Sort-Object)
    $onlyProd  = @($P.Keys | Where-Object { -not $S.ContainsKey($_) } | Sort-Object)
    $differs   = @($S.Keys | Where-Object { $P.ContainsKey($_) -and $P[$_] -ne $S[$_] } | Sort-Object)

    # Write-Host, not bare strings: a bare string would land on the pipeline and become part of
    # this function's return value, which is meant to be the difference count alone.
    Write-Host "`n== $label ==" -ForegroundColor Cyan
    Write-Host ("{0,-34} {1}" -f 'only on STAGE', $onlyStage.Count)
    Write-Host ("{0,-34} {1}" -f 'only on PROD',  $onlyProd.Count)
    Write-Host ("{0,-34} {1}" -f 'exists on both but DIFFERS', $differs.Count)

    if ($Detailed -or $onlyStage.Count + $onlyProd.Count + $differs.Count -le 25) {
        foreach ($k in $onlyStage) { Write-Host ("  STAGE only : {0}  [{1}]" -f $k, $S[$k]) -ForegroundColor Yellow }
        foreach ($k in $onlyProd)  { Write-Host ("  PROD  only : {0}  [{1}]" -f $k, $P[$k]) -ForegroundColor Yellow }
        foreach ($k in $differs)   { Write-Host ("  DIFFERS    : {0}" -f $k) -ForegroundColor Red
                                     Write-Host ("               STAGE {0}" -f $S[$k])
                                     Write-Host ("               PROD  {0}" -f $P[$k]) }
    }
    else { Write-Host "  (run with -Detailed to list them)" -ForegroundColor DarkGray }

    $onlyStage.Count + $onlyProd.Count + $differs.Count
}

$stageCs = Get-Conn 'STAGE'
$prodCs  = Get-Conn 'PROD'
Write-Host "comparing Calibrator (STAGE) <-> CalibratorProd (PROD)" -ForegroundColor DarkGray

$total = 0
$total += Compare-Set 'COLUMNS' (Invoke-Q $stageCs $Q_COLUMNS) (Invoke-Q $prodCs $Q_COLUMNS)
$total += Compare-Set 'PROCEDURES / FUNCTIONS / VIEWS' (Invoke-Q $stageCs $Q_ROUTINES) (Invoke-Q $prodCs $Q_ROUTINES)

Write-Host ("`nTOTAL DIFFERENCES: {0}" -f $total) -ForegroundColor $(if ($total) { 'Yellow' } else { 'Green' })
Write-Host "Note: some drift is expected and fine — PROD legitimately lags on features still in test." -ForegroundColor DarkGray
Write-Host "What matters is drift you did not know about, especially a column a deployed SP depends on." -ForegroundColor DarkGray
