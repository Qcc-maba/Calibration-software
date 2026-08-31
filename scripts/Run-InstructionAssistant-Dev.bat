@echo off
setlocal EnableDelayedExpansion

:: ==========================================================================
::  Run the Instruction Assistant from source, for debugging.
::
::  The installed MabaInstructionAssistant service already owns
::  127.0.0.1:5311 (from the ASPNETCORE_URLS machine env var), so a plain
::  "dotnet run" dies with:
::      Failed to bind to address http://127.0.0.1:5311: address already in use
::
::  Modes:
::    (no args)   Stop the service, run from source on 5311, restart the
::                service on exit. Needs Admin - self-elevates via UAC.
::    <port>      Leave the service running and use that port instead.
::                No Admin needed. NOTE: both processes then share the same
::                SummaryCache store and the same upstream API key, and
::                anything calling the assistant still points at 5311.
::
::  Usage:  Run-InstructionAssistant-Dev.bat
::          Run-InstructionAssistant-Dev.bat 5312
::
::  Ctrl+C makes cmd ask "Terminate batch job (Y/N)?" - answer N so the
::  script gets to restart the service. If you answer Y, restart it with:
::      net start MabaInstructionAssistant
::
::  Service queries go through PowerShell rather than find/netstat, because
::  a shell with Git's bin on PATH shadows find.exe with the Unix find.
:: ==========================================================================

set "REPO=%~dp0.."
set "PROJ=%REPO%\Systems\InstructionAssistant\Maba.VCT.InstructionAssistant.csproj"
set "SVC=MabaInstructionAssistant"
set "PORT=5311"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass"
set "RC=0"
set "WASRUNNING=0"

set "ALTPORT="
set "PAUSEATEND=0"
for %%A in (%*) do (
    if /I "%%~A"=="--elevated" (set "PAUSEATEND=1") else (set "ALTPORT=%%~A")
)

if not exist "%PROJ%" (
    echo ERROR: project not found: %PROJ%
    set "RC=1"
    goto :done
)

:: ---- side-by-side mode: leave the service alone ----------------------
if not "%ALTPORT%"=="" (
    call :checkfree %ALTPORT%
    if !ERRORLEVEL! NEQ 0 (
        set "RC=1"
        goto :done
    )
    echo [dev] Side-by-side mode - service left running, using port %ALTPORT%.
    set "ASPNETCORE_URLS=http://localhost:%ALTPORT%"
    dotnet run --project "%PROJ%"
    set "RC=!ERRORLEVEL!"
    goto :done
)

:: ---- service mode: needs Admin to stop/start the service -------------
net session >nul 2>&1
if !ERRORLEVEL! NEQ 0 (
    echo [dev] Admin rights needed to stop %SVC% - relaunching elevated...
    %PS% -Command "Start-Process -FilePath '%~f0' -ArgumentList '--elevated' -Verb RunAs"
    goto :done
)

set "SVCSTATE="
for /f "usebackq delims=" %%S in (`%PS% -Command "(Get-Service -Name '%SVC%' -ErrorAction SilentlyContinue).Status"`) do set "SVCSTATE=%%S"

if "!SVCSTATE!"=="" (
    echo [dev] Service %SVC% is not installed - nothing to stop.
    goto :run
)
if /I not "!SVCSTATE!"=="Running" (
    echo [dev] Service %SVC% is !SVCSTATE! - nothing to stop.
    goto :run
)

set "WASRUNNING=1"
echo [dev] Stopping %SVC% ...
%PS% -Command "Stop-Service -Name '%SVC%' -Force -ErrorAction SilentlyContinue; $null = (Get-Service '%SVC%').WaitForStatus('Stopped', '00:00:20')"

set /a TRIES=0
:waitport
set "HOLDER="
for /f "usebackq delims=" %%P in (`%PS% -Command "(Get-NetTCPConnection -LocalPort %PORT% -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty OwningProcess)"`) do set "HOLDER=%%P"
if "!HOLDER!"=="" goto :run
set /a TRIES+=1
if !TRIES! GEQ 10 (
    echo [dev] WARNING: port %PORT% is still held by PID !HOLDER! :
    %PS% -Command "Get-Process -Id !HOLDER! -ErrorAction SilentlyContinue | Format-List Id,ProcessName"
    echo [dev] Continuing anyway - dotnet run will probably fail to bind.
    goto :run
)
ping -n 2 127.0.0.1 >nul
goto :waitport

:run
set "ASPNETCORE_URLS=http://localhost:%PORT%"
echo [dev] Starting from source on http://localhost:%PORT%   (Ctrl+C to stop, then answer N)
echo.
dotnet run --project "%PROJ%"
set "RC=!ERRORLEVEL!"
echo.

if "!WASRUNNING!"=="1" (
    echo [dev] Restarting %SVC% ...
    %PS% -Command "Start-Service -Name '%SVC%'"
    if !ERRORLEVEL! EQU 0 (
        echo [dev] %SVC% is running again.
    ) else (
        echo [dev] WARNING: could not restart %SVC%. Run:  net start %SVC%
    )
)

:: ---- helper: fail if the given port is already listening ------------
:checkfree
set "OWNER="
for /f "usebackq delims=" %%P in (`%PS% -Command "(Get-NetTCPConnection -LocalPort %~1 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty OwningProcess)"`) do set "OWNER=%%P"
if "!OWNER!"=="" exit /b 0
set "OWNERNAME="
for /f "usebackq delims=" %%N in (`%PS% -Command "(Get-Process -Id !OWNER! -ErrorAction SilentlyContinue).ProcessName"`) do set "OWNERNAME=%%N"
echo ERROR: port %~1 is already in use by PID !OWNER! ^(!OWNERNAME!^). Pick another one.
exit /b 1

:done
if "%PAUSEATEND%"=="1" pause
endlocal & exit /b %RC%
