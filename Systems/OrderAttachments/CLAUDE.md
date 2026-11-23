# Systems/OrderAttachments — order attachments to PDF (MBA-930)

Claude Code loads this file when working under `Systems/OrderAttachments/`. The SQL objects behind it
follow the **`changing-a-database`** skill.

## What it is

A **library** that turns the documents Priority hangs off an order (quotes, purchase orders, mail
threads; 99% Outlook `.msg`) into PDFs. **`Systems/ReportArchiveSync` runs it** on-prem and puts the
PDFs in S3; the app reads the S3 keys from the database and serves signed links.

```
Priority EXTFILES --(RefreshOrderAttachmentsCache)--> dbo.CrmOrderAttachments
      ReportArchiveSync, each cycle: tops up that cache, takes dbo.GetOrderAttachmentsToConvert,
      converts each file (this library), uploads order-attachments/<ORD>/<EXTFILENUM>/<part>.pdf
      and all.pdf, then dbo.SaveOrderAttachmentConversion
        -> dbo.CrmOrderAttachmentConversion (one row per file) + dbo.CrmOrderAttachmentPart (per part)
  app --> dbo.GetOrderAttachmentDocuments (one row per part) --> signed S3 link
```

**Why ahead of time and not on request.** Until 23/11/2026 this was a web service
(`MabaOrderAttachments`, port 5313) that converted when the screen asked. The app runs on Vercel,
which cannot reach Priority's share or a LAN service, and STAGE and PROD could not both run it on one
machine. Converting into S3 from the on-prem `ReportArchiveSync` (the MBA-998 invoice pattern) removes
both problems. The old service and its installer are in git history before that date.

## Commands

```powershell
dotnet test Systems/OrderAttachments.Tests     # unit + a live .msg pipeline suite
dotnet test Systems/ReportArchiveSync.Tests    # the worker side
```
`LiveMsgPipelineTests.cs` reads real `.msg` files off the Priority share; it is skipped where the share
is unreachable rather than failing, so a green run does **not** prove the conversion path works. Run
`ReportArchiveSync` in DryRun against STAGE for that: it converts real files and logs every part.
`database/tests/Test-OrderAttachmentConversion.sql` covers the SQL side and rolls back.

## Things about the Priority data that will mislead you

- **The key is `(order, EXTFILENUM)`, not `(order, LINE)`.** `LINE` has three distinct values in the
  whole table and repeats within an order — order 106663 has two files, both `LINE = 0`. Measured:
  `distinct (IV, EXTFILENUM)` = 15,326 = the row count; `distinct (IV, LINE)` = 13,239. Keying on
  `LINE` gives a primary-key violation on the first full rebuild, and an order can hold **12** files,
  not 4.
- **`EXTFILES.FILESIZE` is not the file size.** 15,225 of 15,326 rows report `74`, which is the length
  of the path string. A row reporting `74` was a 522,752-byte `.msg`. It is deliberately not cached.
- **Paths are truncated at 80 characters.** `LEN(RTRIM(path)) >= 80` flags exactly 35 rows; those
  files cannot be opened and the screen must say so (`FileStatus = 'Unavailable'`).
- **STAGE reads `\\priority-test`, although its rows say `\\maba-priority`.** priority-test is a clone
  of the live server, so `EXTFILES` there stores the live share's absolute path. The path is kept as
  Priority wrote it; `Data/AttachmentShareMap.cs` swaps the root `\\maba-priority\Priority\Attachments`
  for `ReportArchiveSync:OrderAttachmentShare` when a file is opened. Without it a STAGE install would
  read the live share. Checked 22/11/2026: every sampled test row exists under
  `\\priority-test\Priority\Attachments`, in the same layout.
- `.msg` files carry **Windows-1255**, and .NET ships only Unicode code pages. Without
  `CodePagesEncodingProvider` every Hebrew mail fails at runtime with *"No data is available for
  encoding 1252"* — while `NU1510` insists the `System.Text.Encoding.CodePages` package is
  unnecessary and the project compiles fine without it. That warning is suppressed on purpose.
  The host calls `MsgEncoding.EnsureRegistered()` first thing.

## Rules the code keeps

- **A part that cannot be converted is still listed**, with its reason (AC #6). The converter returns
  it as an `Error` part, the table stores the error text, the read procedure returns it.
- **A file that cannot be read at all is not a broken document.** `AttachmentSourceUnreadableException`
  goes back to the sync as outcome 2 (unreadable, retried after hours) or 3 (not found, after days),
  and parts from an earlier success stay served.
- **Recorded only after every PDF is in S3**, so the screen never offers a link that opens nothing.
- **`dbo.CrmOrderAttachments` is truncated on a full refresh**; conversion state therefore lives in its
  own two tables, or every nightly rebuild would convert everything again.
- **Chromium's location is set for the process only** (`PLAYWRIGHT_BROWSERS_PATH` via
  `Environment.SetEnvironmentVariable` in the host). Set machine-wide, it redirected a different
  project's Playwright, pinned to chromium-**1208**, into a directory holding only **1234**.
