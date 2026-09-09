/**
 * Sanity-checks a pricing export (the .xlsx produced by "הורדה לאקסל").
 *
 *   node local-scripts/check-pricing-export.mjs "C:\\Users\\...\\Downloads\\תמחור-2026-09-02.xlsx"
 *
 * The check that matters: a MABA document number is the last calibration of ONE
 * physical device. If two different serial numbers carry the same one, the run
 * reused a cached result across devices and the numbers on screen are fiction.
 * That is exactly the bug found on 02/09/2026 (nine "Crimp tool" rows, one number).
 *
 * Output is ASCII on purpose - Windows consoles render Hebrew as mojibake.
 */
import { readFileSync } from 'fs';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const XLSX = require('xlsx');

const file = process.argv[2];
if (!file) {
  console.error('usage: node local-scripts/check-pricing-export.mjs <exported .xlsx>');
  process.exit(2);
}

const COL = {
  serial: 'מספר סידורי',
  mba: 'מספר מ.ב.א. אחרון',
  desc: 'תיאור הלקוח',
  part: 'מק"ט מ.ב.א. הזורע',
  status: 'סטטוס',
};

const wb = XLSX.read(readFileSync(file), { type: 'buffer' });
const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]]);
if (rows.length === 0) { console.error('the file has no data rows'); process.exit(2); }

const missing = Object.values(COL).filter(c => !(c in rows[0]));
if (missing.length) {
  console.error('this does not look like a pricing export, missing columns: ' + missing.join(', '));
  process.exit(2);
}

const withSerial = rows.filter(r => String(r[COL.serial] ?? '').trim());
const withMba = rows.filter(r => String(r[COL.mba] ?? '').trim());
const withPart = rows.filter(r => String(r[COL.part] ?? '').trim());

// --- the real check: one MABA number must not span two different devices ----
const byMba = new Map();
for (const r of withMba) {
  const mba = String(r[COL.mba]).trim();
  const serial = String(r[COL.serial] ?? '').trim();
  if (!byMba.has(mba)) byMba.set(mba, new Set());
  byMba.get(mba).add(serial);
}
const shared = [...byMba].filter(([, serials]) => serials.size > 1);

// --- secondary: the same serial appearing twice in the customer's own file ---
const serialCounts = new Map();
for (const r of withSerial) {
  const s = String(r[COL.serial]).trim();
  serialCounts.set(s, (serialCounts.get(s) ?? 0) + 1);
}
const repeatedSerials = [...serialCounts].filter(([, n]) => n > 1);

console.log(`file:            ${file}`);
console.log(`rows:            ${rows.length}`);
console.log(`with a serial:   ${withSerial.length}`);
console.log(`with a part no.: ${withPart.length}`);
console.log(`with a MABA no.: ${withMba.length}`);
console.log('');

let failed = false;

if (shared.length === 0) {
  console.log('OK   every MABA number belongs to exactly one serial number');
} else {
  failed = true;
  console.log(`FAIL ${shared.length} MABA number(s) are shared by several devices:`);
  for (const [mba, serials] of shared.slice(0, 20)) {
    console.log(`       ${mba}  <-  ${[...serials].join(' , ')}`);
  }
  if (shared.length > 20) console.log(`       ... and ${shared.length - 20} more`);
  console.log('       -> the run reused one device\'s result for other devices.');
}

if (repeatedSerials.length) {
  console.log(`NOTE ${repeatedSerials.length} serial(s) appear on more than one row of the source file:`);
  for (const [s, n] of repeatedSerials.slice(0, 10)) console.log(`       ${s} x${n}`);
  console.log('       (legitimate if the customer listed the device twice; those rows SHOULD share a MABA number)');
}

process.exit(failed ? 1 : 0);
