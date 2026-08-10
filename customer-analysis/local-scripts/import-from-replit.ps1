<#
.SYNOPSIS
  מייבא את בסיס הנתונים של QCC Analytics מ-Replit (Neon Postgres) ל-Postgres מקומי.

.DESCRIPTION
  pg_dump מה-DB של Replit -> קובץ custom-format מקומי -> pg_restore ל-DB היעד.
  לפני הדריסה נשמר גיבוי של DB היעד (אלא אם הועבר -NoBackup).

  את ה-SourceUrl לוקחים מ-Replit: פאנל Database -> "Connection string" / Secrets -> DATABASE_URL
  (נראה כמו postgresql://USER:PASS@ep-xxxx.eu-central-1.aws.neon.tech/neondb?sslmode=require)

.EXAMPLE
  # ייבוא ל-qcc_analytics (ברירת המחדל) — ה-DB שהשירות QCCAnalytics מגיש.
  # יש לעצור את השירות קודם, אחרת ה-DROP במסגרת ה-restore ייתקע על נעילות:
  #   sc.exe stop QCCAnalytics   (דורש הרשאות מנהל)
  .\import-from-replit.ps1 -SourceUrl "postgresql://...neon.tech/neondb?sslmode=require"

.EXAMPLE
  # ייבוא ל-DB אחר לבדיקה, בלי לגעת בזה שבפרודקשן
  .\import-from-replit.ps1 -SourceUrl "postgresql://..." -TargetDb qcc_from_replit

.EXAMPLE
  # רק גיבוי מ-Replit לקובץ, בלי לגעת ב-DB מקומי
  .\import-from-replit.ps1 -SourceUrl "postgresql://..." -DumpOnly
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceUrl,

    [string]$TargetDb = 'qcc_analytics',
    [string]$TargetHost = 'localhost',
    [int]$TargetPort = 5432,
    [string]$TargetUser = 'postgres',
    [string]$TargetPassword = 'postgres',

    [string]$DumpDir,
    [switch]$DumpOnly,
    [switch]$NoBackup,
    [switch]$Force
)

# 'Continue' ולא 'Stop': ב-PowerShell 5.1 כל שורת stderr של exe נטיבי (וכלי pg כותבים
# התקדמות ל-stderr) הופכת ל-ErrorRecord ומפילה את הסקריפט באמצע. הטיפול בשגיאות כאן
# נעשה במפורש דרך throw + בדיקת $LASTEXITCODE אחרי כל קריאה נטיבית.
$ErrorActionPreference = 'Continue'

function Find-PgBin {
    $candidates = Get-ChildItem 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue |
        Sort-Object { [int]($_.Name -replace '\D', '0') } -Descending
    foreach ($c in $candidates) {
        $bin = Join-Path $c.FullName 'bin'
        if (Test-Path (Join-Path $bin 'pg_dump.exe')) { return $bin }
    }
    throw 'pg_dump.exe not found under C:\Program Files\PostgreSQL\*\bin'
}

$bin       = Find-PgBin
$pgDump    = Join-Path $bin 'pg_dump.exe'
$pgRestore = Join-Path $bin 'pg_restore.exe'
$psql      = Join-Path $bin 'psql.exe'

$clientVer = ((& $pgDump --version) -replace '[^\d.]', '').Split('.')[0]
Write-Host "pg client: $bin (major $clientVer)" -ForegroundColor Cyan

# ── 1. pre-flight: לוודא שאפשר להתחבר ל-Replit ושהגרסה תואמת ─────────────────
Write-Host "`n[1/5] בודק חיבור ל-Replit..." -ForegroundColor Yellow
# הערה: ל-psql של Windows אין getopt שמפרמט — כל האופציות חייבות לבוא לפני ה-URL.
$srcVer = (& $psql -At -c 'show server_version' $SourceUrl) 2>&1
if ($LASTEXITCODE -ne 0) { throw "לא ניתן להתחבר ל-DB המקורי:`n$srcVer" }
$srcMajor = ($srcVer -replace '[^\d.]', '').Split('.')[0]
Write-Host "  server_version = $srcVer (major $srcMajor)"
if ([int]$srcMajor -gt [int]$clientVer) {
    throw "ה-DB ב-Replit הוא Postgres $srcMajor אבל pg_dump המקומי הוא $clientVer. " +
          "pg_dump מסרב לגבות שרת חדש ממנו — יש להתקין client tools של Postgres $srcMajor."
}

$sqlTables = @'
select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'r' and n.nspname = 'public' order by 1
'@
$srcTables = @(& $psql -At -c $sqlTables $SourceUrl | Where-Object { $_ })
if ($LASTEXITCODE -ne 0) { throw 'לא ניתן לקרוא את רשימת הטבלאות מ-Replit' }
Write-Host ("  נמצאו {0} טבלאות ב-public: {1}" -f $srcTables.Count, ($srcTables -join ', '))

# ── 2. dump ──────────────────────────────────────────────────────────────────
if (-not $DumpDir) { $DumpDir = Join-Path $PSScriptRoot 'dumps' }
New-Item -ItemType Directory -Force -Path $DumpDir | Out-Null
$stamp    = Get-Date -Format 'yyyyMMdd_HHmmss'
$dumpFile = Join-Path $DumpDir "replit_$stamp.dump"

Write-Host "`n[2/5] pg_dump מ-Replit -> $dumpFile" -ForegroundColor Yellow
& $pgDump --format=custom --no-owner --no-privileges --file=$dumpFile $SourceUrl
if ($LASTEXITCODE -ne 0) { throw "pg_dump נכשל (exit $LASTEXITCODE)" }
$sizeMb = [math]::Round((Get-Item $dumpFile).Length / 1MB, 2)
Write-Host "  ✓ dump הושלם: $sizeMb MB" -ForegroundColor Green

if ($DumpOnly) {
    Write-Host "`n-DumpOnly: לא נגעתי ב-DB המקומי. הקובץ: $dumpFile" -ForegroundColor Cyan
    return
}

# ── 3. גיבוי היעד ────────────────────────────────────────────────────────────
$env:PGPASSWORD = $TargetPassword
$targetArgs = @('-h', $TargetHost, '-p', $TargetPort, '-U', $TargetUser)

$exists = & $psql @targetArgs -d postgres -At -c "select 1 from pg_database where datname='$TargetDb'"
if (-not $exists) {
    Write-Host "`n[3/5] DB '$TargetDb' לא קיים — יוצר." -ForegroundColor Yellow
    & $psql @targetArgs -d postgres -c "create database ""$TargetDb"" encoding 'UTF8'" | Out-Null
}
elseif ($NoBackup) {
    Write-Host "`n[3/5] -NoBackup: מדלג על גיבוי '$TargetDb'." -ForegroundColor DarkYellow
}
else {
    $backupFile = Join-Path $DumpDir "${TargetDb}_before_$stamp.dump"
    Write-Host "`n[3/5] מגבה את '$TargetDb' -> $backupFile" -ForegroundColor Yellow
    & $pgDump @targetArgs -d $TargetDb --format=custom --no-owner --no-privileges --file=$backupFile
    if ($LASTEXITCODE -ne 0) { throw "גיבוי היעד נכשל — עוצר לפני דריסה." }
    Write-Host "  ✓ גיבוי הושלם" -ForegroundColor Green
}

if (-not $Force) {
    $ans = Read-Host "`nלדרוס את התוכן של '$TargetDb' בנתונים מ-Replit? (yes/no)"
    if ($ans -ne 'yes') { Write-Host 'בוטל.' -ForegroundColor Red; return }
}

# ── 4. restore ───────────────────────────────────────────────────────────────
Write-Host "`n[4/5] pg_restore -> $TargetDb" -ForegroundColor Yellow
& $pgRestore @targetArgs -d $TargetDb --clean --if-exists --no-owner --no-privileges `
    --single-transaction $dumpFile
if ($LASTEXITCODE -ne 0) { throw "pg_restore נכשל (exit $LASTEXITCODE) — היעד לא שונה (single-transaction)." }
Write-Host '  ✓ restore הושלם' -ForegroundColor Green

# ── 4b. החזרת בעלות לבעל ה-DB ────────────────────────────────────────────────
# חובה: --no-owner + התחברות כ-postgres יוצרים את הטבלאות בבעלות postgres, והאפליקציה
# שמתחברת כ-qcc מקבלת "permission denied for table" (42501) על כל שאילתה.
$fixSql = Join-Path $PSScriptRoot 'fix-db-owner.sql'
if (Test-Path $fixSql) {
    Write-Host '  מחזיר בעלות על אובייקטי public לבעל ה-DB...' -ForegroundColor Yellow
    & $psql @targetArgs -d $TargetDb -f $fixSql | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'תיקון הבעלות נכשל — האפליקציה תקבל 42501.' }
    $wrongOwner = & $psql @targetArgs -d $TargetDb -At -c @"
select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname='public' and c.relkind in ('r','p','v','m','S')
  and pg_get_userbyid(c.relowner) <> (select pg_get_userbyid(datdba) from pg_database where datname=current_database())
"@
    if ([int]$wrongOwner -ne 0) { throw "נשארו $wrongOwner אובייקטים בבעלות שגויה." }
    Write-Host '  ✓ בעלות תקינה' -ForegroundColor Green
}
else {
    Write-Host "  ⚠ $fixSql חסר — ייתכן ש-qcc יקבל 42501. הרץ אותו ידנית." -ForegroundColor Red
}

# ── 5. אימות: השוואת מספרי שורות מקור מול יעד ────────────────────────────────
Write-Host "`n[5/5] אימות מספרי שורות" -ForegroundColor Yellow
$rows = foreach ($t in $srcTables) {
    $src = & $psql -At -c "select count(*) from public.""$t""" $SourceUrl
    $dst = & $psql @targetArgs -d $TargetDb -At -c "select count(*) from public.""$t"""
    [pscustomobject]@{ Table = $t; Replit = [int]$src; Local = [int]$dst; OK = ([int]$src -eq [int]$dst) }
}
$rows | Format-Table -AutoSize
$bad = $rows | Where-Object { -not $_.OK }
if ($bad) {
    Write-Host "⚠ פערים ב-$($bad.Count) טבלאות — ראה למעלה." -ForegroundColor Red
    Write-Host @'
  הסיבה הנפוצה: ה-dump נתפס בזמן שהסנכרון ב-Replit רץ. הסנכרון עובד בתבנית
  "insert דור חדש עם sync_id חדש -> מחק את הדור הישן", ולכן snapshot באמצע התהליך
  מכיל את הדור הישן במלואו + חלק מהחדש (ואז local > Replit).
  אבחון:  select sync_id, count(*) from <table> group by 1;
  פתרון:  להריץ את הסקריפט שוב אחרי שהסנכרון ב-Replit הסתיים.
'@ -ForegroundColor DarkYellow
    exit 1
}
Write-Host "`n✅ הייבוא הושלם, כל הטבלאות תואמות. dump נשמר ב: $dumpFile" -ForegroundColor Green
