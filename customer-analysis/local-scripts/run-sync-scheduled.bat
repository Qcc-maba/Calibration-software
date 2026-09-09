@echo off
setlocal EnableDelayedExpansion

title QCC Analytics - Scheduled Sync

set SCRIPT_DIR=%~dp0
set LOG_DIR=%SCRIPT_DIR%logs
set TIMESTAMP=%DATE:~6,4%-%DATE:~3,2%-%DATE:~0,2%_%TIME:~0,2%-%TIME:~3,2%-%TIME:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set LOG_FILE=%LOG_DIR%\sync_%TIMESTAMP%.log

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

echo ============================================================    >> "%LOG_FILE%"
echo   QCC Analytics - Scheduled Sync                                >> "%LOG_FILE%"
echo   Started: %DATE% %TIME%                                        >> "%LOG_FILE%"
echo ============================================================    >> "%LOG_FILE%"
echo.                                                                >> "%LOG_FILE%"

echo [%TIME%] Starting QCC scheduled sync... >> "%LOG_FILE%"
echo [%TIME%] Starting QCC scheduled sync...

REM Auto-detect Python (py / python / python3)
set PYTHON_CMD=
for %%P in (py python python3) do (
    %%P --version >nul 2>&1 && (
        set PYTHON_CMD=%%P
        goto :found_python
    )
)
:found_python
if "%PYTHON_CMD%"=="" (
    echo [%TIME%] [ERROR] Python not found! Please install Python first. >> "%LOG_FILE%"
    exit /b 1
)

echo [%TIME%] Using Python: %PYTHON_CMD% >> "%LOG_FILE%"

set OVERALL_ERRORS=0

echo. >> "%LOG_FILE%"
echo [1/4] Syncing customers from Priority ERP... >> "%LOG_FILE%"
echo [%TIME%] [1/4] Syncing customers from Priority ERP...
echo ------------------------------------------------------------ >> "%LOG_FILE%"
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [%TIME%] [ERROR] Customer sync failed! >> "%LOG_FILE%"
    echo [%TIME%] [ERROR] Customer sync failed!
    set /A OVERALL_ERRORS+=1
) else (
    echo [%TIME%] [OK] Customer sync completed >> "%LOG_FILE%"
    echo [%TIME%] [OK] Customer sync completed
)

echo. >> "%LOG_FILE%"
echo [2/4] Syncing UPS expenses from Priority ERP... >> "%LOG_FILE%"
echo [%TIME%] [2/4] Syncing UPS expenses from Priority ERP...
echo ------------------------------------------------------------ >> "%LOG_FILE%"
%PYTHON_CMD% "%SCRIPT_DIR%sync-ups-expenses.py" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [%TIME%] [ERROR] UPS expenses sync failed! >> "%LOG_FILE%"
    echo [%TIME%] [ERROR] UPS expenses sync failed!
    set /A OVERALL_ERRORS+=1
) else (
    echo [%TIME%] [OK] UPS expenses sync completed >> "%LOG_FILE%"
    echo [%TIME%] [OK] UPS expenses sync completed
)

echo. >> "%LOG_FILE%"
echo [3/4] Syncing shipments from Ship API (UPS)... >> "%LOG_FILE%"
echo [%TIME%] [3/4] Syncing shipments from Ship API (UPS)...
echo ------------------------------------------------------------ >> "%LOG_FILE%"
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --ship >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [%TIME%] [ERROR] Ship API sync failed! >> "%LOG_FILE%"
    echo [%TIME%] [ERROR] Ship API sync failed!
    set /A OVERALL_ERRORS+=1
) else (
    echo [%TIME%] [OK] Ship API sync completed >> "%LOG_FILE%"
    echo [%TIME%] [OK] Ship API sync completed
)

echo. >> "%LOG_FILE%"
echo [4/5] Syncing calibrators... >> "%LOG_FILE%"
echo [%TIME%] [4/5] Syncing calibrators...
echo ------------------------------------------------------------ >> "%LOG_FILE%"
%PYTHON_CMD% "%SCRIPT_DIR%sync-calibrators.py" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [%TIME%] [ERROR] Calibrators sync failed! >> "%LOG_FILE%"
    echo [%TIME%] [ERROR] Calibrators sync failed!
    set /A OVERALL_ERRORS+=1
) else (
    echo [%TIME%] [OK] Calibrators sync completed >> "%LOG_FILE%"
    echo [%TIME%] [OK] Calibrators sync completed
)

echo. >> "%LOG_FILE%"
echo [5/7] Syncing global return documents + calibration alerts... >> "%LOG_FILE%"
echo [%TIME%] [5/7] Syncing global return documents + calibration alerts...
echo ------------------------------------------------------------ >> "%LOG_FILE%"
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --global-sync >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [%TIME%] [ERROR] Global sync failed! >> "%LOG_FILE%"
    echo [%TIME%] [ERROR] Global sync failed!
    set /A OVERALL_ERRORS+=1
) else (
    echo [%TIME%] [OK] Global sync completed >> "%LOG_FILE%"
    echo [%TIME%] [OK] Global sync completed
)

REM Compute date range: Jan 1 of current year → today
for /f %%D in ('powershell -NoProfile -Command "Get-Date -Format yyyy-01-01"') do set DATE_FROM=%%D
for /f %%D in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set DATE_TO=%%D

echo. >> "%LOG_FILE%"
echo [6/7] Syncing operational query (%DATE_FROM% to %DATE_TO%)... >> "%LOG_FILE%"
echo [%TIME%] [6/7] Syncing operational query (%DATE_FROM% to %DATE_TO%)...
echo ------------------------------------------------------------ >> "%LOG_FILE%"
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --operational-query --date-from %DATE_FROM% --date-to %DATE_TO% --clear >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [%TIME%] [ERROR] Operational query sync failed! >> "%LOG_FILE%"
    echo [%TIME%] [ERROR] Operational query sync failed!
    set /A OVERALL_ERRORS+=1
) else (
    echo [%TIME%] [OK] Operational query sync completed >> "%LOG_FILE%"
    echo [%TIME%] [OK] Operational query sync completed
)

echo. >> "%LOG_FILE%"
echo [7/7] Syncing financial query (%DATE_FROM% to %DATE_TO%)... >> "%LOG_FILE%"
echo [%TIME%] [7/7] Syncing financial query (%DATE_FROM% to %DATE_TO%)...
echo ------------------------------------------------------------ >> "%LOG_FILE%"
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --financial-query --date-from %DATE_FROM% --date-to %DATE_TO% --clear >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [%TIME%] [ERROR] Financial query sync failed! >> "%LOG_FILE%"
    echo [%TIME%] [ERROR] Financial query sync failed!
    set /A OVERALL_ERRORS+=1
) else (
    echo [%TIME%] [OK] Financial query sync completed >> "%LOG_FILE%"
    echo [%TIME%] [OK] Financial query sync completed
)

echo. >> "%LOG_FILE%"
echo ============================================================ >> "%LOG_FILE%"
if %OVERALL_ERRORS% EQU 0 (
    echo   RESULT: SUCCESS - All steps completed                   >> "%LOG_FILE%"
    echo   NOTE: Production migration will run automatically       >> "%LOG_FILE%"
    echo         on the server ~3 minutes after sync ends.         >> "%LOG_FILE%"
    echo [%TIME%] SUCCESS - All steps completed
) else (
    echo   RESULT: COMPLETED WITH %OVERALL_ERRORS% ERROR(S)        >> "%LOG_FILE%"
    echo [%TIME%] COMPLETED WITH %OVERALL_ERRORS% ERROR(S) - check log: %LOG_FILE%
)
echo   Finished: %DATE% %TIME%                                     >> "%LOG_FILE%"
echo ============================================================ >> "%LOG_FILE%"

call :cleanup_old_logs

exit /b %OVERALL_ERRORS%

:cleanup_old_logs
set COUNT=0
for /f "delims=" %%F in ('dir /b /o-d "%LOG_DIR%\sync_*.log" 2^>nul') do (
    set /A COUNT+=1
    if !COUNT! GTR 30 del "%LOG_DIR%\%%F"
)
exit /b 0
