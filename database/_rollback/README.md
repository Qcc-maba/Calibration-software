# Rollback files — portal customer scope (MBA-943)

## Use this one

**`portal-scope-prod-PRE-CHANGE.sql`** — the real pre-change state, 17 objects, rebuilt from
git HEAD (the MBA-936 versions) plus one procedure that git never tracked and that was still
un-changed on production when it was captured.

```powershell
sqlcmd -S 51.17.121.203 -d CalibratorProd -U app_prod -P <password> -C -I -f 65001 `
       -i database\_rollback\portal-scope-prod-PRE-CHANGE.sql
```

`-f 65001` is not optional. `sqlcmd -i` otherwise reads a UTF-8 file in the console codepage and
stores every Hebrew literal as mojibake — the run succeeds and the damage only shows when a
screen renders the text.

## Do NOT use this one

**`NOT-A-ROLLBACK-POINT.mixed-state-capture-*.sql`** — a capture of the live database taken on
31/08 at 10:18. Production had already been partially changed by then, so this file preserves
the half-deployed state rather than restoring anything. Kept only as a record of what was found.
