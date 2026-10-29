# Lists the raw Hydra readings next to the values the VCT compensated them to, from the VCT log,
# and checks each one against the master's certificate in the database - the validation MBA-1007
# asks for, repeatable for any run.
#
# The VCT writes one line per channel per scan to logs\server.log:
#   [HYDRA Correction] CH11 | Raw=22.1000 | Corrected=22.2336 | Status=OK | MasterID=31-98 | From=sensor
# "From" says where the master came from: "sensor" (the one the app associated with the channel) or
# "settings file" (the app associated none). Lines from before MBA-1007 have no From. Channels held
# back because their sensor's certificate is not loaded are logged once per sensor and listed too.
#
# The check uses dbo.fnMasterValueAfterCorrection, the database's own compensation - the reference
# model: one equation per certificate range. The VCT still interpolates between the ranges' start
# points instead (Systems/Hydra-Group/CLAUDE.md); the two agree to about 1e-5 inside a range and
# differ near the certificate's ends, which the BeyondCertificate column shows.
#
# The database is only read. The connection string is taken from the VCT's own exe.config unless
# -ConnectionString is given; -NoDbCheck skips the check entirely.
#
# Examples
#   .\Get-HydraCompensationPairs.ps1 -From '2026-10-29 08:49' -To '2026-10-29 09:20' | Format-Table
#   .\Get-HydraCompensationPairs.ps1 -LogPath \\station\logs\server.log -Channel 11,12 -CsvPath pairs.csv
#
# Console output is ASCII: Windows Server consoles render Hebrew as mojibake.

param(
    # The VCT log. Defaults to the ConsoleHost build's log in this repository.
    [string]$LogPath,
    [datetime]$From,
    [datetime]$To,
    [int[]]$Channel,
    # Defaults to REMOTE_DATABASE_URL from the ConsoleHost exe.config beside the log.
    [string]$ConnectionString,
    [switch]$NoDbCheck,
    # Largest difference still counted as a match. The log prints 4 decimals, so 5e-5 is rounding.
    [double]$Tolerance = 0.0001,
    [string]$CsvPath
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$hostDir = Join-Path $root 'Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin'

if (-not $LogPath) { $LogPath = Join-Path $hostDir 'logs\server.log' }
if (-not (Test-Path $LogPath)) { throw "Log not found: $LogPath - pass -LogPath." }

$line = '^INFO :: (?<t>\d{8}-\d\d:\d\d:\d\d\.\d+) ::\[HYDRA Correction\] CH(?<ch>[\d,]+) \| ' +
        '(?:Raw=(?<raw>-?[\d.]+) \| Corrected=(?<corr>-?[\d.]+) \| Status=(?<st>\w+) \| MasterID=(?<m>\S*)(?: \| From=(?<from>.+?))?' +
        '|NOT SENT: sensor ''(?<held>[^'']*)'': (?<why>.+?))\s*$'
$inv = [Globalization.CultureInfo]::InvariantCulture

$pairs = New-Object System.Collections.Generic.List[object]
$heldBack = New-Object System.Collections.Generic.List[object]
foreach ($m in Select-String -Path $LogPath -Pattern '\[HYDRA Correction\] CH' -Encoding UTF8) {
    $r = [regex]::Match($m.Line, $line)
    if (-not $r.Success) { continue }
    $time = [datetime]::ParseExact($r.Groups['t'].Value, 'yyyyMMdd-HH:mm:ss.fff', $inv)
    if ($From -and $time -lt $From) { continue }
    if ($To -and $time -gt $To) { continue }

    if ($r.Groups['held'].Success) {
        $heldBack.Add([pscustomobject]@{ Time = $time; Channels = $r.Groups['ch'].Value; Sensor = $r.Groups['held'].Value; Reason = $r.Groups['why'].Value })
        continue
    }
    $ch = [int]$r.Groups['ch'].Value
    if ($Channel -and $Channel -notcontains $ch) { continue }
    $pairs.Add([pscustomobject]@{
        Time        = $time
        Channel     = $ch
        Raw         = [double]::Parse($r.Groups['raw'].Value, $inv)
        Compensated = [double]::Parse($r.Groups['corr'].Value, $inv)
        Status      = $r.Groups['st'].Value
        Master      = $r.Groups['m'].Value
        From        = if ($r.Groups['from'].Success) { $r.Groups['from'].Value } else { '(not logged)' }
        Certificate = $null
        Difference  = $null
        BeyondCertificate = $null
        Match       = $null
    })
}

if ($pairs.Count -eq 0) {
    Write-Host "No [HYDRA Correction] pairs in $LogPath for the range given."
} elseif (-not $NoDbCheck) {
    if (-not $ConnectionString) {
        $config = Get-ChildItem $hostDir -Recurse -Filter 'Maba.VCT.CommServer.Hosts.ConsoleHost.exe.config' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $config) { throw 'ConsoleHost exe.config not found - pass -ConnectionString, or -NoDbCheck.' }
        $ConnectionString = (([xml](Get-Content $config.FullName)).configuration.connectionStrings.add |
            Where-Object name -eq 'REMOTE_DATABASE_URL').connectionString
    }

    $conn = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand()
        # The device that holds a certificate, as GetMeasurementDevicesCorrections resolves a MabaID.
        $cmd.CommandText = @'
SELECT TOP (1) f.CorrectedExact, f.OutOfRange
FROM dbo.MeasurementDevices AS md
CROSS APPLY dbo.fnMasterValueAfterCorrection(md.ID, @Reading, NULL) AS f
WHERE md.MabaID = @MabaID
  AND EXISTS (SELECT 1 FROM dbo.MeasurementDevicesCorrections AS c
              WHERE c.MeasurementDevicesId = md.ID AND ISNULL(c.IsDeleted, 0) = 0)
ORDER BY md.ID
'@
        $pMaba = $cmd.Parameters.Add('@MabaID', [Data.SqlDbType]::NVarChar, 50)
        $pRead = $cmd.Parameters.Add('@Reading', [Data.SqlDbType]::Decimal)
        $pRead.Precision = 18; $pRead.Scale = 6

        $cache = @{}
        foreach ($p in $pairs) {
            $key = '{0}|{1}' -f $p.Master, $p.Raw.ToString('R', $inv)
            if (-not $cache.ContainsKey($key)) {
                $pMaba.Value = $p.Master
                $pRead.Value = [decimal]$p.Raw
                $reader = $cmd.ExecuteReader()
                try {
                    $cache[$key] = if ($reader.Read()) { @([double]$reader.GetDecimal(0), ($reader['OutOfRange'] -eq $true)) } else { $null }
                } finally { $reader.Close() }
            }
            $hit = $cache[$key]
            if ($hit) {
                $p.Certificate = [math]::Round($hit[0], 6)
                $p.Difference = [math]::Round($p.Compensated - $hit[0], 6)
                $p.BeyondCertificate = $hit[1]
                $p.Match = [math]::Abs($p.Difference) -le $Tolerance
            }
        }
    } finally { $conn.Close() }
}

if ($CsvPath) { $pairs | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8 }

# The summary goes to the host, so the pipeline carries only the pairs.
if ($pairs.Count -gt 0) {
    $first = ($pairs | Measure-Object Time -Minimum).Minimum
    $last = ($pairs | Measure-Object Time -Maximum).Maximum
    Write-Host ("{0} pairs, {1:yyyy-MM-dd HH:mm:ss} to {2:HH:mm:ss}, channels {3}" -f $pairs.Count, $first, $last,
        (($pairs.Channel | Sort-Object -Unique) -join ','))
    foreach ($g in $pairs | Group-Object Master, From) { Write-Host ("  master {0}: {1} readings" -f $g.Name, $g.Count) }
    $notOk = @($pairs | Where-Object Status -ne 'OK').Count
    if ($notOk) { Write-Host "  status other than OK: $notOk" }
    if (-not $NoDbCheck) {
        $checked = @($pairs | Where-Object { $null -ne $_.Match })
        $bad = @($checked | Where-Object { -not $_.Match })
        Write-Host ("  checked against the certificate: {0}, mismatches beyond {1}: {2}, no certificate found: {3}" -f
            $checked.Count, $Tolerance, $bad.Count, ($pairs.Count - $checked.Count))
        $beyond = @($checked | Where-Object BeyondCertificate).Count
        if ($beyond) { Write-Host "  readings beyond the certificate's range (the VCT's model differs there): $beyond" }
    }
}
foreach ($h in $heldBack) {
    Write-Host ("  held back {0:HH:mm:ss}: CH{1} sensor {2} - {3}" -f $h.Time, $h.Channels, $h.Sensor, $h.Reason)
}

$pairs
