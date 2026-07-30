/**
 * מיגרציה: מעביר נתוני לקוחות מ-Dev ל-Production
 * הרצה: node migrate-to-production.mjs
 */
const PROD_URL = 'https://client-analytics-dashboard--eliran8hadad.replit.app';
const DEV_URL  = 'http://localhost:5000';

async function main() {
  console.log('📤 מביא נתוני לקוחות מ-Dev...');
  const exportRes = await fetch(`${DEV_URL}/api/admin/export-db`);
  if (!exportRes.ok) { console.error('שגיאה ב-export:', exportRes.status); process.exit(1); }
  const { count, customers } = await exportRes.json();
  console.log(`✓ נמצאו ${count} לקוחות`);

  console.log(`📥 מייבא ל-Production (${PROD_URL})...`);
  const CHUNK = 500;
  let total = 0;
  for (let i = 0; i < customers.length; i += CHUNK) {
    const chunk = customers.slice(i, i + CHUNK);
    const importRes = await fetch(`${PROD_URL}/api/admin/bulk-import`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ customers: chunk }),
    });
    if (!importRes.ok) { console.error('שגיאה ב-import:', await importRes.text()); break; }
    const { imported } = await importRes.json();
    total += imported;
    console.log(`  ${total}/${count} יובאו...`);
  }
  console.log(`✅ מיגרציה הושלמה: ${total} לקוחות ב-Production`);
}

main().catch(e => { console.error(e); process.exit(1); });
