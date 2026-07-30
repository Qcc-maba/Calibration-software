@echo off
title QCC Analytics Full Sync

set SCRIPT_DIR=%~dp0

set PYTHON_CMD=
for %%P in (py python python3) do (
    %%P --version >nul 2>&1 && (
        set PYTHON_CMD=%%P
        goto found_python
    )
)
:found_python
if "%PYTHON_CMD%"=="" (
    echo ERROR: Python not found
    pause
    exit /b 1
)

echo [INFO] Using Python: %PYTHON_CMD%
echo =========================================
echo QCC Analytics - Full Sync
echo =========================================
echo.

echo [1/5] Syncing customers...
echo ----------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py"
if %ERRORLEVEL% NEQ 0 echo ERROR: Customer sync failed
echo.

echo [2/5] Syncing UPS expenses...
echo ----------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-ups-expenses.py"
if %ERRORLEVEL% NEQ 0 echo ERROR: UPS sync failed
echo.

echo [3/5] Syncing shipments...
echo ----------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --ship
if %ERRORLEVEL% NEQ 0 echo ERROR: Ship sync failed
echo.

echo [4/5] Syncing calibrators...
echo ----------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --calibrators
if %ERRORLEVEL% NEQ 0 echo ERROR: Calibrator sync failed
echo.

echo [5/5] Syncing monthly calls...
echo ----------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --monthly-calls
if %ERRORLEVEL% NEQ 0 echo ERROR: Monthly calls failed
echo.

echo =========================================
echo Full sync completed!
echo =========================================
pause
