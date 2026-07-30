QCC Analytics - Sync Scripts
============================

Last updated: June 1, 2026

Files included:
- sync-customer-data.py (v10.0) - Main sync script with global alerts & returns
- config.py - SQL Server connection configuration
- sync-ups-expenses.py - UPS expenses sync
- sync-single-customer.py - Single customer sync
- run-sync.bat - Full sync for local use
- run-sync-dev.bat - Sync to development environment
- run-sync-prod.bat - Sync to production environment
- run-sync-scheduled.bat - Scheduled automated sync
- setup-scheduled-task.bat - Windows Task Scheduler setup

How to use:
1. Copy all files to a folder on your Windows machine
2. Edit config.py with your SQL Server credentials
3. Run run-sync.bat for a full sync, or run-sync-prod.bat for production
4. For automatic scheduled sync, run setup-scheduled-task.bat

Python auto-detection:
All batch files now auto-detect Python (py/python/python3).

Global sync features:
- sync-customer-data.py now syncs global return documents and calibration alerts
- These populate the company-wide tables in PostgreSQL
- Run with --url to specify target environment
