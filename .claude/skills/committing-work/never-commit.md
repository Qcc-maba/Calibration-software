# What is deliberately kept out of git, and why

All of these are in `.gitignore`. The reasons matter, because each one looks like an oversight until
you know it is not.

| Path | Why it is excluded |
|---|---|
| `app/` | its own git repository, cloned inside this one; committing it embeds one repo in another |
| `tmpsetup-watch/` | installer payload left by a build — 267 MB |
| `customer-analysis/data/` | written at runtime: `customer-overrides.json` is every match correction a user has ever confirmed, `pricelist.xlsx` is the customer price list |
| `customer-analysis/deploy/env-additions.txt` | carries a live dashboard password |
| `customer-analysis/local-scripts/_*.mjs` | scratch probes, named with a leading underscore |
| `Installer/assets/.env.station` | generated per station; carries the DB password and S3 keys |
| `Systems/*/appsettings.Development.json` | real connection strings |
| `Installer/drivers/` | third-party driver package |
| `.claude/settings.local.json` | per-machine permissions |
| root `DATABASES.en.pdf` | byte-identical duplicate of the generated `docs/` copy |
| `dist/`, `bin/`, `obj/`, `publish/`, `packages/`, `TestResults/` | build output |

**"Commit it so it is backed up" is not a reason.** Committing `customer-analysis/data/` publishes the
customer price list and freezes learning that is supposed to keep changing.

## A coloured folder is not uncommitted work

When the VS Code explorer colours a folder but `git status` is clean, the folder holds only *ignored*
changes — `bin/`, `obj/`, `publish/`, a service's own log file. Confirm before believing it:

```
git status --ignored --porcelain <path>
```

VS Code also caches ignore state per folder and does not re-read `.gitignore` when it changes from
the terminal, so freshly-ignored directories keep their "untracked" colour and freshly-committed
files keep their `M` badge until Source Control is refreshed. Trust `git status`, not the badges.

## Secrets

Never echo a password, and never write one into a runbook, ticket, commit message or terminal output.
Several `.config` files in this repository already carry plaintext passwords — do not add more, and do
not repeat the existing ones anywhere.
