@echo off
:: Start webapp in background, output to log
set APPDIR=%~dp0\..
set LOGDIR=%APPDIR%\logs
set WEBAPP=%APPDIR%\webapp
if not exist "%LOGDIR%" mkdir "%LOGDIR%"

cd /d "%WEBAPP%"
if not exist "server.js" (
    echo ERROR: server.js not found >> "%LOGDIR%\webapp.log"
    exit /b 1
)

echo ===== WEBAPP SESSION STARTED %date% %time% ===== >> "%LOGDIR%\webapp.log"
powershell -WindowStyle Hidden -Command "Start-Process -FilePath 'node' -ArgumentList 'server.js' -WorkingDirectory '%WEBAPP%' -WindowStyle Hidden -RedirectStandardOutput '%LOGDIR%\webapp.log' -RedirectStandardError '%LOGDIR%\webapp-error.log'"
