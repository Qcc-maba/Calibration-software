@echo off
setlocal EnableDelayedExpansion
:: Calibration Software - Silent Launcher
:: All output goes to log files. No console windows are shown.
::
:: Restart-safe: stop Windows Service when possible; only taskkill ConsoleHost.exe
:: when the service is NOT running (same exe is used as service binary — killing
:: orphans while the service runs would terminate the service).

set APPDIR=%~dp0\..
set LOGDIR=%APPDIR%\logs
set CONSOLEHOST=%APPDIR%\consolehost
set WEBAPP=%APPDIR%\webapp
set LOCKFILE=%LOGDIR%\launcher.run.lock
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
set LOGFILE=%LOGDIR%\launcher.log

if exist "%LOCKFILE%" (
    echo ========================================== >> "%LOGFILE%"
    echo   LAUNCHER SKIPPED %date% %time% >> "%LOGFILE%"
    echo   Another start-all.bat is running, or delete >> "%LOGFILE%"
    echo   %LOCKFILE% >> "%LOGFILE%"
    echo   if a previous run ended abnormally. >> "%LOGFILE%"
    echo ========================================== >> "%LOGFILE%"
    endlocal
    exit /b 0
)
echo %date% %time%> "%LOCKFILE%"

echo ========================================== >> "%LOGFILE%"
echo   LAUNCHER STARTED %date% %time% >> "%LOGFILE%"
echo ========================================== >> "%LOGFILE%"

:: ---- Step 0: Stop backend; taskkill only when service is not running ----
echo [0/3] Stopping previous run (service first, then orphans if safe)... >> "%LOGFILE%"

set "SVC_RUNNING=0"
sc query MabaCalibrationServer 2>nul | find "RUNNING" >nul 2>&1
if !ERRORLEVEL! EQU 0 set "SVC_RUNNING=1"

if "!SVC_RUNNING!"=="1" (
    echo   Stopping MabaCalibrationServer... >> "%LOGFILE%"
    net stop MabaCalibrationServer >> "%LOGFILE%" 2>&1
    ping -n 5 127.0.0.1 >nul
    set "SVC_RUNNING=0"
    sc query MabaCalibrationServer 2>nul | find "RUNNING" >nul 2>&1
    if !ERRORLEVEL! EQU 0 set "SVC_RUNNING=1"
)

if "!SVC_RUNNING!"=="1" (
    echo   WARNING: Service still RUNNING — skipped taskkill ^(same exe as service; need Admin to net stop^). >> "%LOGFILE%"
) else (
    taskkill /IM "Maba.VCT.CommServer.Hosts.ConsoleHost.exe" /F >nul 2>&1
    if !ERRORLEVEL! EQU 0 (
        echo   Killed stray ConsoleHost process ^(service was not running^) >> "%LOGFILE%"
    ) else (
        echo   No stray ConsoleHost >> "%LOGFILE%"
    )
)
ping -n 3 127.0.0.1 >nul

powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object { if ($_) { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue } }" >> "%LOGFILE%" 2>&1
ping -n 4 127.0.0.1 >nul

:: Refresh service running flag before starting backend
set "SVC_RUNNING=0"
sc query MabaCalibrationServer 2>nul | find "RUNNING" >nul 2>&1
if !ERRORLEVEL! EQU 0 set "SVC_RUNNING=1"

:: ---- Diagnostics ----
if exist "%CONSOLEHOST%\Maba.VCT.CommServer.Hosts.ConsoleHost.exe" (
    echo   ConsoleHost.exe - FOUND >> "%LOGFILE%"
) else (
    echo   ConsoleHost.exe - MISSING >> "%LOGFILE%"
)
if exist "%WEBAPP%\server.js" (
    echo   webapp/server.js - FOUND >> "%LOGFILE%"
) else (
    echo   webapp/server.js - MISSING >> "%LOGFILE%"
)

:: ---- Step 1: Start backend ----
echo [1/3] Starting service... >> "%LOGFILE%"

if "!SVC_RUNNING!"=="1" (
    echo   Backend already active ^(Windows Service RUNNING^) >> "%LOGFILE%"
    goto :after_backend
)

net start MabaCalibrationServer >> "%LOGFILE%" 2>&1
set NETSTART_RC=!ERRORLEVEL!

if !NETSTART_RC! EQU 0 (
    echo   Service started OK >> "%LOGFILE%"
    goto :after_backend
)

echo   net start failed ^(code !NETSTART_RC!^) — checking service state... >> "%LOGFILE%"
sc query MabaCalibrationServer 2>nul | find "RUNNING" >nul 2>&1
if !ERRORLEVEL! EQU 0 (
    echo   Service already RUNNING >> "%LOGFILE%"
    goto :after_backend
)

echo   Service not running - starting ConsoleHost in background >> "%LOGFILE%"
if exist "%CONSOLEHOST%\Maba.VCT.CommServer.Hosts.ConsoleHost.exe" (
    powershell -WindowStyle Hidden -Command "Start-Process -FilePath '%CONSOLEHOST%\Maba.VCT.CommServer.Hosts.ConsoleHost.exe' -WorkingDirectory '%CONSOLEHOST%' -WindowStyle Hidden"
    echo   ConsoleHost started (hidden) >> "%LOGFILE%"
) else (
    echo   ERROR: ConsoleHost.exe not found! >> "%LOGFILE%"
)

:after_backend
ping -n 6 127.0.0.1 >nul

:: ---- Step 2: Start webapp (hidden) ----
echo [2/3] Starting Web App... >> "%LOGFILE%"
if exist "%WEBAPP%\server.js" (
    powershell -WindowStyle Hidden -Command "Start-Process -FilePath 'node' -ArgumentList 'server.js' -WorkingDirectory '%WEBAPP%' -WindowStyle Hidden -RedirectStandardOutput '%LOGDIR%\webapp.log' -RedirectStandardError '%LOGDIR%\webapp-error.log'"
    echo   Web App started (hidden) >> "%LOGFILE%"
) else (
    echo   ERROR: server.js not found! >> "%LOGFILE%"
)

ping -n 7 127.0.0.1 >nul

:: ---- Step 3: Open browser ----
echo [3/3] Opening browser... >> "%LOGFILE%"
start http://localhost:3000

echo ========================================== >> "%LOGFILE%"
echo   LAUNCHER COMPLETE %date% %time% >> "%LOGFILE%"
echo ========================================== >> "%LOGFILE%"

if exist "%LOCKFILE%" del "%LOCKFILE%" 2>nul
endlocal
exit /b 0
