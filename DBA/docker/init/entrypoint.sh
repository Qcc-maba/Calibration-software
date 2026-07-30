#!/bin/bash
# Bootstraps the local test SQL Server: restore a CalibratorProd backup if one is provided,
# otherwise create an empty schema shell, then apply the cross-environment safety toggles.
set -uo pipefail

SQLCMD=/opt/mssql-tools18/bin/sqlcmd
SERVER=sqlserver
# -C trusts the server's self-signed cert (mssql-tools18 defaults to encrypt).
CONN=(-S "$SERVER" -U sa -P "$MSSQL_SA_PASSWORD" -C -b)

echo "[init] waiting for SQL Server to accept connections..."
for i in $(seq 1 40); do
  if "$SQLCMD" "${CONN[@]}" -Q "SELECT 1" >/dev/null 2>&1; then break; fi
  sleep 3
done
if ! "$SQLCMD" "${CONN[@]}" -Q "SELECT 1" >/dev/null 2>&1; then
  echo "[init] ERROR: SQL Server did not become ready." >&2; exit 1
fi
echo "[init] SQL Server is ready."

# Already initialised? (the safety script creates the calib_test login as a marker)
if "$SQLCMD" "${CONN[@]}" -h -1 -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.sql_logins WHERE name='calib_test'" | grep -q '^\s*1'; then
  echo "[init] Environment already initialised — nothing to do."
  exit 0
fi

BAK=$(ls /backup/*.bak 2>/dev/null | head -1)
if [ -n "$BAK" ]; then
  echo "[init] Found backup: $BAK — restoring as CalibratorTest..."
  "$SQLCMD" "${CONN[@]}" -v BAK="$BAK" -i /init/sql/20_restore.sql || { echo "[init] restore failed"; exit 1; }
else
  echo "[init] No backup in /backup — creating an empty schema shell (CalibratorTest)."
  "$SQLCMD" "${CONN[@]}" -i /init/sql/00_bootstrap.sql || { echo "[init] bootstrap failed"; exit 1; }
fi

echo "[init] applying safety toggles..."
"$SQLCMD" "${CONN[@]}" -v CALIB_TEST_PASSWORD="$CALIB_TEST_PASSWORD" -i /init/sql/10_safety.sql || exit 1

echo "[init] applying the etl logging framework (DBA/sql/03)..."
"$SQLCMD" "${CONN[@]}" -d CalibratorTest -i /project-sql/03_etl_logging_framework.sql || \
  echo "[init] WARN: 03_etl_logging_framework did not apply cleanly (ok if it needs base tables)."

echo "[init] DONE. Connect: sqlserver=localhost,14330  db=CalibratorTest  login=calib_test"
