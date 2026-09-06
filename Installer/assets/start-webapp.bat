@echo off
:: Starts the webapp via start-webapp.ps1, which resolves REMOTE_DATABASE_URL for this station
:: from the shipped .env before launching node. See that script for why.
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0start-webapp.ps1"
