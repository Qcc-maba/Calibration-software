@echo off
title Calibration Software - Console Host
cd /d "%~dp0\..\consolehost"
if not exist "Maba.VCT.CommServer.Hosts.ConsoleHost.exe" (
    echo ERROR: ConsoleHost executable not found.
    pause
    exit /b 1
)
echo Starting VCT Console Host ...
start "" "Maba.VCT.CommServer.Hosts.ConsoleHost.exe"
