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
    echo   ConsoleHost started ^(hidden^) >> "%LOGFILE%"
) else (
    echo   ERROR: ConsoleHost.exe not found! >> "%LOGFILE%"
)

:after_backend
ping -n 6 127.0.0.1 >nul

:: ---- Step 2: Start webapp (hidden) ----
:: Through start-webapp.ps1, never `node server.js` directly. The shipped .env carries only
:: REMOTE_DATABASE_URL_PROD / _STAGE; src\env.js requires the plain REMOTE_DATABASE_URL and that
:: script is what derives it. Starting node here meant the server came up, answered every request
:: with "Invalid environment variables" and returned 500 - the site looked dead while the service
:: and the WebSocket were both fine. It also skips the log upload the script performs on launch.
echo [2/3] Starting Web App... >> "%LOGFILE%"
if exist "%WEBAPP%\server.js" (
    powershell -WindowStyle Hidden -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%APPDIR%\assets\start-webapp.ps1' -WindowStyle Hidden"
    echo   Web App started via start-webapp.ps1 ^(hidden^) >> "%LOGFILE%"
) else (
    echo   ERROR: server.js not found! >> "%LOGFILE%"
)

:: ---- Step 3: Open the browser, but only once something answers ----
:: This used to be a flat 6-second wait and then `start http://localhost:3000`. The web app needs a
:: great deal longer than that from a cold start under Program Files - start-webapp.ps1 allows it 90
:: seconds - so the browser regularly arrived at a dead port and showed the operator "this site
:: cannot be reached". The station was working; it just was not working YET, and by the time it came
:: up the operator had already been told the software was broken.
::
:: A TcpClient connect is the same thing the browser is about to do, and unlike Get-NetTCPConnection
:: it exists on every Windows build we ship to.
echo [3/3] Waiting for the web app to answer on port 3000... >> "%LOGFILE%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ok=$false; for($i=0;$i -lt 60;$i++){ try { $c=New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1',3000); $c.Close(); $ok=$true; break } catch { Start-Sleep -Seconds 2 } }; if($ok){ exit 0 } else { exit 1 }"
if !ERRORLEVEL! EQU 0 (
    echo   Web app is answering - opening the browser. >> "%LOGFILE%"
) else (
    echo   WARNING: nothing answered on port 3000 after 120s. Opening the browser anyway; >> "%LOGFILE%"
    echo   see logs\webapp-launcher.log and logs\webapp-error.log for what node did. >> "%LOGFILE%"
)
start http://localhost:3000

echo ========================================== >> "%LOGFILE%"
echo   LAUNCHER COMPLETE %date% %time% >> "%LOGFILE%"
echo ========================================== >> "%LOGFILE%"

if exist "%LOCKFILE%" del "%LOCKFILE%" 2>nul
endlocal
exit /b 0
