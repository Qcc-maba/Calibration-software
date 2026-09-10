---
name: changing-a-database
description: Add or change a SQL Server column, procedure or data fix across STAGE and PROD - where the file goes, the dry-run pattern every writing object uses, and how to address rows so a script written against one environment does not damage the other. Use when a task needs a schema change, a new stored procedure, or a one-off data correction on Calibrator/CalibratorProd.
---

# Changing a database here

STAGE-only objects are this codebase's most common "works here, missing there" bug, and the in-flight
list has carried "STAGE leads PROD on N procedures" for several sessions running. The procedure below
exists so a change either lands on both or is written down as landing on one.

## Where the file goes

One file per object, committed alongside the change — never only applied to a server.

| Kind | Path |
|---|---|
| Stored procedure / function | `database/procedures/<schema>.<Object>.sql` |
| Column add | `database/schema/dbo.<Table>.<Column>.sql` |
| Constraint | `database/constraints/<Name>.sql` |
| One-off data fix | `database/data/<Verb>-<Thing>.sql` |
| Investigation that writes nothing | `database/diagnostics/` |

`stg` is a real schema, not a prefix: `stg.stg_Customers`, `stg.MergeCustomersData`. Objects there are
named `stg.<Object>.sql`, and `OBJECT_DEFINITION(OBJECT_ID('dbo.X'))` returns **empty** for them — look
objects up through `sys.objects` joined to `sys.schemas` rather than assuming `dbo`.

## The house style for anything that writes

`dbo.RefreshCustomerRemarksFromPriority` is the reference implementation. Copy its shape:

- A header comment saying **why**, with the measured numbers that justify it — not what the code does.
- **`@Apply BIT = 0`**. The default run reports what *would* change and touches nothing. Only
  `@Apply = 1` writes. Always run the dry run first and read the plan.
- **Idempotent.** Write only rows that actually differ, so a second run reports zero changes. That
  property is what makes it safe to re-run after a sync.
- **`IF NOT EXISTS`** around a column add, so the file can be replayed on either server.
- **`OPENQUERY`** when the work belongs on the Priority side. A join written with four-part names
  issues one remote call per row.
- English comments in SQL objects. `sqlcmd -i` reads a UTF-8 file in the console codepage and mangles
  Hebrew silently — inside a comment just as quietly as inside a literal. Pass `-f 65001` if you must.

## Derive the key from the data, do not infer it from the column names

A cache table over `EXTFILES` was keyed on `(order, LINE)` because that is what the column names
suggest. It failed with a primary-key violation on the first full rebuild: `LINE` has three distinct
values in the entire table and repeats within an order. `distinct (IV, EXTFILENUM)` = 15,326 = the
row count; `distinct (IV, LINE)` = 13,239.

Before declaring a key, count it:

```sql
SELECT COUNT(*), COUNT(DISTINCT <candidate key>) FROM <source>;
```

The same measurement tells you the real cardinality — that source allows twelve files per order, not
the four the shape of the data suggested.

While you are there, check whether the columns you plan to carry are **true**. `EXTFILES.FILESIZE`
reports `74` on 15,225 of 15,326 rows, which is the length of the path string; one such row is a
522,752-byte file. A column that is wrong 99.3% of the time is worse than an absent one, because
someone will use it to pick "the real document". It was deliberately not cached.

## Temp tables that receive `OPENQUERY` results need `COLLATE DATABASE_DEFAULT`

Values arrive from the linked server as `Latin1_General_100_CI_AI_SC`; the target table is
`Hebrew_CI_AS`. A `MERGE` comparing them fails outright with a collation conflict. Declare the text
columns of any staging temp table as `COLLATE DATABASE_DEFAULT` and the comparison resolves. This is
the same family as the cross-server join conflict, but it bites inside a single procedure, where
nothing looks cross-server.

## Measure the blast radius before changing a shared function

`dbo.fnUnreverseVisualText` returned `:RE` where a mail subject was `RE:`. The obvious fix — peel the
usual trailing punctuation — was correct for that case and **changed 24 device descriptions for the
worse**, turning `'5000.` into `0005'.`, because `.` and `,` are decimal separators inside the
numeric runs it reverses.

A function used by display code across many screens has no local change. Before deploying one, count
the rows whose output differs:

```sql
SELECT COUNT(*) FROM <table> WHERE dbo.<fn>(col) <> <expected-or-current>;
```

The narrowed version was deployed only once that count read zero outside the case being fixed.

## Address rows by their Priority key, never by an identity column

`CustomerId`, `CustomerContactId` and friends are identity columns and **differ between STAGE and
PROD**. The same fourteen contacts are `44080, 19708, …` on PROD and `48691, 15512, …` on STAGE. A
hardcoded id list written against one environment will hit unrelated rows in the other.

`CustomerIdFromSource` (= Priority `CUST`) is stable everywhere. Take the Priority keys as parameters
at the top of the script and resolve the local ids from them.

## Order of work

1. Write the file, with `@Apply = 0` as the default.
2. **Pre-flight**: count what the change would touch, on both servers, before deploying anything.
3. Deploy to **STAGE**. Run the dry run. Compare against the pre-flight — if the numbers disagree,
   stop and find out why.
4. Apply on STAGE. Verify with a query that would fail if the change were wrong, then re-run the dry
   run and confirm it now reports **zero**.
5. Repeat on **PROD**.
6. Commit the file. If PROD did not happen, say so in the commit body and add it to the in-flight
   list — `database/Compare-Schema.ps1` will show the drift, but only if someone runs it.

Writing to a production database is a permission-gated action. If the tool refuses it, do not route
around it: report what is deployed where, and hand over the exact command.

## Two flags that are not the same thing

`IsDeleted` is **this system's** soft delete, set by our users. `IsInactiveInSource` is the **source
system's** opinion, owned by `dbo.RefreshCustomerStatusFromPriority`. Do not overload one for the
other — a Priority status change would become indistinguishable from a deliberate delete.

A new status column is `NOT NULL DEFAULT 0` meaning "active", so nothing vanishes from a screen in the
window between the column landing and the first refresh.
