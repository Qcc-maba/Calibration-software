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

:: A lock older than five minutes is not a concurrent run, it is wreckage: the longest a launch can
:: legitimately take is the two-minute wait at step 3. Without this check one killed run made every
:: later click do nothing at all, in silence - four consecutive SKIPPED entries on a customer
:: station, with the operator seeing no window, no error and no browser.
if exist "%LOCKFILE%" (
    powershell -NoProfile -Command "if ((Get-Item -LiteralPath '%LOCKFILE%').LastWriteTime -lt (Get-Date).AddMinutes(-5)) { exit 0 } else { exit 1 }"
    if !ERRORLEVEL! EQU 0 (
        echo   Stale lock from a run that did not finish - removing it and continuing. >> "%LOGFILE%"
        del "%LOCKFILE%" 2>nul
    ) else (
        echo ========================================== >> "%LOGFILE%"
        echo   LAUNCHER SKIPPED %date% %time% >> "%LOGFILE%"
        echo   Another start-all.bat is running, or delete >> "%LOGFILE%"
        echo   %LOCKFILE% >> "%LOGFILE%"
        echo   if a previous run ended abnormally. >> "%LOGFILE%"
        echo ========================================== >> "%LOGFILE%"
        endlocal
        exit /b 0
    )
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
    :: cmd's own `start`, NOT powershell's Start-Process. Start-Process joins -ArgumentList elements
    :: with spaces and does not quote them, so on the default install path the child received
    ::     -File C:\Program Files\Calibration Software\assets\start-webapp.ps1
    :: and powershell.exe answered "Processing -File 'C:\Program' failed" into a hidden window that
    :: nobody ever saw. The script never ran, so it never wrote its own log, while the line below
    :: still reported "Web App started" - the station looked started and had no web app at all.
    :: It only ever bit installs whose path contains a space, which is why every bench install under
    :: C:\tmp worked and the customer's Program Files install did not.
    start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%APPDIR%\assets\start-webapp.ps1"
    echo   Web App started via start-webapp.ps1 ^(hidden^) >> "%LOGFILE%"
) else (
    echo   ERROR: server.js not found! >> "%LOGFILE%"
)

:: ---- Step 3: Show the operator something, immediately ----
:: The history here is two mistakes in a row. First the browser opened on a flat 6-second delay and
:: reached a dead port, so the operator was shown "this site cannot be reached" while the station was
:: still starting - it read as no internet, and the software was blamed. Then the browser was made to
:: wait for the port, which removed the wrong answer and replaced it with NO answer: click the icon,
:: and for up to two minutes nothing happens on screen at all.
::
:: So: open a local page at once. It says the system is starting, counts the seconds, and replaces
:: itself with the application the moment the application answers - the page polls, not this script.
:: The wait below therefore no longer opens anything; it stays only to record the outcome in the log.
echo [3/3] Opening the waiting page and watching port 3000... >> "%LOGFILE%"
if exist "%APPDIR%\assets\starting.html" (
    start "" "%APPDIR%\assets\starting.html"
    echo   Waiting page shown; it will switch to the app by itself. >> "%LOGFILE%"
    set "PAGE_SHOWN=1"
) else (
    echo   WARNING: assets\starting.html missing - falling back to opening the app directly. >> "%LOGFILE%"
    set "PAGE_SHOWN="
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ok=$false; for($i=0;$i -lt 60;$i++){ try { $c=New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1',3000); $c.Close(); $ok=$true; break } catch { Start-Sleep -Seconds 2 } }; if($ok){ exit 0 } else { exit 1 }"
if !ERRORLEVEL! EQU 0 (
    echo   Web app is answering on port 3000. >> "%LOGFILE%"
    if not defined PAGE_SHOWN start http://localhost:3000
) else (
    echo   WARNING: nothing answered on port 3000 after 120s. >> "%LOGFILE%"
    echo   see logs\webapp-launcher.log and logs\webapp-error.log for what node did. >> "%LOGFILE%"
    if not defined PAGE_SHOWN start http://localhost:3000
)

echo ========================================== >> "%LOGFILE%"
echo   LAUNCHER COMPLETE %date% %time% >> "%LOGFILE%"
echo ========================================== >> "%LOGFILE%"

if exist "%LOCKFILE%" del "%LOCKFILE%" 2>nul
endlocal
exit /b 0
