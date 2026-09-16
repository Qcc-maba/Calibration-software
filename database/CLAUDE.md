# database — SQL Server objects

Claude Code loads this file when working under `database/`. Where each kind of file goes, the
`@Apply BIT = 0` dry-run house style, idempotency, the `stg` schema trap, the two "inactive" flags,
measuring a shared function's blast radius, and the order of work across STAGE and PROD are the
**`changing-a-database`** skill — read it before writing anything that changes a server.
`database/Compare-Schema.ps1` diffs the STAGE and PROD schemas.

Besides the folders in that skill's table (`procedures/`, `schema/`, `constraints/`, `data/`,
`diagnostics/`), this directory also holds `jobs/`, `sync/`, `tests/`, `deploy-prod/` and
`_rollback/`.

Rules that cross areas — addressing rows by their Priority key, how STAGE and PROD differ, the two SQL
Servers, and Priority's data traps — are in the root `CLAUDE.md`.

## The wizard's "already assigned" error is a business rule

`dbo.AssignMeasurmentDeviceToOrderDetailsItems` throws `51000, 'Sensor with specified channel(s)
already assigned to other device.'` when the same logger + sensor pair is used on two devices of one
order line. Despite the message the guard **ignores channels**, so a 5-channel sensor cannot serve
two devices on one line even on different channels. The router maps it to a tRPC `CONFLICT` and the
screen shows a Hebrew message; before that it surfaced as a bare 500. Changing the rule is the
procedure owner's call, not a bug to fix in passing.

**Reproduce a write-path error without writing:** pyodbc with `autocommit=False`, execute the
procedure, read the exception, `rollback()`. Only a faithful payload reproduces — a guessed one
"succeeds" and proves nothing. This is what produced the real text behind two "Internal server
error"s in one afternoon.

