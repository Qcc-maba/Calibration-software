<#
.SYNOPSIS
  פורס את הבנייה הנוכחית לשירות QCCAnalytics, ואופציונלית פותח גישה לקולגה
  ברשת המקומית — לקריאה בלבד ומאחורי סיסמה.

.DESCRIPTION
  שלושת השלבים:
    1. גיבוי ה-dist הקיים והחלפתו בבנייה מהריפו.
    2. הגדרת DASHBOARD_USER/DASHBOARD_PASSWORD כמשתני סביבה ברמת המכונה
       (השירות רץ כ-LocalSystem ולכן חייב Machine scope, לא User).
    3. חוק firewall נכנס לפורט 5000 — מוגבל לכתובת ה-IP של הקולגה בלבד.

  בלי סיסמה מוגדרת, השרת דוחה כל בקשה שאינה מהמכונה עצמה. פתיחת ה-firewall
  לבדה לא חושפת כלום.

.EXAMPLE
  # פריסה בלבד, בלי לשתף
  .\deploy-and-share.ps1

.EXAMPLE
  # פריסה + שיתוף לקולגה ב-10.3.0.57
  .\deploy-and-share.ps1 -ShareWithIp 10.3.0.57 -DashboardUser qcc -DashboardPassword 'בחר-סיסמה-חזקה'

.NOTES
  חייב לרוץ כמנהל (UAC) — עצירת שירות ושינוי firewall דורשים הרשאות.
#>
[CmdletBinding()]
param(
  [string] $RepoDir,
  [string] $ServiceDir = 'C:\Users\eliran_ha\Desktop\Client-Analytics-Dashboard',
  [string] $ServiceName = 'QCCAnalytics',
  [int]    $Port = 5000,
  [string] $ShareWithIp,
  [string] $DashboardUser,
  [string] $DashboardPassword,
  [switch] $RevokeSharing
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot is not always populated in param() defaults — resolve it here instead
if (-not $RepoDir) {
  $here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
  $RepoDir = (Resolve-Path (Join-Path $here '..')).Path
}
$RuleName = "QCC Analytics dashboard (port $Port)"

function Assert-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  if (-not (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "יש להריץ את הסקריפט כמנהל (Run as Administrator)."
  }
}
Assert-Admin

# ── ביטול שיתוף ────────────────────────────────────────────────────────────────
if ($RevokeSharing) {
  Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
  [Environment]::SetEnvironmentVariable('DASHBOARD_USER',     $null, 'Machine')
  [Environment]::SetEnvironmentVariable('DASHBOARD_PASSWORD', $null, 'Machine')
  Restart-Service -Name $ServiceName -Force
  Write-Host "השיתוף בוטל: חוק ה-firewall הוסר והסיסמה נמחקה." -ForegroundColor Green
  return
}

# ── 1. פריסה ───────────────────────────────────────────────────────────────────
$srcDist = Join-Path $RepoDir 'dist'
if (-not (Test-Path (Join-Path $srcDist 'index.cjs'))) {
  throw "לא נמצאה בנייה ב-$srcDist. הרץ 'npm run build' בריפו קודם."
}

Write-Host "עוצר את $ServiceName..." -ForegroundColor Cyan
Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
(Get-Service $ServiceName).WaitForStatus('Stopped', '00:00:30')

$dstDist = Join-Path $ServiceDir 'dist'
if (Test-Path $dstDist) {
  $backup = Join-Path $ServiceDir ("dist_backup_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
  Write-Host "מגבה את הגרסה הקיימת ל-$backup" -ForegroundColor Cyan
  Move-Item $dstDist $backup
}
Write-Host "מעתיק בנייה חדשה..." -ForegroundColor Cyan
Copy-Item $srcDist $dstDist -Recurse

# ── 2. אישורי גישה מרחוק ───────────────────────────────────────────────────────
if ($DashboardPassword) {
  if (-not $DashboardUser) { $DashboardUser = 'qcc' }
  if ($DashboardPassword.Length -lt 12) { throw "בחר סיסמה באורך 12 תווים לפחות." }
  [Environment]::SetEnvironmentVariable('DASHBOARD_USER',     $DashboardUser,     'Machine')
  [Environment]::SetEnvironmentVariable('DASHBOARD_PASSWORD', $DashboardPassword, 'Machine')
  Write-Host "הוגדרו אישורי גישה מרחוק עבור המשתמש '$DashboardUser'." -ForegroundColor Green
}

Write-Host "מפעיל את $ServiceName..." -ForegroundColor Cyan
Start-Service -Name $ServiceName
(Get-Service $ServiceName).WaitForStatus('Running', '00:00:30')

# ── 3. firewall ────────────────────────────────────────────────────────────────
if ($ShareWithIp) {
  if (-not $DashboardPassword -and -not [Environment]::GetEnvironmentVariable('DASHBOARD_PASSWORD','Machine')) {
    throw "סירוב לפתוח את הפורט בלי סיסמה. העבר -DashboardPassword."
  }
  Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
  New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Action Allow `
    -Protocol TCP -LocalPort $Port -RemoteAddress $ShareWithIp -Profile Domain,Private | Out-Null
  Write-Host "נפתחה גישה מ-$ShareWithIp בלבד." -ForegroundColor Green
}

# ── סיכום ──────────────────────────────────────────────────────────────────────
$ip = (Get-NetIPAddress -AddressFamily IPv4 |
       Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
       Select-Object -First 1).IPAddress
Write-Host ""
Write-Host "מצב השירות : $((Get-Service $ServiceName).Status)"
Write-Host "מקומי      : http://localhost:$Port"
if ($ShareWithIp) { Write-Host "לקולגה     : http://${ip}:$Port  (משתמש: $DashboardUser)" }
Write-Host ""
Write-Host "לביטול השיתוף: .\deploy-and-share.ps1 -RevokeSharing" -ForegroundColor Yellow
