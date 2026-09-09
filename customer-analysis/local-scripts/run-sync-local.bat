@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul

REM ==========================================================================
REM  QCC Analytics - sync into the LOCAL service (the QCCAnalytics Windows
REM  service on http://localhost:5000, served from
REM  C:\Users\eliran_ha\Desktop\Client-Analytics-Dashboard).
REM
REM  This exists because run-sync-scheduled.bat passes no --url, so it falls
REM  back to the placeholder Replit address and syncs nowhere. It also lacked
REM  PYTHONIOENCODING, so the script died on the Unicode arrows it prints.
REM
REM  Credentials are read from ..\.env (AMABA_SQL_*) rather than duplicated
REM  here, so there is only ever one copy of the password on disk.
REM
REM  Usage:  run-sync-local.bat              global sync (return docs + alerts)
REM          run-sync-local.bat full         the above plus operational+financial
REM ==========================================================================

set "SCRIPT_DIR=%~dp0"
set "ENV_FILE=%SCRIPT_DIR%..\.env"
set "TARGET_URL=http://localhost:5000"
set "LOG_DIR=%SCRIPT_DIR%logs"
set "MODE=%~1"

REM the script prints -> and (!) ; cp1255 cannot encode them and it crashes
set "PYTHONIOENCODING=utf-8"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
for /f "usebackq tokens=1-6 delims=/: " %%a in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy MM dd HH mm ss'"`) do (
    set "STAMP=%%a-%%b-%%c_%%d%%e%%f"
)
set "LOG=%LOG_DIR%\local-sync_%STAMP%.log"

call :log "============================================================"
call :log "  QCC Analytics - local sync"
call :log "  target : %TARGET_URL%"
call :log "  started: %DATE% %TIME%"
call :log "============================================================"

REM ---- python ------------------------------------------------------------
set "PYTHON_CMD="
for %%P in (py python python3) do (
    %%P --version >nul 2>&1 && (
        set "PYTHON_CMD=%%P"
        goto :got_python
    )
)
:got_python
if "%PYTHON_CMD%"=="" (
    call :log "[ERROR] Python not found on PATH."
    exit /b 1
)
call :log "[INFO] python: %PYTHON_CMD%"

REM ---- the service must be up, or every POST silently fails ---------------
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri '%TARGET_URL%/api/agents' -UseBasicParsing -TimeoutSec 15; exit 0 } catch { exit 1 }" >nul 2>&1
if !ERRORLEVEL! NEQ 0 (
    call :log "[ERROR] %TARGET_URL% is not answering. Is the QCCAnalytics service running?"
    exit /b 1
)
call :log "[INFO] service is up"

REM ---- credentials from ..\.env ------------------------------------------
if not exist "%ENV_FILE%" (
    call :log "[ERROR] env file not found: %ENV_FILE%"
    exit /b 1
)
set "SQL_SERVER="
set "SQL_UID="
set "SQL_PWD="
set "SQL_DATABASE=amaba"
for /f "usebackq tokens=1,* delims==" %%A in (`findstr /b /c:"AMABA_SQL_SERVER=" /c:"AMABA_SQL_USER=" /c:"AMABA_SQL_PASSWORD=" "%ENV_FILE%"`) do (
    if "%%A"=="AMABA_SQL_SERVER"   set "SQL_SERVER=%%~B"
    if "%%A"=="AMABA_SQL_USER"     set "SQL_UID=%%~B"
    if "%%A"=="AMABA_SQL_PASSWORD" set "SQL_PWD=%%~B"
)
if "!SQL_UID!"==""  ( call :log "[ERROR] AMABA_SQL_USER missing from %ENV_FILE%"     & exit /b 1 )
if "!SQL_PWD!"==""  ( call :log "[ERROR] AMABA_SQL_PASSWORD missing from %ENV_FILE%" & exit /b 1 )
if "!SQL_SERVER!"=="" set "SQL_SERVER=maba-priority\pri"
call :log "[INFO] priority: !SQL_SERVER!/%SQL_DATABASE% as !SQL_UID!"

set "RC=0"

REM ---- 1: return documents + calibration alerts ---------------------------
REM  The endpoint behind --global-sync replaces the tables wholesale
REM  (delete then insert), so re-running cannot stack duplicates.
call :log ""
call :log "[1] global sync (return documents + calibration alerts)..."
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --global-sync --url "%TARGET_URL%" >> "%LOG%" 2>&1
if !ERRORLEVEL! NEQ 0 ( call :log "[FAIL] global sync" & set "RC=1" ) else ( call :log "[OK]   global sync" )

if /i not "%MODE%"=="full" goto :done

REM ---- 2: operational + financial, current year --------------------------
REM  --clear is REQUIRED: these endpoints append, so without it every run
REM  stacks another generation and silently inflates every total.
for /f "usebackq" %%Y in (`powershell -NoProfile -Command "(Get-Date).Year"`) do set "YR=%%Y"
set "DATE_FROM=%YR%-01-01"
for /f "usebackq" %%D in (`powershell -NoProfile -Command "(Get-Date).ToString('yyyy-MM-dd')"`) do set "DATE_TO=%%D"

call :log ""
call :log "[2] operational query %DATE_FROM% .. %DATE_TO% (--clear)..."
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --operational-query --date-from %DATE_FROM% --date-to %DATE_TO% --clear --url "%TARGET_URL%" >> "%LOG%" 2>&1
if !ERRORLEVEL! NEQ 0 ( call :log "[FAIL] operational query" & set "RC=1" ) else ( call :log "[OK]   operational query" )

call :log ""
call :log "[3] financial query %DATE_FROM% .. %DATE_TO% (--clear)..."
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --financial-query --date-from %DATE_FROM% --date-to %DATE_TO% --clear --url "%TARGET_URL%" >> "%LOG%" 2>&1
if !ERRORLEVEL! NEQ 0 ( call :log "[FAIL] financial query" & set "RC=1" ) else ( call :log "[OK]   financial query" )

:done
call :log ""
if "%RC%"=="0" ( call :log "[DONE] finished OK  %DATE% %TIME%" ) else ( call :log "[DONE] finished WITH ERRORS  %DATE% %TIME%" )
call :log "log: %LOG%"
endlocal & exit /b %RC%

:log
if "%~1"=="" (
    echo.
    echo.>> "%LOG%"
) else (
    echo %~1
    echo %~1>> "%LOG%"
)
goto :eof
