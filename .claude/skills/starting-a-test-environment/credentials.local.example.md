# Test-environment logins (local only) - TEMPLATE

Copy this file to `credentials.local.md` beside it and fill in the values. That name is gitignored;
this template is not, so it must never carry a real secret.

Ask a teammate for the internal password - it is shared and deliberately absent from the repo, so
that rotating it does not mean rewriting git history.

| Where | Who | Secret |
|---|---|---|
| Internal app, `localhost:3000/sign-in` | any user from the dropdown | `<ask a teammate>` |
| Customer portal, `/customer/sign-in` | a real portal contact | `000000` in Development - see below |
| Local SQL container `calibrator-test-sql` | `calib_test` | `CALIB_TEST_PASSWORD` in `DBA\.env` |
| Local SQL container, admin | `sa` | `MSSQL_SA_PASSWORD` in `DBA\.env` |

**The portal code is not really a secret.** When `Systems/CustomerPortalApi` runs in Development from
a loopback caller it forces every one-time code to `000000` and logs
`DEVELOPMENT LOGIN CODE IS ACTIVE` at startup. It cannot happen on a reachable service, so it is safe
to write down here.

The two database passwords are named, not quoted - they already live in `DBA\.env`, which is
gitignored. Never copy their values into this file.
