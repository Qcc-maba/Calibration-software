# Systems/OrderAttachments — the order-attachments service

Claude Code loads this file when working under `Systems/OrderAttachments/`. Installing it as a
Windows service, and the ports it shares a machine with, are the **`installing-a-windows-service`**
skill. The SQL objects behind it follow the **`changing-a-database`** skill.

## Commands

```powershell
dotnet test  Systems/OrderAttachments.Tests      # unit + a live .msg pipeline suite
dotnet run --project Systems/OrderAttachments    # console mode, listens on 5313
.\scripts\Install-OrderAttachments-Service.ps1   # installs it as MabaOrderAttachments
```
`Systems/OrderAttachments.Tests/LiveMsgPipelineTests.cs` reads real `.msg` files off the Priority
share; it is skipped where the share is unreachable rather than failing, so a green run does **not**
prove the conversion path works. Prove that with `/health` and one real PDF.

## Configured in-process, on purpose

This service shares a machine with others, so nothing it needs is set through a variable another
process also reads — the `installing-a-windows-service` skill has the two incidents behind that rule.
In `Program.cs`:

- Its URL comes from its own key, `OrderAttachments__Urls`, applied with
  `builder.WebHost.UseUrls(...)` — never from the machine-wide `ASPNETCORE_URLS`, which every ASP.NET
  service on the box reads.
- `PLAYWRIGHT_BROWSERS_PATH` is set with `Environment.SetEnvironmentVariable`, which affects this
  process and the browser driver it spawns and nothing else. Set machine-wide, it redirected a
  different project's Playwright (pinned to chromium-**1208**) into a directory holding only **1234**.

## The order-attachments service (MBA-930)

Serves the documents Priority hangs off an order — quotes, mail threads, drawings — to the calibrator,
converted to PDF. `Systems/OrderAttachments/`, listening on 5313, plus five SQL objects and a proxy
route in `app/`.

```
Priority EXTFILES --(OPENQUERY, cached)--> dbo.CrmOrderAttachments
                                                   |
  browser --> app /api/order-attachments/... --> :5313 --> convert --> PDF cache on disk
```

**The cache table is refreshed, not queried live.** `dbo.RefreshOrderAttachmentsCache` does the whole
`TYPE='O'` set in **one** `OPENQUERY` round-trip and MERGEs it; `@IncrementalOnly BIT = 0` follows the
house dry-run convention. The read side is `dbo.GetOrderAttachmentsByOrder` (one row per file) and
`dbo.GetOrderAttachmentCounts` (batched by CSV of order ids, because the work-assignment grid renders
a page of orders and must not issue one call per row).

Four things about the Priority data that will mislead you:

- **The key is `(order, EXTFILENUM)`, not `(order, LINE)`.** `LINE` has three distinct values in the
  whole table and repeats within an order — order 106663 has two files, both `LINE = 0`. Measured:
  `distinct (IV, EXTFILENUM)` = 15,326 = the row count; `distinct (IV, LINE)` = 13,239. Keying on
  `LINE` gives a primary-key violation on the first full rebuild, and an order can hold **12** files,
  not 4.
- **`EXTFILES.FILESIZE` is not the file size.** 15,225 of 15,326 rows report `74`, which is the length
  of the path string. A row reporting `74` was a 522,752-byte `.msg`. It is deliberately not cached —
  do not use it to pick "the real document".
- **Paths are truncated at 80 characters.** `LEN(RTRIM(path)) >= 80` flags exactly 35 rows; those
  files cannot be opened and the UI must say so rather than showing a broken button.
- `.msg` files carry **Windows-1255**, and .NET ships only Unicode code pages. Without
  `CodePagesEncodingProvider` every Hebrew mail fails at runtime with *"No data is available for
  encoding 1252"* — while `NU1510` insists the `System.Text.Encoding.CodePages` package is
  unnecessary and the project compiles fine without it. That warning is suppressed on purpose.

**A document that cannot be converted must still be visible.** The list returns such parts with an
`Error` instead of omitting them, and the endpoint answers **422**, not 500 — the request was valid,
this one document just cannot become a PDF. The calibrator needs to know the document exists.

