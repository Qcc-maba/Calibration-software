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

## Never name the Priority server in a module (MBA-1028)

STAGE and PROD share one AWS instance and one set of procedure files, so a server name in a file
is the same server on both. STAGE reads `priority-test` through `[PRIORITY_TEST]`; PROD reads live
Priority through `[31.168.173.93]`. Which one a database uses is the row in
`dbo.PriorityLinkedServer`, changed only by `dbo.SetPriorityLinkedServer` (dry run by default).

- **OPENQUERY:** build the SQL dynamically. A static `OPENQUERY(...)` moves unchanged into
  `EXEC dbo.BuildPriorityOpenQuery @RemoteQuery = N'...', @OpenQuery = @Oq OUTPUT`; then
  `INSERT INTO #T (...) EXEC sys.sp_executesql @Sql`. Where the SQL is already dynamic, splice the
  name from `EXEC dbo.GetPriorityLinkedServer @QuotedName = @PriorityLink OUTPUT`.
- **Four-part names:** use the synonyms `prio.<TABLE>`. A new remote table goes into the list in
  `dbo.SetPriorityLinkedServer` first, and that procedure is re-run on both databases.
- `SELECT * INTO #T FROM OPENQUERY(...)` cannot become dynamic (the temp table would die with the
  `sp_executesql` scope): declare `#T`, with Priority's `varchar` as **`NVARCHAR`**. A `varchar`
  column in this database's Latin collation turns Hebrew into `?`.
- `database/tests/Test-PriorityLinkedServer.sql` fails on any module that names a server, and checks
  that the link reaches the right machine. Run it after every deploy, on both databases.
- **Deploy order on a database that does not have the setting yet** (PROD, a fresh copy): the
  table `dbo.PriorityLinkedServer`, then `dbo.fnPriorityLinkRefusal`, `dbo.GetPriorityLinkedServer`,
  `dbo.BuildPriorityOpenQuery`, `dbo.SetPriorityLinkedServer`, then `SetPriorityLinkedServer` with
  `@Apply = 1` (it creates the row and the `prio` synonyms), and only then the readers. A reader
  deployed earlier fails on every call (208 or 51020), the order screen included. Then the test.
- One-off scripts that read Priority refuse to run outside `CalibratorProd` unless rewritten with
  `dbo.BuildPriorityOpenQuery`; they are not modules, so the test cannot see them.

The resolver refuses rather than guessing: no row (51020), or a server wrong for the database
(51021, `dbo.fnPriorityLinkRefusal`, the only module that may contain the production address).

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

