<#
.SYNOPSIS
    Builds a self-contained folder (and .zip) of the Instruction Assistant that a colleague can
    run on their own machine — no admin rights, no .NET install, no Windows Service.

.DESCRIPTION
    Publishes win-x64 self-contained, so the recipient does not need the .NET runtime, and adds a
    launcher that starts the service on localhost and opens the browser at it. Nothing is
    installed and nothing is registered: closing the console window stops it.

    The recipient's machine still needs three things the package cannot carry:
      * a domain account that can read  \\maba-dc\Public\הספריה הציבורית\...
      * network reach to the Priority SQL Server (maba-priority\pri)
      * outbound HTTPS to api.anthropic.com

    SECRETS. The service needs an Anthropic key and a read-only Priority connection string.
    By default they are NOT written into the package: the recipient fills config.cmd once, and
    it stays on their machine. -IncludeSecrets bakes your own values in instead, which is
    convenient and means handing another person two working credentials in clear text on disk —
    the Anthropic key is billed to you. Choose deliberately.

.PARAMETER OutputPath
    Where to build the package. Default: <repo>\dist\InstructionAssistant.

.PARAMETER IncludeSecrets
    Write the current secrets into config.cmd instead of leaving a blank template.

.PARAMETER AnthropicApiKey
    Key to bake in with -IncludeSecrets. Defaults to your User-scope ANTHROPIC_API_KEY.

.PARAMETER PriorityConnectionString
    Connection string to bake in with -IncludeSecrets. Defaults to the one in the local
    appsettings.Development.json.

.PARAMETER Port
    Port the packaged app listens on locally. Default 5311.

.PARAMETER NoZip
    Leave the folder without also producing a .zip.

.EXAMPLE
    # Package for a colleague who will enter the secrets themselves
    .\Package-InstructionAssistant.ps1

.EXAMPLE
    # Package ready to run, with your credentials inside
    .\Package-InstructionAssistant.ps1 -IncludeSecrets
#>
param(
    [string] $OutputPath,
    [switch] $IncludeSecrets,
    [string] $AnthropicApiKey,
    [string] $PriorityConnectionString,
    [int]    $Port = 5311,
    [switch] $NoZip
)

$ErrorActionPreference = 'Stop'

$Root    = Split-Path $PSScriptRoot -Parent
$Project = Join-Path $Root 'Systems\InstructionAssistant\Maba.VCT.InstructionAssistant.csproj'
if (-not $OutputPath) { $OutputPath = Join-Path $Root 'dist\InstructionAssistant' }

Write-Host '=== Instruction Assistant - Package Builder ===' -ForegroundColor Cyan

if (-not (Test-Path $Project)) { Write-Error "Project not found at $Project"; exit 1 }

# ── Publish self-contained: the recipient should not have to install anything ──────────────────
if (Test-Path $OutputPath) { Remove-Item $OutputPath -Recurse -Force }
Write-Host "Publishing self-contained win-x64 to $OutputPath ..." -ForegroundColor Yellow

dotnet publish $Project -c Release -r win-x64 --self-contained true `
    -p:PublishSingleFile=false -o $OutputPath --nologo | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "dotnet publish failed (exit $LASTEXITCODE)"; exit 1 }

$exe = Join-Path $OutputPath 'Maba.VCT.InstructionAssistant.exe'
if (-not (Test-Path $exe)) { Write-Error "Published executable not found at $exe"; exit 1 }

# Belt and braces: the csproj already excludes it, but never ship the dev config.
Get-ChildItem $OutputPath -Filter 'appsettings.Development.json' -EA SilentlyContinue | Remove-Item -Force

# ── config.cmd — the only file the recipient edits ────────────────────────────────────────────
if ($IncludeSecrets) {
    if (-not $AnthropicApiKey) {
        $AnthropicApiKey = [Environment]::GetEnvironmentVariable('ANTHROPIC_API_KEY', 'User')
    }
    if (-not $PriorityConnectionString) {
        $devConfig = Join-Path $Root 'Systems\InstructionAssistant\appsettings.Development.json'
        if (Test-Path $devConfig) {
            $PriorityConnectionString =
                (Get-Content $devConfig -Raw | ConvertFrom-Json).InstructionAssistant.Priority.ConnectionString
        }
    }
    if (-not $AnthropicApiKey -or -not $PriorityConnectionString) {
        Write-Host 'ERROR: -IncludeSecrets was requested but a value could not be resolved.' -ForegroundColor Red
        Write-Host '       Pass -AnthropicApiKey and -PriorityConnectionString explicitly.' -ForegroundColor Red
        exit 1
    }
    Write-Host 'WARNING: baking your Anthropic key and Priority credentials into the package.' -ForegroundColor Yellow
    Write-Host '         Anyone holding the folder holds those credentials, and the Claude usage' -ForegroundColor Yellow
    Write-Host '         is billed to you. Hand it over the same way you would a password.' -ForegroundColor Yellow
} else {
    $AnthropicApiKey = ''
    $PriorityConnectionString = ''
    Write-Host 'Secrets left blank - the recipient fills config.cmd once.' -ForegroundColor Gray
}

$configCmd = @"
@rem ===================================================================
@rem  Instruction Assistant - local settings. Edit the two values below.
@rem  This file stays on this machine; do not e-mail it on.
@rem ===================================================================

@rem  Claude API key (starts with sk-ant-)
set ANTHROPIC_API_KEY=$AnthropicApiKey

@rem  Read-only connection to the Priority company database
set InstructionAssistant__Priority__ConnectionString=$PriorityConnectionString
"@
Set-Content -Path (Join-Path $OutputPath 'config.cmd') -Value $configCmd -Encoding OEM

# ── launcher ──────────────────────────────────────────────────────────────────────────────────
$startCmd = @"
@echo off
setlocal
cd /d "%~dp0"

if not exist config.cmd (
  echo config.cmd is missing - cannot start.
  pause
  exit /b 1
)
call config.cmd

if "%ANTHROPIC_API_KEY%"=="" (
  echo.
  echo   Open config.cmd in Notepad and fill in the two values, then run this again.
  echo.
  pause
  exit /b 1
)

rem Bind to localhost only: this runs for the person sitting at this machine.
set ASPNETCORE_URLS=http://localhost:$Port
set ASPNETCORE_ENVIRONMENT=Production

echo Starting the Instruction Assistant on http://localhost:$Port ...
start "" http://localhost:$Port/
Maba.VCT.InstructionAssistant.exe
"@
Set-Content -Path (Join-Path $OutputPath 'Start.cmd') -Value $startCmd -Encoding OEM

# ── README for the recipient (Hebrew, UTF-8 with BOM so Notepad renders it) ────────────────────
$readme = @"
עוזר הוראות לקוח — הפעלה מקומית
================================

הרצה:
  1. אם config.cmd ריק — פתחו אותו ב-Notepad והדביקו את שני הערכים שקיבלתם.
  2. הפעילו את Start.cmd (לחיצה כפולה). ייפתח חלון שחור — אל תסגרו אותו.
  3. הדפדפן ייפתח בכתובת http://localhost:$Port
  4. לסיום — סגרו את החלון השחור.

שימוש:
  הזינו מספר מבא (למשל 2601047/7) ולחצו "הצג הוראות".
  לא יודעים את המספר? חפשו לפי דגם/יצרן/מס' סידורי/שם לקוח ובחרו מהרשימה.
  החיפוש הראשון למכשיר אורך כ-45 שניות (הסיכום נבנה מול Claude). אחריו זה מיידי.

דרישות מהמחשב:
  * להיות ברשת הארגונית (או VPN) — לגישה לשרת Priority ולתיקיית \\maba-dc
  * חיבור אינטרנט יוצא ל-api.anthropic.com
  * לא נדרשת התקנה ולא הרשאות מנהל

בעיות נפוצות:
  "חיבור נכשל" בדפדפן        — החלון השחור נסגר. הפעילו שוב את Start.cmd.
  אין סיכום, רק רשימת מקורות — מפתח Claude חסר או שגוי ב-config.cmd.
  לא נמצא מספר מבא            — אין גישה ל-Priority (רשת/VPN או מחרוזת חיבור שגויה).
  הטבלה ריקה                  — אין גישה לתיקייה \\maba-dc.
"@
$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText((Join-Path $OutputPath 'README.txt'), $readme, $utf8Bom)

# ── zip ───────────────────────────────────────────────────────────────────────────────────────
$sizeMb = [math]::Round((Get-ChildItem $OutputPath -Recurse -File | Measure-Object Length -Sum).Sum / 1MB, 1)
Write-Host "Package built: $OutputPath  ($sizeMb MB, $((Get-ChildItem $OutputPath -Recurse -File).Count) files)" -ForegroundColor Green

if (-not $NoZip) {
    $zip = "$OutputPath.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $OutputPath '*') -DestinationPath $zip
    $zipMb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
    Write-Host "Zip: $zip  ($zipMb MB)" -ForegroundColor Green
}

Write-Host ''
Write-Host 'Give the recipient the folder (or zip) and tell them to run Start.cmd.' -ForegroundColor Cyan
if (-not $IncludeSecrets) {
    Write-Host 'Send the two secrets separately - they go into config.cmd.' -ForegroundColor Cyan
}
