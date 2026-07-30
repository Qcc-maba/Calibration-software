@echo off
title QCC Analytics - Full Sync

echo ============================================================
echo   QCC Analytics - Full Sync
echo ============================================================
echo.

set SCRIPT_DIR=%~dp0

REM איתור מקום פייתון (תומך ב-gpy/py/python)
set PYTHON_CMD=
for %%P in (py python python3) do (
    %%P --version >nul 2>&1 && (
        set PYTHON_CMD=%%P
        goto :found_python
    )
)
:found_python
if "%PYTHON_CMD%"=="" (
    echo [ERROR] לא נמצא פייתון! ודא שהותקן במחשב.
    pause
    exit /b 1
)
echo [INFO] Using Python: %PYTHON_CMD%

echo [1/5] Syncing customers from Priority ERP...
echo ------------------------------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Customer sync failed!
) else (
    echo [OK] Customer sync completed
)

echo.
echo [2/5] Syncing UPS expenses from Priority ERP...
echo ------------------------------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-ups-expenses.py"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] UPS expenses sync failed!
) else (
    echo [OK] UPS expenses sync completed
)

echo.
echo [3/5] Syncing shipments from Ship API...
echo ------------------------------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --ship
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Ship API sync failed!
) else (
    echo [OK] Ship API sync completed
)

echo.
echo [4/5] Syncing calibrators...
echo ------------------------------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --calibrators
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Calibrators sync failed!
) else (
    echo [OK] Calibrators sync completed
)

echo.
echo [5/6] Syncing global return documents + calibration alerts...
echo ------------------------------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --global-sync
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Global sync failed!
) else (
    echo [OK] Global sync completed
)

echo.
echo [6/6] Syncing monthly service call counts...
echo ------------------------------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --monthly-calls
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Monthly calls sync failed!
) else (
    echo [OK] Monthly calls sync completed
)

echo.
echo ============================================================
echo   Full sync completed!
echo ============================================================
echo.
pause
