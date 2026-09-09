QCC Analytics - Sync Scripts
============================

Last updated: June 1, 2026 (v3 - Clean batch files)

FIXED in this version:
- SSL certificate error: Added TrustServerCertificate=yes
- Driver auto-detection: All scripts auto-detect ODBC driver
- Windows encoding issues: All batch files use ONLY English text
- UPS script: Auto-detects driver instead of hardcoded

Files included:
- sync-customer-data.py (v10.45) - Main sync with global alerts and returns
- config.py - SQL Server connection (production URL set)
- sync-ups-expenses.py - UPS expenses sync (auto-detects driver)
- sync-single-customer.py - Single customer sync
- run-sync.bat - Full sync for local use
- run-sync-dev.bat - Sync to dev environment
- run-sync-prod.bat - Sync to production
- run-sync-scheduled.bat - Scheduled automated sync

How to use:
1. Extract all files to a folder on your Windows machine
2. Run: run-sync-dev.bat (for dev) or run-sync-prod.bat (for production)

Requirements:
- Python 3 (py / python / python3)
- ODBC Driver for SQL Server (17 or 18)
- Access to Priority ERP (maba-priority\pri)

Production: https://client-analytics-dashboard--eliran8hadad.replit.app
Dev: https://232ca506-7be9-4e7f-a436-7bb478f77860-00-1bf7ltq07a1po.riker.replit.dev
