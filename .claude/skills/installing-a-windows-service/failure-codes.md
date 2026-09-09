# Service install failures, and what each one actually means

Every row here was diagnosed as something else first. The error text names the mechanism, never the
cause.

| Symptom | Actually |
|---|---|
| `sc.exe create` fails with **exit 1639** ("invalid command line") | The password went on the command line and contains characters `sc.exe` parses. Nothing is wrong with the password. Use `New-Service -Credential`. |
| Service fails to start, **error 1069** ("logon failure") | The account has not been granted **"Log on as a service"**. Not a wrong password — grant `SeServiceLogonRight` with `secedit`, then start it. |
| The password is rejected repeatedly, and it is definitely correct | It was mistyped into a masked prompt. Validate it before use with `PrincipalContext.ValidateCredentials`, so the installer can say "that password is wrong" instead of letting Windows say something vaguer three steps later. |
| Starts, then answers nothing; log shows `Failed to bind to address ...: address already in use` | Another service on the box took the port, almost certainly through a shared `ASPNETCORE_URLS`. Find the owner with `Get-NetTCPConnection -State Listen -OwningProcess`. |
| `/health` returns 200 but the answer is wrong or belongs to another system | The **other** service on that port answered. Compare the body against what this service is supposed to return; do not treat 200 as identity. |
| Connection string is null at startup, under `LocalSystem` | The secret was set at `User` scope. It must be `Machine`. |
| A share the service needs reads as missing, but opens fine for you | The service identity cannot reach it. `LocalSystem` cannot reach a domain share at all — this is what `/health`'s `identity` field is for. |
| An unrelated project's Playwright stops launching after an install | A machine-wide `PLAYWRIGHT_BROWSERS_PATH`. Clear it (needs elevation) and set the path in-process instead. |

## Two that are not service faults

- **A `.msg` that fails with "No data is available for encoding 1252".** The legacy code pages are
  not registered. `NU1510` will insist the `System.Text.Encoding.CodePages` package is unnecessary
  and the project compiles without it; it throws at runtime. The warning is suppressed on purpose.
- **A test suite that passes without proving anything.** The attachments service's live pipeline
  tests read real files off the Priority share and are **skipped** where the share is unreachable
  rather than failing. A green run is not evidence the conversion path works — `/health` plus one
  real converted document is.
