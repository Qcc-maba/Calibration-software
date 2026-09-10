#!/usr/bin/env node
// Driver for the customer-analysis (QCC Analytics) dashboard.
// Windows-native (no WSL/Docker assumed). Run from the customer-analysis/ directory:
//   node .claude/skills/run-customer-analysis/driver.mjs <command>
//
// Commands:
//   start   spawn the dev server (tsx server/index.ts), detached, log -> .claude/skills/run-customer-analysis/server.log
//   wait    poll http://localhost:$PORT/ until it responds (default timeout 30s)
//   smoke   hit a few API routes + take a screenshot (implies wait)
//   stop    kill whatever is listening on $PORT
//
// Env vars: PORT (default 5000), CHROME_PATH (auto-detected if unset).

import { spawn, execSync } from 'node:child_process';
import { existsSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SKILL_DIR = path.dirname(fileURLToPath(import.meta.url));
const APP_DIR = path.resolve(SKILL_DIR, '..', '..', '..'); // customer-analysis/
const PORT = process.env.PORT || '5000';
const BASE_URL = `http://localhost:${PORT}`;
const LOG_FILE = path.join(SKILL_DIR, 'server.log');
const SHOT_DIR = path.join(SKILL_DIR, 'screenshots');

function findChrome() {
  if (process.env.CHROME_PATH && existsSync(process.env.CHROME_PATH)) return process.env.CHROME_PATH;
  const candidates = [
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
    'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
  ];
  return candidates.find(existsSync) || null;
}

async function waitForServer(timeoutMs = 30000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(BASE_URL, { signal: AbortSignal.timeout(2000) });
      if (res.status) return true;
    } catch {}
    await new Promise(r => setTimeout(r, 1000));
  }
  return false;
}

function cmdStart() {
  // Two things fought us here on Windows:
  //  1. package.json's own "dev"/"start" scripts use POSIX `NODE_ENV=x cmd` syntax,
  //     which cmd.exe/PowerShell can't parse.
  //  2. Node's own spawn(..., { detached: true }) throws "spawn EINVAL" on Windows
  //     when the target is a .cmd shim (npx.cmd) -- a real Node-on-Windows bug, not
  //     a config mistake.
  // Routing the launch through Git Bash's own `& disown` sidesteps both: bash accepts
  // inline env vars natively, and `disown` genuinely detaches the process from this
  // one's job object, so it survives after this script exits. Verified working on
  // this exact machine (Git for Windows bash on PATH).
  const posixAppDir = APP_DIR.replace(/\\/g, '/').replace(/^([A-Za-z]):/, '/$1');
  const posixLog = LOG_FILE.replace(/\\/g, '/').replace(/^([A-Za-z]):/, '/$1');
  const bashCmd = `cd "${posixAppDir}" && NODE_ENV=development PORT=${PORT} npx tsx server/index.ts > "${posixLog}" 2>&1 & disown`;
  const child = spawn('bash', ['-c', bashCmd], { stdio: 'ignore', detached: true });
  child.unref();
  console.log(`[start] launched via bash & disown, logging to ${LOG_FILE}`);
  console.log(`[start] run "node ${path.basename(fileURLToPath(import.meta.url))} wait" to block until ready`);
}

async function cmdWait() {
  console.log(`[wait] polling ${BASE_URL} ...`);
  const ok = await waitForServer();
  if (!ok) {
    console.error('[wait] server did not respond within timeout. Check server.log');
    process.exit(1);
  }
  console.log('[wait] server is up');
}

async function cmdSmoke() {
  const ok = await waitForServer();
  if (!ok) {
    console.error('[smoke] server never came up. Check server.log');
    process.exit(1);
  }

  const listRes = await fetch(`${BASE_URL}/api/customers/list`);
  const list = await listRes.json();
  console.log(`[smoke] GET /api/customers/list -> HTTP ${listRes.status}, count=${list.count}`);
  if (!listRes.ok || !list.count) {
    console.error('[smoke] FAIL: customer list came back empty -- is Postgres up and synced_customers populated?');
    process.exit(1);
  }

  const firstId = list.customers[0].id;
  const oneRes = await fetch(`${BASE_URL}/api/customers/${firstId}`);
  const one = await oneRes.json();
  console.log(`[smoke] GET /api/customers/${firstId} -> HTTP ${oneRes.status}, companyName=${one.companyName || '(missing)'}`);

  mkdirSync(SHOT_DIR, { recursive: true });
  const shotPath = path.join(SHOT_DIR, 'dashboard.png');
  const chrome = findChrome();
  if (!chrome) {
    console.warn('[smoke] no Chrome/Edge found -- skipping screenshot. Set CHROME_PATH to override.');
    return;
  }
  // --headless=old (not the new default headless mode) is required: with --headless=new,
  // --virtual-time-budget never fires and Chrome hangs indefinitely (see Gotchas).
  // A dedicated --user-data-dir + --disable-background-networking matter too: without
  // them Chrome can hang for minutes contending for the default profile's lock file
  // (e.g. a leftover Chrome process from a prior run) or block on GCM/sync registration
  // network calls before it'll ever get to the actual page load.
  const profileDir = path.join(SHOT_DIR, 'chrome-profile');
  mkdirSync(profileDir, { recursive: true });
  execSync(
    `"${chrome}" --headless=old --disable-gpu --no-sandbox ` +
    `--disable-background-networking --disable-sync --disable-default-apps ` +
    `--disable-extensions --no-first-run --user-data-dir="${profileDir}" ` +
    `--window-size=1440,1000 --virtual-time-budget=6000 --screenshot="${shotPath}" "${BASE_URL}/"`,
    { stdio: 'inherit' }
  );
  console.log(`[smoke] screenshot -> ${shotPath}`);
  console.log('[smoke] PASS');
}

function cmdStop() {
  if (process.platform === 'win32') {
    let pid;
    try {
      const out = execSync(`netstat -ano | findstr :${PORT} | findstr LISTENING`).toString();
      pid = out.trim().split(/\s+/).pop();
    } catch {
      console.log(`[stop] nothing listening on port ${PORT}`);
      return;
    }
    execSync(`taskkill /F /PID ${pid}`, { stdio: 'inherit' });
    console.log(`[stop] killed pid ${pid}`);
  } else {
    execSync(`lsof -ti:${PORT} -sTCP:LISTEN | xargs -r kill`, { stdio: 'inherit', shell: '/bin/bash' });
  }
}

const cmd = process.argv[2];
switch (cmd) {
  case 'start': cmdStart(); break;
  case 'wait': await cmdWait(); break;
  case 'smoke': await cmdSmoke(); break;
  case 'stop': cmdStop(); break;
  default:
    console.error('Usage: node driver.mjs <start|wait|smoke|stop>');
    process.exit(1);
}
