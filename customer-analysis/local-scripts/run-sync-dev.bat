@echo off
chcp 65001 >nul
title QCC Analytics - Dev Sync
set DEV_URL=https://232ca506-7be9-4e7f-a436-7bb478f77860-00-1bf7ltq07a1po.riker.replit.dev
set SCRIPT_DIR=%~dp0

REM איתור מקום פייתון (תומך ב-py/python/python3)
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

echo ============================================================
echo   QCC Analytics - Dev Sync
echo   URL: %DEV_URL%
echo ============================================================
echo.

echo [1/6] Syncing customers to dev...
echo ------------------------------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --url "%DEV_URL%"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Customer sync failed!
) else (
    echo [OK] Customer sync completed
)

echo.
echo [2/6] Syncing department stats to dev...
echo ------------------------------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --departments --url "%DEV_URL%"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Department stats sync failed!
) else (
    echo [OK] Department stats sync completed
)

echo.
echo [3/7] Syncing UPS expenses to dev...
echo ------------------------------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-ups-expenses.py" --url "%DEV_URL%"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] UPS expenses sync failed!
) else (
    echo [OK] UPS expenses sync completed
)

echo.
echo [4/7] Syncing shipments to dev...
echo ------------------------------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --ship --url "%DEV_URL%"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Ship sync failed!
) else (
    echo [OK] Ship sync completed
)

echo.
echo [5/7] Syncing calibrators to dev...
echo ------------------------------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --calibrators --url "%DEV_URL%"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Calibrators sync failed!
) else (
    echo [OK] Calibrators sync completed
)

echo.
echo [6/7] Syncing monthly service call counts to dev...
echo ------------------------------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --monthly-calls --url "%DEV_URL%"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Monthly calls sync failed!
) else (
    echo [OK] Monthly calls sync completed
)

echo.
echo [7/8] Syncing calibrator dept stats to dev...
echo ------------------------------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --calib-dept-stats --url "%DEV_URL%"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Calibrator dept stats sync failed!
) else (
    echo [OK] Calibrator dept stats sync completed
)

echo.
echo [8/8] Syncing global return documents + calibration alerts...
echo ------------------------------------------------------------
%PYTHON_CMD% "%SCRIPT_DIR%sync-customer-data.py" --global-sync --url "%DEV_URL%"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Global sync failed!
) else (
    echo [OK] Global sync completed
)

echo.
echo ============================================================
echo   Dev sync completed!
echo ============================================================
echo.
pause
