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
    * procedure and function bodies, with whitespace and case ignored (MBA-999)
    * defaults, check constraints, foreign keys and indexes (MBA-999)

  The last group is matched by what a constraint does, not by its name, because many on STAGE carry
  system-generated names (DF__CrmDevice__Refre__06703FA0) that can never match the other server.
  It was added after the 31/08 production package created tables with their columns only: every
  column matched, so this script reported nothing, and on 2026-10-25 the first validator note and the
  first portal request both failed on PROD for want of a DEFAULT.

  Read-only. Credentials come from the app clone's .env (a sibling of this repo) and are never printed.

  Differences that are known and accepted - a feature still in test on STAGE, PROD's own sync
  monitoring - are listed in Compare-Schema.expected.txt with their reason and ticket. Everything
  else is "unexpected". With -FailOnUnexpected the script exits 1 on any unexpected difference: run it
  that way before and after every PROD deploy, and do not merge app stg -> main while it fails.

.EXAMPLE
  .\Compare-Schema.ps1                        # summary: unexpected differences listed, accepted counted
  .\Compare-Schema.ps1 -Detailed              # also lists every accepted difference and its reason
  .\Compare-Schema.ps1 -FailOnUnexpected      # the release gate: exit code 1 on anything unexpected
#>
[CmdletBinding()]
param(
    [switch]$Detailed,
    # Exit 1 when any difference is not in the accepted list: the release gate.
    [switch]$FailOnUnexpected,
    [string]$ExpectedPath = (Join-Path $PSScriptRoot 'Compare-Schema.expected.txt'),
    # GIT_ROOT\app\.env: the app repo is checked out beside this one.
    [string]$EnvPath = (Join-Path $PSScriptRoot '..\..\app\.env')
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

# Keyed by content: table + column for a default, table + definition for a check, the column mapping
# for a foreign key, the key/include/filter shape for an index. Names stay out of the key on purpose.
$Q_CONSTRAINTS = @'
SELECT CAST('DEFAULT ' + s.name + '.' + t.name + '.' + c.name AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT AS k,
       CAST(LOWER(d.definition) AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT AS v
FROM sys.default_constraints d
JOIN sys.tables t  ON t.object_id = d.parent_object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.columns c ON c.object_id = d.parent_object_id AND c.column_id = d.parent_column_id
WHERE t.is_ms_shipped = 0
UNION ALL
SELECT CAST('CHECK ' + s.name + '.' + t.name + ' ' + LOWER(k.definition) AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT,
       CAST('enabled=' + CAST(1 - k.is_disabled AS VARCHAR(1)) AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.check_constraints k
JOIN sys.tables t  ON t.object_id = k.parent_object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE t.is_ms_shipped = 0
UNION ALL
SELECT CAST('FK ' + s.name + '.' + t.name + ' (' +
       STUFF((SELECT ',' + pc.name FROM sys.foreign_key_columns fc
              JOIN sys.columns pc ON pc.object_id = fc.parent_object_id AND pc.column_id = fc.parent_column_id
              WHERE fc.constraint_object_id = f.object_id ORDER BY fc.constraint_column_id FOR XML PATH('')), 1, 1, '')
       + ') -> ' + OBJECT_SCHEMA_NAME(f.referenced_object_id) + '.' + OBJECT_NAME(f.referenced_object_id) + ' (' +
       STUFF((SELECT ',' + rc.name FROM sys.foreign_key_columns fc
              JOIN sys.columns rc ON rc.object_id = fc.referenced_object_id AND rc.column_id = fc.referenced_column_id
              WHERE fc.constraint_object_id = f.object_id ORDER BY fc.constraint_column_id FOR XML PATH('')), 1, 1, '') + ')' AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT,
       CAST('on-delete=' + f.delete_referential_action_desc + ' on-update=' + f.update_referential_action_desc
       + ' trusted=' + CAST(1 - f.is_not_trusted AS VARCHAR(1)) AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.foreign_keys f
JOIN sys.tables t  ON t.object_id = f.parent_object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE t.is_ms_shipped = 0
UNION ALL
SELECT CAST('INDEX ' + s.name + '.' + t.name + ' (' +
       STUFF((SELECT ',' + c.name + CASE WHEN ic.is_descending_key = 1 THEN ' desc' ELSE '' END
              FROM sys.index_columns ic JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
              WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
              ORDER BY ic.key_ordinal FOR XML PATH('')), 1, 1, '') + ')'
       + ISNULL(' include (' + STUFF((SELECT ',' + c.name
              FROM sys.index_columns ic JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
              WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
              ORDER BY c.name FOR XML PATH('')), 1, 1, '') + ')', '')
       + ISNULL(' where ' + LOWER(i.filter_definition), '') AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT,
       CAST(LOWER(i.type_desc) + CASE WHEN i.is_primary_key = 1 THEN ' primary key'
                                 WHEN i.is_unique = 1 THEN ' unique' ELSE '' END AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.indexes i
JOIN sys.tables t  ON t.object_id = i.object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE t.is_ms_shipped = 0 AND i.type > 0;
'@

# Procedure and function BODIES, compared with whitespace and case removed - the check behind every
# release's "what is on STAGE and not on PROD" list. Routines present on one side only are already
# reported by the parameter comparison, so only bodies that differ are counted here.
$Q_BODIES = @'
SELECT s.name + '.' + o.name AS k,
       CONVERT(VARCHAR(64), HASHBYTES('SHA2_256',
           LOWER(REPLACE(REPLACE(REPLACE(REPLACE(m.definition, N' ', N''), NCHAR(9), N''), NCHAR(10), N''), NCHAR(13), N''))), 2) AS v
FROM sys.sql_modules m
JOIN sys.objects o ON o.object_id = m.object_id
JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE o.is_ms_shipped = 0;
'@

# Differences everyone already knows about, one per line: SECTION | KIND | key pattern | reason.
# A difference that matches is reported as accepted and does not count; anything else counts.
$expected = @()
if (Test-Path $ExpectedPath) {
    foreach ($line in Get-Content -LiteralPath $ExpectedPath -Encoding UTF8) {
        if ($line -match '^\s*(#|$)') { continue }
        $parts = $line -split '\|', 4
        if ($parts.Count -lt 3) { continue }
        $expected += [pscustomobject]@{
            Section = $parts[0].Trim(); Kind = $parts[1].Trim(); Pattern = $parts[2].Trim()
            Reason  = if ($parts.Count -ge 4) { $parts[3].Trim() } else { '' }
        }
    }
}

function Get-Accepted([string]$section, [string]$kind, [string]$key) {
    $expected | Where-Object {
        $_.Section -eq $section -and ($_.Kind -eq '*' -or $_.Kind -eq $kind) -and $key -like $_.Pattern
    } | Select-Object -First 1
}

function Compare-Set([string]$section, [string]$label, $stage, $prod, [switch]$DiffersOnly) {
    $S = @{}; foreach ($r in $stage.Rows) { $S[$r.k] = $r.v }
    $P = @{}; foreach ($r in $prod.Rows) { $P[$r.k] = $r.v }

    $found = @()
    if (-not $DiffersOnly) {
        $found += $S.Keys | Where-Object { -not $P.ContainsKey($_) } | Sort-Object |
                  ForEach-Object { [pscustomobject]@{ Kind = 'STAGE only'; Key = $_; Detail = "[$($S[$_])]" } }
        $found += $P.Keys | Where-Object { -not $S.ContainsKey($_) } | Sort-Object |
                  ForEach-Object { [pscustomobject]@{ Kind = 'PROD only'; Key = $_; Detail = "[$($P[$_])]" } }
    }
    $found += $S.Keys | Where-Object { $P.ContainsKey($_) -and $P[$_] -ne $S[$_] } | Sort-Object |
              ForEach-Object { [pscustomobject]@{ Kind = 'DIFFERS'; Key = $_; Detail = "STAGE [$($S[$_])]  PROD [$($P[$_])]" } }

    $unexpected = @(); $accepted = @()
    foreach ($f in $found) {
        $hit = Get-Accepted $section $f.Kind $f.Key
        if ($hit) { $accepted += [pscustomobject]@{ F = $f; Reason = $hit.Reason } } else { $unexpected += $f }
    }

    # Write-Host, not bare strings: a bare string would land on the pipeline and become part of
    # this function's return value, which is meant to be the unexpected count alone.
    Write-Host "`n== $label ==" -ForegroundColor Cyan
    Write-Host ("{0,-34} {1}" -f 'unexpected', $unexpected.Count) -ForegroundColor $(if ($unexpected.Count) { 'Red' } else { 'Green' })
    Write-Host ("{0,-34} {1}" -f 'accepted (Compare-Schema.expected.txt)', $accepted.Count) -ForegroundColor DarkGray
    foreach ($f in $unexpected) { Write-Host ("  {0,-10} : {1}  {2}" -f $f.Kind, $f.Key, $f.Detail) -ForegroundColor Red }
    if ($Detailed) {
        foreach ($a in $accepted) { Write-Host ("  accepted   : {0} {1}  ({2})" -f $a.F.Kind, $a.F.Key, $a.Reason) -ForegroundColor DarkGray }
    }

    $unexpected.Count
}

$stageCs = Get-Conn 'STAGE'
$prodCs  = Get-Conn 'PROD'
Write-Host "comparing Calibrator (STAGE) <-> CalibratorProd (PROD)" -ForegroundColor DarkGray
Write-Host "accepted differences: $ExpectedPath ($($expected.Count) entries)" -ForegroundColor DarkGray

$total = 0
$total += Compare-Set 'COLUMNS'     'COLUMNS' (Invoke-Q $stageCs $Q_COLUMNS) (Invoke-Q $prodCs $Q_COLUMNS)
$total += Compare-Set 'ROUTINES'    'PROCEDURES / FUNCTIONS / VIEWS (presence, parameters)' (Invoke-Q $stageCs $Q_ROUTINES) (Invoke-Q $prodCs $Q_ROUTINES)
$total += Compare-Set 'BODIES'      'PROCEDURE / FUNCTION BODIES (whitespace and case ignored)' (Invoke-Q $stageCs $Q_BODIES) (Invoke-Q $prodCs $Q_BODIES) -DiffersOnly
$total += Compare-Set 'CONSTRAINTS' 'DEFAULTS / CHECKS / FOREIGN KEYS / INDEXES' (Invoke-Q $stageCs $Q_CONSTRAINTS) (Invoke-Q $prodCs $Q_CONSTRAINTS)

Write-Host ("`nUNEXPECTED DIFFERENCES: {0}" -f $total) -ForegroundColor $(if ($total) { 'Red' } else { 'Green' })
if ($total) {
    Write-Host "Each one is either work to deploy or a new entry for Compare-Schema.expected.txt, with its reason and ticket." -ForegroundColor DarkGray
    Write-Host "Do not merge to app main or finish a PROD deploy while this is not zero." -ForegroundColor DarkGray
}
if ($FailOnUnexpected -and $total) { exit 1 }
