@echo off
title QCC Analytics Production Sync

set PROD_URL=https://client-analytics-dashboard--eliran8hadad.replit.app
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

echo =========================================
echo QCC Analytics - Production Sync
echo URL: %PROD_URL%
echo =========================================
echo.

echo [1/7] Syncing customers...
echo ----------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --url "%PROD_URL%"
if %ERRORLEVEL% NEQ 0 echo ERROR: Customer sync failed
echo.

echo [2/7] Syncing departments...
echo ----------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --departments --url "%PROD_URL%"
if %ERRORLEVEL% NEQ 0 echo ERROR: Department sync failed
echo.

echo [3/7] Syncing UPS expenses...
echo ----------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-ups-expenses.py" --url "%PROD_URL%"
if %ERRORLEVEL% NEQ 0 echo ERROR: UPS sync failed
echo.

echo [4/7] Syncing shipments...
echo ----------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --ship --url "%PROD_URL%"
if %ERRORLEVEL% NEQ 0 echo ERROR: Ship sync failed
echo.

echo [5/7] Syncing calibrators...
echo ----------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --calibrators --url "%PROD_URL%"
if %ERRORLEVEL% NEQ 0 echo ERROR: Calibrator sync failed
echo.

echo [6/7] Syncing monthly calls...
echo ----------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --monthly-calls --url "%PROD_URL%"
if %ERRORLEVEL% NEQ 0 echo ERROR: Monthly calls failed
echo.

echo [7/7] Syncing calibrator dept stats...
echo ----------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --calib-dept-stats --url "%PROD_URL%"
if %ERRORLEVEL% NEQ 0 echo ERROR: Calib dept stats failed
echo.

echo =========================================
echo Production sync completed!
echo =========================================
pause
