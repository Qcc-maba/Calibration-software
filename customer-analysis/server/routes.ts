import type { Express } from "express";
import { type Server } from "http";
import { gzipSync } from "zlib";
import { db } from "./db";
import * as priority from "./priority";
import { syncedCustomers, appSettings, defaultScoringConfig, companyDaysOff, insertCompanyDayOffSchema, upsExpenses, insertUpsExpenseSchema, shipShipments, departmentStats, calibratorDeptStats, calibrators, monthlyCallStats, companyReturnDocuments, companyCalibrationAlerts, operationalQueryRows, financialQueryRows, monthlyTargets } from "@shared/schema";
import { eq, sql } from "drizzle-orm";
import ExcelJS from "exceljs";

// Concurrency limiter for sync endpoint - prevents DB overload
let syncConcurrency = 0;
const MAX_SYNC_CONCURRENCY = 5;
async function withSyncConcurrency<T>(fn: () => Promise<T>): Promise<T> {
  const waitStart = Date.now();
  while (syncConcurrency >= MAX_SYNC_CONCURRENCY) {
    if (Date.now() - waitStart > 60000) throw new Error('Sync queue timeout');
    await new Promise(r => setTimeout(r, 200));
  }
  syncConcurrency++;
  try { return await fn(); } finally { syncConcurrency--; }
}

// ─── In-memory customer list cache ──────────────────────────────────────────
// Built once at startup and refreshed after each sync batch.
// Serves /api/customers/list in <5ms instead of 4s DB round-trip.
interface CustomerListCache {
  customers: any[];
  yearlyFinancials: any[];
  builtAt: Date;
}
let customerListCache: CustomerListCache | null = null;
let customerListCacheJson: string | null = null;       // pre-serialized JSON string
let customerListCacheGzip: Buffer | null = null;        // pre-compressed for gzip clients
let cacheBuilding = false;

// Promise that resolves when the cache is first built (used to wait on startup)
let cacheReadyPromise: Promise<void> | null = null;
let cacheReadyResolve: (() => void) | null = null;
cacheReadyPromise = new Promise<void>(resolve => { cacheReadyResolve = resolve; });

async function buildCustomerListCache(): Promise<void> {
  if (cacheBuilding) return;
  cacheBuilding = true;
  let attempts = 0;
  while (attempts < 3) {
    attempts++;
    try {
      // Run queries sequentially to avoid connection contention
      const listRows = await db.execute(sql`
        SELECT
          data->>'id'             AS id,
          data->>'hp'             AS hp,
          data->>'companyName'    AS "companyName",
          data->>'agentName'      AS "agentName",
          data->'customerScore'   AS "customerScore",
          data->'deviceInventory' AS "deviceInventory",
          data->'alerts'          AS alerts,
          data->'financials'      AS financials,
          data->'pendingForecast' AS "pendingForecast",
          synced_at               AS "syncedAt",
          (SELECT COALESCE(jsonb_agg(m ORDER BY m->>'month'), '[]'::jsonb)
           FROM jsonb_array_elements(COALESCE(data->'monthlyRevenue', '[]'::jsonb)) m
           WHERE (m->>'month') >= '2022-01') AS "monthlyRevenue"
        FROM synced_customers
      `);
      const yearlyRows = await db.execute(sql`
        SELECT
          (f->>'year')::int                               AS year,
          COALESCE(SUM((f->>'revenue')::float), 0)        AS revenue,
          COALESCE(SUM((f->>'invoicesCount')::int), 0)    AS "invoicesCount",
          COALESCE(SUM((f->>'quotesCount')::int), 0)      AS "quotesCount",
          COALESCE(SUM((f->>'quotesRevenue')::float), 0)  AS "quotesRevenue",
          COALESCE(SUM((f->>'ordersCount')::int), 0)      AS "ordersCount",
          COALESCE(SUM((f->>'ordersRevenue')::float), 0)  AS "ordersRevenue",
          COALESCE(SUM((f->>'returnsRevenue')::float), 0) AS "returnsRevenue",
          COALESCE(SUM((f->>'returnsCount')::int), 0)     AS "returnsCount"
        FROM synced_customers,
             jsonb_array_elements(COALESCE(data->'financials', '[]'::jsonb)) AS f
        WHERE (f->>'year')::int IN (2024, 2025, 2026)
        GROUP BY (f->>'year')::int
        ORDER BY year
      `);
      customerListCache = {
        customers: listRows.rows as any[],
        yearlyFinancials: yearlyRows.rows as any[],
        builtAt: new Date(),
      };
      // Pre-serialize once so each request just sends the string (no per-request JSON.stringify)
      customerListCacheJson = JSON.stringify({
        customers: customerListCache.customers,
        count: customerListCache.customers.length,
        yearlyFinancials: customerListCache.yearlyFinancials,
      });
      // Pre-compress for gzip clients (browsers always support gzip)
      customerListCacheGzip = gzipSync(Buffer.from(customerListCacheJson, 'utf8'), { level: 6 });
      console.log(`✓ Customer list cache built (${customerListCache.customers.length} customers, ${Math.round(customerListCacheJson.length / 1024)}KB raw / ${Math.round(customerListCacheGzip.length / 1024)}KB gzip)`);
      // Signal any waiting requests that the cache is ready
      if (cacheReadyResolve) { cacheReadyResolve(); cacheReadyResolve = null; }
      break; // success
    } catch (err: any) {
      console.error(`Failed to build customer list cache (attempt ${attempts}/3):`, err.message);
      if (attempts < 3) {
        await new Promise(r => setTimeout(r, 2000 * attempts)); // back-off: 2s, 4s
      }
    }
  }
  cacheBuilding = false;
}
// ────────────────────────────────────────────────────────────────────────────

// Global sync state machine (in-memory, resets on server restart)
// Flow: idle → requested (dashboard) → running (local script starts) → complete/error
type GlobalSyncStatus = 'idle' | 'requested' | 'running' | 'complete' | 'error';
let globalSyncState: {
  status: GlobalSyncStatus;
  requestedAt: Date | null;
  startedAt: Date | null;
  completedAt: Date | null;
  error: string | null;
} = { status: 'idle', requestedAt: null, startedAt: null, completedAt: null, error: null };

// Sync status tracking (in-memory is fine for this)
let syncStatus = {
  lastSyncTime: null as Date | null,
  totalSynced: 0,
  currentSessionSynced: 0,  // Counter for current sync session
  syncSessionStart: null as Date | null,
  recentlySynced: [] as { id: string, name: string, time: Date }[]
};

// Auto-migration to production after sync session ends
const PRODUCTION_URL = process.env.PRODUCTION_URL || 'https://client-analytics-dashboard--eliran8hadad.replit.app';
const AUTO_MIGRATE_DELAY_MS = 3 * 60 * 1000; // 3 minutes after last sync

let migrationStatus = {
  isRunning: false,
  lastMigrationTime: null as Date | null,
  lastMigrationCount: 0,
  lastMigrationError: null as string | null,
  autoMigrateEnabled: true,
};
let autoMigrateTimer: ReturnType<typeof setTimeout> | null = null;

async function runMigrationToProduction(): Promise<void> {
  if (migrationStatus.isRunning) return;
  // Skip if running in production (avoid self-migration)
  if (process.env.NODE_ENV === 'production') return;

  migrationStatus.isRunning = true;
  migrationStatus.lastMigrationError = null;
  console.log('[MIGRATION] Starting auto-migration to production...');

  const MAX_DEVICES = 2000;
  function trimCustomerForMigration(c: any) {
    if (!c || !Array.isArray(c.devicesList) || c.devicesList.length <= MAX_DEVICES) return c;
    // Sort: expired first, then by nextCalDate ascending, then no date last
    const sorted = [...c.devicesList].sort((a, b) => {
      const aExp = a.status === 'expired';
      const bExp = b.status === 'expired';
      if (aExp && !bExp) return -1;
      if (!aExp && bExp) return 1;
      if (a.nextCalDate && b.nextCalDate) return a.nextCalDate.localeCompare(b.nextCalDate);
      if (a.nextCalDate) return -1;
      if (b.nextCalDate) return 1;
      return 0;
    });
    return { ...c, devicesList: sorted.slice(0, MAX_DEVICES) };
  }

  try {
    const rows = await db.select().from(syncedCustomers);
    const customers = rows.map(r => trimCustomerForMigration(r.data));
    const CHUNK = 50;
    let total = 0;
    for (let i = 0; i < customers.length; i += CHUNK) {
      const chunk = customers.slice(i, i + CHUNK);
      const res = await fetch(`${PRODUCTION_URL}/api/admin/bulk-import`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ customers: chunk }),
        signal: AbortSignal.timeout(60000),
      });
      if (!res.ok) {
        const errText = await res.text();
        throw new Error(`Production import failed at ${i}-${i+CHUNK}: ${res.status} ${errText.slice(0,200)}`);
      }
      const { imported } = await res.json() as { imported: number };
      total += imported;
      if (total % 500 === 0 || i + CHUNK >= customers.length) {
        console.log(`[MIGRATION] ${total}/${customers.length} migrated...`);
      }
    }
    migrationStatus.lastMigrationTime = new Date();
    migrationStatus.lastMigrationCount = total;
    console.log(`[MIGRATION] ✅ Customers done — ${total} migrated to production`);

    // Also migrate department_stats
    const deptRows = await db.select().from(departmentStats);
    if (deptRows.length > 0) {
      const DEPT_CHUNK = 504;
      for (let i = 0; i < deptRows.length; i += DEPT_CHUNK) {
        const chunk = deptRows.slice(i, i + DEPT_CHUNK).map(r => ({
          ...r,
          syncedAt: r.syncedAt instanceof Date ? r.syncedAt.toISOString() : r.syncedAt,
        }));
        const res2 = await fetch(`${PRODUCTION_URL}/api/admin/bulk-import-dept-stats`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ stats: chunk }),
          signal: AbortSignal.timeout(30000),
        });
        if (!res2.ok) throw new Error(`Dept stats import failed: ${res2.status} ${await res2.text()}`);
      }
      console.log(`[MIGRATION] ✅ Department stats done — ${deptRows.length} rows migrated to production`);
    }

    // Migrate calibrator_dept_stats
    const calibDeptRows = await db.select().from(calibratorDeptStats);
    if (calibDeptRows.length > 0) {
      const CHUNK = 400;
      for (let i = 0; i < calibDeptRows.length; i += CHUNK) {
        const chunk = calibDeptRows.slice(i, i + CHUNK).map(r => ({
          ...r,
          syncedAt: r.syncedAt instanceof Date ? r.syncedAt.toISOString() : r.syncedAt,
        }));
        const res3 = await fetch(`${PRODUCTION_URL}/api/admin/bulk-import-calibrator-dept-stats`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ stats: chunk }),
          signal: AbortSignal.timeout(30000),
        });
        if (!res3.ok) throw new Error(`Calibrator dept stats import failed: ${res3.status} ${await res3.text()}`);
      }
      console.log(`[MIGRATION] ✅ Calibrator dept stats done — ${calibDeptRows.length} rows migrated to production`);
    }

    // Migrate calibrators
    const calibRows = await db.select().from(calibrators);
    if (calibRows.length > 0) {
      const res4 = await fetch(`${PRODUCTION_URL}/api/admin/bulk-import-calibrators`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ calibrators: calibRows.map(r => ({ ...r, syncedAt: r.syncedAt instanceof Date ? r.syncedAt.toISOString() : r.syncedAt })) }),
        signal: AbortSignal.timeout(30000),
      });
      if (!res4.ok) throw new Error(`Calibrators import failed: ${res4.status} ${await res4.text()}`);
      console.log(`[MIGRATION] ✅ Calibrators done — ${calibRows.length} rows migrated to production`);
    }

    // Migrate operational_query_rows
    const opRows = await db.select().from(operationalQueryRows);
    if (opRows.length > 0) {
      const OP_CHUNK = 200;
      for (let i = 0; i < opRows.length; i += OP_CHUNK) {
        const chunk = opRows.slice(i, i + OP_CHUNK).map(r => ({
          ...r,
          syncedAt: r.syncedAt instanceof Date ? r.syncedAt.toISOString() : r.syncedAt,
        }));
        const res5 = await fetch(`${PRODUCTION_URL}/api/admin/bulk-import-operational-rows`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ rows: chunk }),
          signal: AbortSignal.timeout(60000),
        });
        if (!res5.ok) throw new Error(`Operational rows import failed: ${res5.status} ${await res5.text()}`);
      }
      console.log(`[MIGRATION] ✅ Operational query rows done — ${opRows.length} rows migrated to production`);
    }

    // Migrate financial_query_rows
    const finRows = await db.select().from(financialQueryRows);
    if (finRows.length > 0) {
      const FIN_CHUNK = 200;
      for (let i = 0; i < finRows.length; i += FIN_CHUNK) {
        const chunk = finRows.slice(i, i + FIN_CHUNK).map(r => ({
          ...r,
          syncedAt: r.syncedAt instanceof Date ? r.syncedAt.toISOString() : r.syncedAt,
        }));
        const res6 = await fetch(`${PRODUCTION_URL}/api/admin/bulk-import-financial-rows`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ rows: chunk }),
          signal: AbortSignal.timeout(60000),
        });
        if (!res6.ok) throw new Error(`Financial rows import failed: ${res6.status} ${await res6.text()}`);
      }
      console.log(`[MIGRATION] ✅ Financial query rows done — ${finRows.length} rows migrated to production`);
    }

  } catch (err: any) {
    migrationStatus.lastMigrationError = err.message;
    console.error('[MIGRATION] ❌ Error:', err.message);
  } finally {
    migrationStatus.isRunning = false;
  }
}

function scheduleAutoMigration() {
  if (!migrationStatus.autoMigrateEnabled) return;
  if (autoMigrateTimer) clearTimeout(autoMigrateTimer);
  autoMigrateTimer = setTimeout(() => {
    console.log('[MIGRATION] Sync session ended — triggering auto-migration to production...');
    runMigrationToProduction();
  }, AUTO_MIGRATE_DELAY_MS);
}

export async function registerRoutes(
  httpServer: Server,
  app: Express
): Promise<Server> {
  
  // Load initial sync status from database (efficient queries, no full-table load)
  try {
    const [countRow] = await db.select({ count: sql<number>`COUNT(*)` }).from(syncedCustomers);
    syncStatus.totalSynced = Number(countRow?.count ?? 0);
    if (syncStatus.totalSynced > 0) {
      const [latestRow] = await db.select({ syncedAt: syncedCustomers.syncedAt })
        .from(syncedCustomers)
        .orderBy(sql`synced_at DESC`)
        .limit(1);
      if (latestRow) syncStatus.lastSyncTime = latestRow.syncedAt;
      const recentRows = await db.select({ id: syncedCustomers.id, companyName: syncedCustomers.companyName, syncedAt: syncedCustomers.syncedAt })
        .from(syncedCustomers)
        .orderBy(sql`synced_at DESC`)
        .limit(5);
      syncStatus.recentlySynced = recentRows.map(c => ({ id: c.id, name: c.companyName, time: c.syncedAt }));
    }
    console.log(`✓ Loaded ${syncStatus.totalSynced} customers from database`);
    // Build lightweight list cache in background (takes a few seconds)
    buildCustomerListCache().catch(() => {});
  } catch (error) {
    console.log('Database not ready yet, starting with empty cache');
  }
  
  // Manually trigger migration to production
  app.post("/api/admin/trigger-migration", async (_req, res) => {
    if (process.env.NODE_ENV === 'production') {
      return res.status(400).json({ error: 'Cannot run migration from production' });
    }
    res.json({ message: 'Migration triggered' });
    runMigrationToProduction();
  });

  // Export all raw customer data (for migrating between dev and production)
  app.get("/api/admin/export-db", async (req, res) => {
    try {
      const rows = await db.select().from(syncedCustomers);
      res.json({ count: rows.length, customers: rows.map(r => r.data) });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  });

  // Bulk import customer data (for migrating between dev and production)
  app.post("/api/admin/bulk-import", async (req, res) => {
    try {
      const { customers } = req.body;
      if (!Array.isArray(customers)) return res.status(400).json({ error: 'customers array required' });
      let imported = 0;
      const BATCH = 100;
      for (let i = 0; i < customers.length; i += BATCH) {
        const batch = customers.slice(i, i + BATCH);
        for (const customerData of batch) {
          if (!customerData.id) continue;
          await db.insert(syncedCustomers)
            .values({ id: customerData.id, hp: customerData.hp || customerData.id, companyName: customerData.companyName, data: customerData, syncedAt: new Date() })
            .onConflictDoUpdate({ target: syncedCustomers.id, set: { hp: customerData.hp || customerData.id, companyName: customerData.companyName, data: customerData, syncedAt: new Date() } });
          imported++;
        }
      }
      // Get actual total from DB so the status counter is correct across multiple batch calls
      const [{ count }] = await db.select({ count: sql<number>`count(*)::int` }).from(syncedCustomers);
      syncStatus.totalSynced = count;
      syncStatus.lastSyncTime = new Date();
      res.json({ success: true, imported, total: count });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  });

  // Export department stats (for migration to production)
  app.get("/api/admin/export-dept-stats", async (_req, res) => {
    try {
      const rows = await db.select().from(departmentStats);
      res.json({ count: rows.length, stats: rows });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  });

  // Bulk import department stats (for migration to production)
  app.post("/api/admin/bulk-import-dept-stats", async (req, res) => {
    try {
      const { stats } = req.body;
      if (!Array.isArray(stats)) return res.status(400).json({ error: 'stats array required' });
      const valid = stats.filter((r: any) => r.id);
      if (valid.length === 0) return res.json({ success: true, imported: 0 });
      const BATCH = 200;
      let imported = 0;
      for (let i = 0; i < valid.length; i += BATCH) {
        const chunk = valid.slice(i, i + BATCH).map((r: any) => {
          const { syncedAt, ...rest } = r;
          return rest;
        });
        await db.insert(departmentStats).values(chunk).onConflictDoUpdate({
          target: departmentStats.id,
          set: {
            deptName: sql`excluded.dept_name`,
            agentName: sql`excluded.agent_name`,
            customerCount: sql`excluded.customer_count`,
            callCount: sql`excluded.call_count`,
            revenue: sql`excluded.revenue`,
          }
        });
        imported += chunk.length;
      }
      res.json({ success: true, imported });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  });

  // Bulk import calibrator dept stats (for migration to production)
  app.post("/api/admin/bulk-import-calibrator-dept-stats", async (req, res) => {
    try {
      const { stats } = req.body;
      if (!Array.isArray(stats)) return res.status(400).json({ error: 'stats array required' });
      const valid = stats.filter((r: any) => r.id);
      if (valid.length === 0) return res.json({ success: true, imported: 0 });
      const BATCH = 200;
      let imported = 0;
      for (let i = 0; i < valid.length; i += BATCH) {
        const chunk = valid.slice(i, i + BATCH).map((r: any) => {
          const { syncedAt, ...rest } = r;
          return rest;
        });
        await db.insert(calibratorDeptStats).values(chunk).onConflictDoUpdate({
          target: calibratorDeptStats.id,
          set: {
            deptName: sql`excluded.dept_name`,
            customerCount: sql`excluded.customer_count`,
            callCount: sql`excluded.call_count`,
            revenue: sql`excluded.revenue`,
          }
        });
        imported += chunk.length;
      }
      res.json({ success: true, imported });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  });

  // Bulk import calibrators (for migration to production)
  app.post("/api/admin/bulk-import-calibrators", async (req, res) => {
    try {
      const { calibrators: list } = req.body;
      if (!Array.isArray(list)) return res.status(400).json({ error: 'calibrators array required' });
      if (list.length === 0) return res.json({ success: true, imported: 0 });
      const rows = list.map((r: any) => ({
        userId: String(r.userId),
        fullName: r.fullName || null,
        agentCode: r.agentCode || null,
        calibrationCount: Number(r.calibrationCount) || 0,
      }));
      await db.insert(calibrators).values(rows).onConflictDoUpdate({
        target: calibrators.userId,
        set: { fullName: sql`excluded.full_name`, agentCode: sql`excluded.agent_code`, calibrationCount: sql`excluded.calibration_count` }
      });
      res.json({ success: true, imported: rows.length });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  });

  // Bulk import operational query rows (for migration to production)
  app.post("/api/admin/bulk-import-operational-rows", async (req, res) => {
    try {
      const { rows: list } = req.body;
      if (!Array.isArray(list)) return res.status(400).json({ error: 'rows array required' });
      if (list.length === 0) return res.json({ success: true, imported: 0 });
      const BATCH = 100;
      let imported = 0;
      for (let i = 0; i < list.length; i += BATCH) {
        const chunk = list.slice(i, i + BATCH).map((r: any) => ({
          id: r.id,
          docNo: r.docNo || null,
          docDate: r.docDate || null,
          custName: r.custName || null,
          syncId: r.syncId || null,
          data: r.data,
        }));
        await db.insert(operationalQueryRows).values(chunk).onConflictDoUpdate({
          target: operationalQueryRows.id,
          set: { data: sql`excluded.data`, syncId: sql`excluded.sync_id` }
        });
        imported += chunk.length;
      }
      res.json({ success: true, imported });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  });

  // Bulk import financial query rows (for migration to production)
  app.post("/api/admin/bulk-import-financial-rows", async (req, res) => {
    try {
      const { rows: list } = req.body;
      if (!Array.isArray(list)) return res.status(400).json({ error: 'rows array required' });
      if (list.length === 0) return res.json({ success: true, imported: 0 });
      const BATCH = 100;
      let imported = 0;
      for (let i = 0; i < list.length; i += BATCH) {
        const chunk = list.slice(i, i + BATCH).map((r: any) => ({
          id: r.id,
          ivNum: r.ivNum || null,
          ivDate: r.ivDate || null,
          custName: r.custName || null,
          syncId: r.syncId || null,
          data: r.data,
        }));
        await db.insert(financialQueryRows).values(chunk).onConflictDoUpdate({
          target: financialQueryRows.id,
          set: { data: sql`excluded.data`, syncId: sql`excluded.sync_id` }
        });
        imported += chunk.length;
      }
      res.json({ success: true, imported });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  });

  // Department stats sync endpoint (from local script)
  // Calibrators sync — receives T$USER→name mapping from local script
  app.post("/api/sync/calibrators", async (req, res) => {
    try {
      const { calibrators: list } = req.body;
      if (!Array.isArray(list)) return res.status(400).json({ error: 'calibrators array required' });
      if (list.length === 0) return res.json({ success: true, saved: 0 });
      const rows = list.map((r: any) => ({
        userId: String(r.userId),
        fullName: r.fullName || null,
        agentCode: r.agentCode || null,
        calibrationCount: Number(r.calibrationCount) || 0,
        syncedAt: new Date(),
      }));
      await db.insert(calibrators).values(rows).onConflictDoUpdate({
        target: calibrators.userId,
        set: {
          fullName: sql`excluded.full_name`,
          agentCode: sql`excluded.agent_code`,
          calibrationCount: sql`excluded.calibration_count`,
          syncedAt: sql`excluded.synced_at`,
        }
      });
      console.log(`[CALIB] Saved ${rows.length} calibrators`);
      res.json({ success: true, saved: rows.length });
    } catch (error: any) {
      console.error('[CALIB] Error:', error.message);
      res.status(500).json({ error: error.message });
    }
  });

  // Get all calibrators
  // Monthly revenue targets (₪), persisted in the local DB. GET auto-seeds the 2026 defaults on
  // first read; POST upserts a full 12-month array (index 0 = January).
  const DEFAULT_TARGETS_2026 = [2956688, 2672056, 3162523, 1972449, 2830916, 2627561, 3023079, 2972763, 2014610, 2672366, 2945973, 3245720];

  app.get("/api/targets/:year", async (req, res) => {
    try {
      const year = String(req.params.year);
      let rows = await db.select().from(monthlyTargets).where(sql`${monthlyTargets.yearMonth} LIKE ${year + '-%'}`);
      if (rows.length === 0 && year === '2026') {
        const seed = DEFAULT_TARGETS_2026.map((amt, i) => ({ yearMonth: `${year}-${String(i + 1).padStart(2, '0')}`, targetAmount: amt }));
        await db.insert(monthlyTargets).values(seed).onConflictDoNothing();
        rows = await db.select().from(monthlyTargets).where(sql`${monthlyTargets.yearMonth} LIKE ${year + '-%'}`);
      }
      const monthly = Array.from({ length: 12 }, () => 0);
      for (const r of rows) {
        const m = parseInt(r.yearMonth.split('-')[1], 10);
        if (m >= 1 && m <= 12) monthly[m - 1] = r.targetAmount;
      }
      res.json({ year: Number(year), monthly });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post("/api/targets/:year", async (req, res) => {
    try {
      const year = String(req.params.year);
      const monthly = req.body?.monthly;
      if (!Array.isArray(monthly) || monthly.length !== 12) {
        return res.status(400).json({ error: 'monthly must be an array of 12 numbers (Jan..Dec)' });
      }
      const rows = monthly.map((amt: any, i: number) => ({
        yearMonth: `${year}-${String(i + 1).padStart(2, '0')}`,
        targetAmount: Number(amt) || 0,
        updatedAt: new Date(),
      }));
      await db.insert(monthlyTargets).values(rows).onConflictDoUpdate({
        target: monthlyTargets.yearMonth,
        set: { targetAmount: sql`excluded.target_amount`, updatedAt: sql`excluded.updated_at` },
      });
      res.json({ success: true, year: Number(year), monthly: monthly.map((a: any) => Number(a) || 0) });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  });

  // Monthly call stats (company-wide calibration service calls from Priority ERP)
  app.get("/api/monthly-call-stats", async (_req, res) => {
    try {
      const rows = await db.select().from(monthlyCallStats).orderBy(monthlyCallStats.yearMonth);
      res.json(rows);
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post("/api/sync/monthly-call-stats", async (req, res) => {
    try {
      const { stats } = req.body;
      if (!Array.isArray(stats)) return res.status(400).json({ error: 'stats array required' });
      if (stats.length === 0) return res.json({ success: true, imported: 0 });
      const rows = stats.map(r => ({
        yearMonth: String(r.yearMonth),
        callCount: Number(r.callCount) || 0,
        syncedAt: new Date(),
      }));
      await db.insert(monthlyCallStats)
        .values(rows)
        .onConflictDoUpdate({
          target: monthlyCallStats.yearMonth,
          set: {
            callCount: sql`excluded.call_count`,
            syncedAt: sql`excluded.synced_at`,
          }
        });
      console.log(`[MONTHLY-CALLS] Synced ${rows.length} monthly call stat rows`);
      res.json({ success: true, imported: rows.length });
    } catch (error: any) {
      console.error('[MONTHLY-CALLS] Sync error:', error.message);
      res.status(500).json({ error: error.message });
    }
  });

  app.get("/api/calibrators", async (_req, res) => {
    try {
      const rows = await db.select().from(calibrators);
      res.json(rows);
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post("/api/sync/department-stats", async (req, res) => {
    try {
      const { stats } = req.body;
      if (!Array.isArray(stats)) return res.status(400).json({ error: 'stats array required' });
      const valid = stats.filter(r => r.id);
      if (valid.length === 0) return res.json({ success: true, imported: 0 });

      const BATCH = 200;
      let imported = 0;
      for (let i = 0; i < valid.length; i += BATCH) {
        const chunk = valid.slice(i, i + BATCH).map(row => ({
          id: row.id,
          deptCode: String(row.deptCode || ''),
          deptName: row.deptName || null,
          year: String(row.year),
          agentCode: row.agentCode || null,
          agentName: row.agentName || null,
          customerCount: Number(row.customerCount) || 0,
          callCount: Number(row.callCount) || 0,
          revenue: Number(row.revenue) || 0,
          syncedAt: new Date(),
        }));
        await db.insert(departmentStats)
          .values(chunk)
          .onConflictDoUpdate({
            target: departmentStats.id,
            set: {
              deptName: sql`excluded.dept_name`,
              customerCount: sql`excluded.customer_count`,
              callCount: sql`excluded.call_count`,
              revenue: sql`excluded.revenue`,
              syncedAt: sql`excluded.synced_at`,
            }
          });
        imported += chunk.length;
      }
      console.log(`[DEPT] Synced ${imported} department stat rows`);
      res.json({ success: true, imported });
    } catch (error: any) {
      console.error('[DEPT] Sync error:', error.message);
      res.status(500).json({ error: error.message });
    }
  });

  // Department stats retrieval
  app.get("/api/departments/stats", async (_req, res) => {
    try {
      const rows = await db.select().from(departmentStats);
      res.json(rows);
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  });

  // Calibrator dept stats sync (grouped by ORDERS.DOER — who performed the work)
  app.post("/api/sync/calibrator-dept-stats", async (req, res) => {
    try {
      const { stats } = req.body;
      if (!Array.isArray(stats)) return res.status(400).json({ error: 'stats array required' });
      const valid = stats.filter(r => r.id && r.doerId);
      if (valid.length === 0) return res.json({ success: true, imported: 0 });

      const BATCH = 200;
      let imported = 0;
      for (let i = 0; i < valid.length; i += BATCH) {
        const chunk = valid.slice(i, i + BATCH).map(row => ({
          id: row.id,
          doerId: String(row.doerId),
          deptCode: String(row.deptCode || ''),
          deptName: row.deptName || null,
          year: String(row.year),
          customerCount: Number(row.customerCount) || 0,
          callCount: Number(row.callCount) || 0,
          revenue: Number(row.revenue) || 0,
          syncedAt: new Date(),
        }));
        await db.insert(calibratorDeptStats)
          .values(chunk)
          .onConflictDoUpdate({
            target: calibratorDeptStats.id,
            set: {
              deptName: sql`excluded.dept_name`,
              customerCount: sql`excluded.customer_count`,
              callCount: sql`excluded.call_count`,
              revenue: sql`excluded.revenue`,
              syncedAt: sql`excluded.synced_at`,
            }
          });
        imported += chunk.length;
      }
      console.log(`[CALIB-DEPT] Synced ${imported} calibrator dept stat rows`);
      res.json({ success: true, imported });
    } catch (error: any) {
      console.error('[CALIB-DEPT] Sync error:', error.message);
      res.status(500).json({ error: error.message });
    }
  });

  // Calibrator dept stats retrieval
  app.get("/api/departments/calibrator-stats", async (_req, res) => {
    try {
      const rows = await db.select().from(calibratorDeptStats);
      res.json(rows);
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  });

  // Migration status and manual trigger
  app.get("/api/sync/migration-status", (_req, res) => {
    res.json({
      ...migrationStatus,
      productionUrl: PRODUCTION_URL,
      autoMigrateDelayMinutes: AUTO_MIGRATE_DELAY_MS / 60000,
      timerActive: autoMigrateTimer !== null,
    });
  });

  app.post("/api/sync/migrate-now", async (_req, res) => {
    if (migrationStatus.isRunning) {
      return res.json({ success: false, message: 'Migration already running' });
    }
    runMigrationToProduction(); // run in background
    res.json({ success: true, message: 'Migration started' });
  });

  // API to receive customer data from local Python script
  app.post("/api/sync/customer-data", async (req, res) => {
    try {
      const customerData = req.body;
      
      if (!customerData.id) {
        return res.status(400).json({ error: 'Customer ID is required' });
      }
      
      await withSyncConcurrency(async () => {
        // Upsert to database
        await db.insert(syncedCustomers)
          .values({
            id: customerData.id,
            hp: customerData.hp || customerData.id,
            companyName: customerData.companyName,
            data: customerData,
            syncedAt: new Date()
          })
          .onConflictDoUpdate({
            target: syncedCustomers.id,
            set: {
              hp: customerData.hp || customerData.id,
              companyName: customerData.companyName,
              data: customerData,
              syncedAt: new Date()
            }
          });
        
        // Update sync status
        syncStatus.lastSyncTime = new Date();
        
        // Track current session - reset if more than 5 minutes since last sync
        const now = new Date();
        if (!syncStatus.syncSessionStart || 
            (now.getTime() - syncStatus.syncSessionStart.getTime()) > 5 * 60 * 1000) {
          syncStatus.syncSessionStart = now;
          syncStatus.currentSessionSynced = 0;
        }
        syncStatus.currentSessionSynced++;
        
        // Increment count without querying full table
        syncStatus.totalSynced = Math.max(syncStatus.totalSynced, syncStatus.currentSessionSynced);
        
        syncStatus.recentlySynced.unshift({
          id: customerData.id,
          name: customerData.companyName,
          time: new Date()
        });
        if (syncStatus.recentlySynced.length > 10) {
          syncStatus.recentlySynced = syncStatus.recentlySynced.slice(0, 10);
        }
      });
      
      // Schedule auto-migration to production (resets timer on each sync)
      scheduleAutoMigration();
      // Refresh list cache in background (debounced via cacheBuilding flag)
      buildCustomerListCache().catch(() => {});

      console.log(`✓ Customer data synced: ${customerData.companyName} (${customerData.id})`)
      
      res.json({ 
        success: true, 
        message: 'Customer data synced successfully',
        customerId: customerData.id
      });
    } catch (error: any) {
      console.error('Error syncing customer data:', error);
      res.status(500).json({ 
        error: 'Failed to sync customer data',
        message: error.message 
      });
    }
  });
  
  // Lightweight customer list — served from pre-serialized + pre-compressed in-memory cache
  app.get("/api/customers/list", async (req, res) => {
    // If cache isn't ready yet, wait for the build that's already in progress (up to 30s)
    if (!customerListCacheJson) {
      if (cacheReadyPromise) {
        await Promise.race([
          cacheReadyPromise,
          new Promise(r => setTimeout(r, 30000)),
        ]);
      }
    }
    // If still not ready after waiting, try one synchronous build
    if (!customerListCacheJson) {
      await buildCustomerListCache();
    }
    if (!customerListCacheJson) {
      return res.status(503).json({ error: 'Customer list cache not ready. Please try again in a moment.' });
    }
    const acceptsGzip = (req.headers['accept-encoding'] || '').includes('gzip');
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    if (acceptsGzip && customerListCacheGzip) {
      res.setHeader('Content-Encoding', 'gzip');
      res.setHeader('Content-Length', customerListCacheGzip.length);
      return res.end(customerListCacheGzip);
    }
    return res.send(customerListCacheJson);
  });

  // API to get customer data
  app.get("/api/customers/:customerId", async (req, res) => {
    try {
      const { customerId } = req.params;
      
      // Try to get from database
      const [customer] = await db.select()
        .from(syncedCustomers)
        .where(eq(syncedCustomers.id, customerId));
      
      if (!customer) {
        // Also try by HP
        const [customerByHp] = await db.select()
          .from(syncedCustomers)
          .where(eq(syncedCustomers.hp, customerId));
        
        if (!customerByHp) {
          return res.status(404).json({ 
            error: 'Customer not found',
            message: 'Please sync customer data using the local Python script first'
          });
        }
        
        return res.json(customerByHp.data);
      }
      
      res.json(customer.data);
    } catch (error: any) {
      console.error('Error fetching customer data:', error);
      res.status(500).json({ 
        error: 'Failed to fetch customer data',
        message: error.message 
      });
    }
  });

  app.get("/api/agents", async (req, res) => {
    try {
      // Use the in-memory cache if available (built from /api/customers/list)
      if (customerListCache?.customers?.length) {
        const agentSet = new Set<string>();
        for (const c of customerListCache.customers) {
          const name = (c as any).agentName;
          if (name && name.trim()) agentSet.add(name);
        }
        return res.json({ agents: Array.from(agentSet).sort() });
      }
      // Fallback: fast SQL query extracting only agentName
      const result = await db.execute(sql`
        SELECT DISTINCT data->>'agentName' AS agent_name
        FROM synced_customers
        WHERE data->>'agentName' IS NOT NULL AND data->>'agentName' != ''
        ORDER BY 1
      `);
      const agents = (result.rows as any[]).map(r => r.agent_name).filter(Boolean);
      res.json({ agents });
    } catch (error: any) {
      console.error('Error fetching agents:', error);
      res.status(500).json({ error: 'Failed to fetch agents' });
    }
  });

  // API to get yearly financials aggregated per agent (fast SQL-side aggregation)
  app.get("/api/agents/yearly-financials", async (req, res) => {
    try {
      const { sql } = await import('drizzle-orm');
      const result = await db.execute(sql`
        SELECT
          data->>'agentName' as agent_name,
          (fin->>'year')::int as year,
          SUM((fin->>'revenue')::numeric) as revenue,
          SUM((fin->>'invoicesCount')::int) as invoices_count,
          SUM((fin->>'ordersCount')::int) as orders_count,
          SUM((fin->>'quotesCount')::int) as quotes_count,
          SUM((fin->>'ordersRevenue')::numeric) as orders_revenue,
          SUM((fin->>'quotesRevenue')::numeric) as quotes_revenue,
          SUM((fin->>'returnsRevenue')::numeric) as returns_revenue,
          SUM((fin->>'returnsCount')::int) as returns_count
        FROM synced_customers c,
          jsonb_array_elements(c.data->'financials') fin
        WHERE data->>'agentName' IS NOT NULL
          AND data->>'agentName' != ''
          AND (fin->>'year')::int IN (2023, 2024, 2025, 2026)
        GROUP BY data->>'agentName', (fin->>'year')::int
        ORDER BY agent_name, year
      `);

      // Group by agent
      const byAgent: Record<string, any[]> = {};
      for (const row of result.rows as any[]) {
        const agent = row.agent_name;
        if (!byAgent[agent]) byAgent[agent] = [];
        byAgent[agent].push({
          year: row.year,
          revenue: Number(row.revenue) || 0,
          invoicesCount: Number(row.invoices_count) || 0,
          ordersCount: Number(row.orders_count) || 0,
          quotesCount: Number(row.quotes_count) || 0,
          ordersRevenue: Number(row.orders_revenue) || 0,
          quotesRevenue: Number(row.quotes_revenue) || 0,
          returnsRevenue: Number(row.returns_revenue) || 0,
          returnsCount: Number(row.returns_count) || 0,
        });
      }

      res.json({ agentFinancials: byAgent });
    } catch (error: any) {
      console.error('Error fetching agent yearly financials:', error);
      res.status(500).json({ error: 'Failed to fetch agent financials' });
    }
  });

  // API to get monthly revenue breakdown per agent for a specific year
  app.get("/api/agents/monthly-revenue", async (req, res) => {
    try {
      const { sql } = await import('drizzle-orm');
      const year = parseInt(req.query.year as string) || new Date().getFullYear();

      const result = await db.execute(sql`
        SELECT
          data->>'agentName' as agent_name,
          (elem->>'month') as month,
          SUM((elem->>'revenue')::numeric) as revenue,
          SUM((elem->>'count')::int) as count
        FROM synced_customers c,
          jsonb_array_elements(c.data->'monthlyRevenue') elem
        WHERE data->>'agentName' IS NOT NULL
          AND data->>'agentName' != ''
          AND (elem->>'month') LIKE ${year + '-%'}
        GROUP BY data->>'agentName', (elem->>'month')
        ORDER BY agent_name, month
      `);

      // Group by agent → array of { month, revenue, count }
      const byAgent: Record<string, { month: string; revenue: number; count: number }[]> = {};
      for (const row of result.rows as any[]) {
        const agent = row.agent_name;
        if (!byAgent[agent]) byAgent[agent] = [];
        byAgent[agent].push({
          month: row.month,
          revenue: Number(row.revenue) || 0,
          count: Number(row.count) || 0,
        });
      }

      // Also compute company-wide monthly totals
      const companyResult = await db.execute(sql`
        SELECT
          (elem->>'month') as month,
          SUM((elem->>'revenue')::numeric) as revenue,
          SUM((elem->>'count')::int) as count
        FROM synced_customers c,
          jsonb_array_elements(c.data->'monthlyRevenue') elem
        WHERE (elem->>'month') LIKE ${year + '-%'}
        GROUP BY (elem->>'month')
        ORDER BY month
      `);

      const companyMonthly = (companyResult.rows as any[]).map(row => ({
        month: row.month,
        revenue: Number(row.revenue) || 0,
        count: Number(row.count) || 0,
      }));

      res.json({ year, agentMonthly: byAgent, companyMonthly });
    } catch (error: any) {
      console.error('Error fetching agent monthly revenue:', error);
      res.status(500).json({ error: 'Failed to fetch agent monthly revenue' });
    }
  });

  // Monthly returns (תעודות החזרה) per agent — for company-targets actual revenue
  app.get("/api/agents/monthly-returns", async (req, res) => {
    try {
      const { sql } = await import('drizzle-orm');
      const year = parseInt(req.query.year as string) || new Date().getFullYear();

      // Company-wide: from company_return_documents table (month is YYYY-MM)
      const companyResult = await db.execute(sql`
        SELECT month, SUM(value) as revenue, COUNT(*) as count
        FROM company_return_documents
        WHERE month LIKE ${year + '-%'}
        GROUP BY month
        ORDER BY month
      `);
      const companyMonthly = (companyResult.rows as any[]).map(row => ({
        month: row.month as string,
        revenue: Number(row.revenue) || 0,
        count: Number(row.count) || 0,
      }));

      // Per-agent: same source as companyMonthly above (company_return_documents),
      // joined to the customer→agent map. Previously this expanded the
      // returnDocuments JSONB of every customer: 3.2s, and it disagreed with the
      // company total on the same screen (7,604 docs / ₪20.9M vs 7,904 / ₪21.9M)
      // because the two came from different sources.
      // AS MATERIALIZED matters — without it the planner re-reads the 47MB JSONB
      // column per join probe and the query goes back to ~3.2s.
      const agentResult = await db.execute(sql`
        WITH agent AS MATERIALIZED (
          SELECT id, data->>'agentName' AS agent_name FROM synced_customers
        )
        SELECT a.agent_name, d.month,
               SUM(d.value)::numeric AS revenue,
               COUNT(*)::int         AS count
        FROM company_return_documents d
        JOIN agent a ON a.id = d.customer_id
        WHERE d.month LIKE ${year + '-%'}
          AND COALESCE(a.agent_name, '') <> ''
        GROUP BY 1, 2
        ORDER BY 1, 2
      `);

      const byAgent: Record<string, { month: string; revenue: number; count: number }[]> = {};
      for (const row of agentResult.rows as any[]) {
        const agent = row.agent_name;
        if (!agent || !row.month) continue;
        if (!byAgent[agent]) byAgent[agent] = [];
        byAgent[agent].push({
          month: row.month,
          revenue: Number(row.revenue) || 0,
          count: Number(row.count) || 0,
        });
      }

      res.json({ year, agentMonthly: byAgent, companyMonthly });
    } catch (error: any) {
      console.error('Error fetching agent monthly returns:', error);
      res.status(500).json({ error: 'Failed to fetch agent monthly returns' });
    }
  });

  app.get("/api/customers", async (req, res) => {
    try {
      const allCustomers = await db.select().from(syncedCustomers);
      
      // Aggregate yearly financials across all customers
      const yearlyAggregates: Record<number, {
        revenue: number;
        invoicesCount: number;
        quotesCount: number;
        quotesRevenue: number;
        ordersCount: number;
        ordersRevenue: number;
        returnsRevenue: number;
        returnsCount: number;
      }> = {};
      
      [2024, 2025, 2026].forEach(year => {
        yearlyAggregates[year] = {
          revenue: 0,
          invoicesCount: 0,
          quotesCount: 0,
          quotesRevenue: 0,
          ordersCount: 0,
          ordersRevenue: 0,
          returnsRevenue: 0,
          returnsCount: 0
        };
      });
      
      const customers = allCustomers.map(c => {
        const data = c.data as any;
        
        // Aggregate financials for company summary
        if (data.financials && Array.isArray(data.financials)) {
          data.financials.forEach((f: any) => {
            const year = f.year;
            if (yearlyAggregates[year]) {
              yearlyAggregates[year].revenue += Number(f.revenue) || 0;
              yearlyAggregates[year].invoicesCount += f.invoicesCount || 0;
              yearlyAggregates[year].quotesCount += f.quotesCount || 0;
              yearlyAggregates[year].quotesRevenue += Number(f.quotesRevenue) || 0;
              yearlyAggregates[year].ordersCount += f.ordersCount || 0;
              yearlyAggregates[year].ordersRevenue += Number(f.ordersRevenue) || 0;
              yearlyAggregates[year].returnsRevenue += Number(f.returnsRevenue) || 0;
              yearlyAggregates[year].returnsCount += f.returnsCount || 0;
            }
          });
        }
        
        // Calculate total revenue (sum of all years)
        let totalRevenue = 0;
        if (data.financials && Array.isArray(data.financials)) {
          totalRevenue = data.financials.reduce((sum: number, f: any) => sum + (Number(f.revenue) || 0), 0);
        }
        
        return {
          id: data.id || data.hp,
          hp: data.hp,
          companyName: data.companyName,
          agentName: data.agentName || '',
          totalRevenue,
          deviceInventory: data.deviceInventory || { totalDevices: 0, activeDevices: 0, outForCalibration: 0 },
          customerScore: data.customerScore || null,
          alerts: data.alerts || [],
          pendingForecast: data.pendingForecast || { totalDocuments: 0, totalValue: 0 },
          monthlyRevenue: data.monthlyRevenue || [],
          financials: data.financials || [],
          returnDocuments: data.returnDocuments || [],
          invoices: data.invoices || []
        };
      });
      
      // Convert to array format
      const yearlyFinancials = Object.entries(yearlyAggregates).map(([year, data]) => ({
        year: parseInt(year),
        ...data
      }));
      
      res.json({ customers, count: customers.length, yearlyFinancials });
    } catch (error: any) {
      console.error('Error listing customers:', error);
      res.status(500).json({ 
        error: 'Failed to list customers',
        message: error.message 
      });
    }
  });

  // API to get sync status
  app.get("/api/sync/status", async (req, res) => {
    res.json({
      lastSyncTime: syncStatus.lastSyncTime,
      totalSynced: syncStatus.totalSynced,
      currentSessionSynced: syncStatus.currentSessionSynced,
      syncSessionStart: syncStatus.syncSessionStart,
      recentlySynced: syncStatus.recentlySynced.slice(0, 5)
    });
  });

  // Helper: verify optional sync-secret header/body field
  function checkSyncSecret(req: any, res: any): boolean {
    const secret = process.env.SYNC_SECRET;
    if (!secret) return true; // not configured — open in dev
    const provided = req.headers['x-sync-secret'] || req.body?.syncSecret;
    if (provided !== secret) {
      res.status(401).json({ error: 'Unauthorized: invalid sync secret' });
      return false;
    }
    return true;
  }

  // Sync endpoint: company-wide return documents (truncate + insert)
  app.post("/api/sync/company-return-documents", async (req, res) => {
    if (!checkSyncSecret(req, res)) return;
    try {
      const { documents } = req.body;
      if (!Array.isArray(documents)) return res.status(400).json({ error: 'documents array required' });
      await db.delete(companyReturnDocuments);
      if (documents.length > 0) {
        const BATCH = 500;
        for (let i = 0; i < documents.length; i += BATCH) {
          const chunk = documents.slice(i, i + BATCH).map((d: any) => ({
            docNumber: String(d.docNumber || ''),
            customerName: d.customerName || null,
            customerId: d.customerId ? String(d.customerId) : null,
            openDate: d.openDate || null,
            value: Number(d.value) || 0,
            status: d.status || null,
            month: d.month || null,
            syncedAt: new Date(),
          }));
          await db.insert(companyReturnDocuments).values(chunk);
        }
      }
      console.log(`[COMPANY-RETURNS] Synced ${documents.length} return documents`);
      res.json({ success: true, saved: documents.length });
    } catch (error: any) {
      console.error('[COMPANY-RETURNS] Sync error:', error.message);
      res.status(500).json({ error: error.message });
    }
  });

  // Sync endpoint: company-wide calibration alerts (batch insert with syncId)
  // Uses syncId to safely swap data: insert new batches tagged with syncId,
  // then delete old rows (different syncId) only after the last batch arrives.
  // This prevents data loss if two syncs overlap.
  app.post("/api/sync/company-calibration-alerts", async (req, res) => {
    if (!checkSyncSecret(req, res)) return;
    try {
      const { alerts, syncId, isLast } = req.body;
      if (!Array.isArray(alerts)) return res.status(400).json({ error: 'alerts array required' });
      if (!syncId) return res.status(400).json({ error: 'syncId required' });
      if (alerts.length > 0) {
        const BATCH = 500;
        for (let i = 0; i < alerts.length; i += BATCH) {
          const chunk = alerts.slice(i, i + BATCH).map((a: any) => ({
            customerId: a.customerId ? String(a.customerId) : null,
            customerName: a.customerName || null,
            serialNo: a.serialNo || null,
            deviceName: a.deviceName || null,
            nextCalDate: a.nextCalDate || null,
            lastCalDate: a.lastCalDate || null,
            type: a.type || 'warning',
            location: a.location || 'internal',
            syncId: syncId,
            syncedAt: new Date(),
          }));
          await db.insert(companyCalibrationAlerts).values(chunk);
        }
      }
      if (isLast === true) {
        // All batches received — delete rows from previous syncs
        await db.delete(companyCalibrationAlerts).where(
          sql`sync_id != ${syncId} OR sync_id IS NULL`
        );
        console.log(`[COMPANY-CAL-ALERTS] Committed syncId=${syncId}, removed old rows`);
      }
      console.log(`[COMPANY-CAL-ALERTS] Synced ${alerts.length} calibration alerts (syncId=${syncId}, isLast=${isLast})`);
      res.json({ success: true, saved: alerts.length });
    } catch (error: any) {
      console.error('[COMPANY-CAL-ALERTS] Sync error:', error.message);
      res.status(500).json({ error: error.message });
    }
  });

  // API to get all returns across all customers for company summary
  // Reads from the company_return_documents table (synced globally)
  app.get("/api/company/returns", async (req, res) => {
    try {
      const now = new Date();
      const hebrewMonths = ['ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
                            'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר'];

      // Build last 3 months
      const monthsToFetch = [];
      for (let i = 0; i < 3; i++) {
        const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
        const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
        const name = hebrewMonths[d.getMonth()] + ' ' + d.getFullYear();
        monthsToFetch.push({ key, name, idx: i });
      }

      const allResults = await Promise.all(
        monthsToFetch.map(m => db.select().from(companyReturnDocuments).where(eq(companyReturnDocuments.month, m.key)))
      );

      const toDoc = (r: any) => ({
        customerName: r.customerName || '',
        customerHp: r.customerId || '',
        customerId: r.customerId || '',
        docNumber: r.docNumber || '',
        openDate: r.openDate || '',
        totalPrice: Number(r.value) || 0,
        month: r.month || '',
      });

      const months = monthsToFetch.map((m, idx) => {
        const docs = allResults[idx].map(toDoc).sort((a, b) => b.totalPrice - a.totalPrice);
        return {
          name: m.name,
          key: m.key,
          documents: docs,
          totalCount: docs.length,
          totalRevenue: docs.reduce((sum: number, r: any) => sum + r.totalPrice, 0),
        };
      });

      // Keep backward-compatible fields
      const currentMonth = monthsToFetch[0];
      const prevMonth = monthsToFetch[1];
      const currentDocs = months[0].documents;
      const prevDocs = months[1].documents;

      res.json({
        months,
        currentMonth: {
          name: currentMonth.name,
          key: currentMonth.key,
          documents: currentDocs,
          totalCount: currentDocs.length,
          totalRevenue: currentDocs.reduce((sum: number, r: any) => sum + r.totalPrice, 0),
        },
        previousMonth: {
          name: prevMonth.name,
          key: prevMonth.key,
          documents: prevDocs,
          totalCount: prevDocs.length,
          totalRevenue: prevDocs.reduce((sum: number, r: any) => sum + r.totalPrice, 0),
        },
      });
    } catch (error: any) {
      console.error('Error fetching company returns:', error);
      res.status(500).json({ error: 'Failed to fetch company returns', message: error.message });
    }
  });

  // API to receive database schema from local script
  let latestSchema: any = null;
  
  app.post("/api/schema/upload", (req, res) => {
    try {
      latestSchema = req.body;
      console.log(`\n${'='.repeat(60)}`);
      console.log('📊 DATABASE SCHEMA RECEIVED');
      console.log(`${'='.repeat(60)}`);
      console.log(`Database: ${latestSchema.database}`);
      console.log(`Server: ${latestSchema.server}`);
      console.log(`Tables: ${latestSchema.tables?.length || 0}`);
      console.log(`Timestamp: ${latestSchema.timestamp}`);
      console.log(`${'='.repeat(60)}\n`);
      
      if (latestSchema.tables) {
        latestSchema.tables.forEach((table: any) => {
          console.log(`\n📋 [${table.schema}].[${table.name}] - ${table.columns?.length || 0} columns`);
          if (table.columns) {
            table.columns.forEach((col: any) => {
              console.log(`   - ${col.name} (${col.type}${col.maxLength ? `, ${col.maxLength}` : ''})`);
            });
          }
        });
      }
      
      res.json({ success: true, message: 'Schema received', tablesCount: latestSchema.tables?.length });
    } catch (error: any) {
      console.error('Error receiving schema:', error);
      res.status(500).json({ error: 'Failed to receive schema', message: error.message });
    }
  });
  
  app.get("/api/schema/latest", (req, res) => {
    if (!latestSchema) {
      return res.status(404).json({ error: 'No schema uploaded yet' });
    }
    res.json(latestSchema);
  });

  // API to count devices calibrated in a given year (lastCalDate format: dd/mm/yyyy)
  app.get("/api/summary/calibrated-devices", async (req, res) => {
    try {
      const year = parseInt(req.query.year as string) || new Date().getFullYear();
      const result = await db.execute(sql`
        SELECT COUNT(*)::int AS count
        FROM synced_customers,
             jsonb_array_elements(
               CASE jsonb_typeof(data->'devicesList')
                 WHEN 'array' THEN data->'devicesList'
                 ELSE '[]'::jsonb
               END
             ) AS device
        WHERE device->>'lastCalDate' LIKE ${`%/${year}`}
      `);
      const count = (result.rows[0] as any)?.count || 0;
      res.json({ year, count });
    } catch (err: any) {
      res.status(500).json({ error: err.message });
    }
  });

  // API to count return documents (תעודות החזרה) by year
  app.get("/api/summary/returns-by-year", async (req, res) => {
    try {
      const year = parseInt(req.query.year as string) || new Date().getFullYear();
      const yearStr = String(year);
      const result = await db.execute(sql`
        SELECT COUNT(*)::int AS count,
               COALESCE(SUM((doc->>'value')::numeric), 0)::numeric AS total_value,
               COALESCE(SUM(COALESCE((doc->>'linesCount')::int, 1)), 0)::int AS total_lines
        FROM synced_customers,
             jsonb_array_elements(
               CASE jsonb_typeof(data->'returnDocuments')
                 WHEN 'array' THEN data->'returnDocuments'
                 ELSE '[]'::jsonb
               END
             ) AS doc
        WHERE split_part(doc->>'openDate', '/', 3) = ${yearStr}
          AND (doc->>'status') NOT IN ('מבוטלת', 'טיוטא')
      `);
      const row = result.rows[0] as any;
      res.json({ year, count: row?.count || 0, totalValue: parseFloat(row?.total_value || '0'), totalLines: parseInt(row?.total_lines || '0') });
    } catch (err: any) {
      res.status(500).json({ error: err.message });
    }
  });

  // API to find customers with similar company name (for "no data" duplicate detection)
  app.get("/api/customers/:customerId/similar", async (req, res) => {
    try {
      const { customerId } = req.params;
      // Get the current customer's company name
      const [customer] = await db.select().from(syncedCustomers).where(eq(syncedCustomers.id, customerId));
      if (!customer) return res.json({ similar: [] });

      const companyName: string = (customer.data as any)?.companyName || customer.companyName || '';
      if (!companyName) return res.json({ similar: [] });

      // Extract key words from the company name (≥3 chars, skip common words)
      const stopWords = new Set(['בעמ', 'בע"מ', "בע'מ", 'בעמ', 'מפעל', 'בע', 'מ', 'של']);
      const words = companyName
        .replace(/["""''()]/g, ' ')
        .split(/[\s\-–]+/)
        .map((w: string) => w.trim())
        .filter((w: string) => w.length >= 3 && !stopWords.has(w));

      if (words.length === 0) return res.json({ similar: [] });

      // Search for customers with at least one matching keyword, that have actual data
      const result = await db.execute(sql`
        SELECT 
          id,
          hp,
          company_name,
          jsonb_array_length(COALESCE(data->'devicesList','[]')) AS devices,
          jsonb_array_length(COALESCE(data->'ordersDetail','[]')) AS orders
        FROM synced_customers
        WHERE id != ${customerId}
          AND (
            ${sql.raw(words.map((w: string) => `company_name ILIKE '%${w.replace(/'/g, "''")}%'`).join(' OR '))}
          )
          AND (
            jsonb_array_length(COALESCE(data->'devicesList','[]')) > 0
            OR jsonb_array_length(COALESCE(data->'ordersDetail','[]')) > 0
          )
        ORDER BY devices DESC, orders DESC
        LIMIT 5
      `);

      res.json({ similar: result.rows });
    } catch (error: any) {
      console.error('Error finding similar customers:', error);
      res.json({ similar: [] });
    }
  });

  // API to get alerts summary across all customers
  app.get("/api/alerts/summary", async (req, res) => {
    try {
      const allCustomers = await db.select().from(syncedCustomers);
      
      const companiesWithAlerts: { 
        id: string; 
        companyName: string; 
        expiredDevices: number;
        totalOrders: number;
        totalRevenue: number;
        monthlyNetRevenue: number;
      }[] = [];
      
      let totalExpiredDevices = 0;
      let totalDevices = 0;
      let totalMonthlyNetRevenue = 0;
      
      const now = new Date();
      const currentYear = now.getFullYear();
      const currentMonth = now.getMonth() + 1; // 1-based month
      
      allCustomers.forEach(customer => {
        const data = customer.data as any;
        const deviceInventory = data.deviceInventory || {};
        const expired = deviceInventory.outForCalibration || 0;
        const total = deviceInventory.totalDevices || 0;
        
        totalExpiredDevices += expired;
        totalDevices += total;
        
        // Calculate revenue from I-prefix invoices for current year (using netPrice = TOTPRICE - VAT)
        const invoices = data.invoices || [];
        const iInvoices = invoices.filter((inv: any) => 
          (inv.invoiceNumber || '').startsWith('I') && inv.year === currentYear
        );
        const totalRevenue = iInvoices.reduce((sum: number, inv: any) => sum + (inv.netPrice || 0), 0);
        
        // Calculate current month net revenue (TOTPRICE - VAT = netPrice)
        const currentMonthInvoices = iInvoices.filter((inv: any) => inv.month === currentMonth);
        const monthlyNetRevenue = currentMonthInvoices.reduce((sum: number, inv: any) => sum + (inv.netPrice || 0), 0);
        totalMonthlyNetRevenue += monthlyNetRevenue;
        
        // Calculate orders from ordersDetail for current year only
        const ordersDetail = data.ordersDetail || [];
        const currentYearOrders = ordersDetail.filter((o: any) => o.year === currentYear);
        const totalOrders = currentYearOrders.length;
        
        companiesWithAlerts.push({
          id: data.id || customer.id,
          companyName: data.companyName || customer.companyName,
          expiredDevices: expired,
          totalOrders,
          totalRevenue,
          monthlyNetRevenue
        });
      });
      
      // Sort by revenue (top customers) - at least 10
      const topByRevenue = [...companiesWithAlerts]
        .filter(c => c.totalRevenue > 0)
        .sort((a, b) => b.totalRevenue - a.totalRevenue)
        .slice(0, 15);
      
      // Sort by orders count - at least 10
      const topByOrders = [...companiesWithAlerts]
        .filter(c => c.totalOrders > 0)
        .sort((a, b) => b.totalOrders - a.totalOrders)
        .slice(0, 15);
      
      // Sort by expired devices - top companies with most expired
      const topByExpiredDevices = [...companiesWithAlerts]
        .filter(c => c.expiredDevices > 0)
        .sort((a, b) => b.expiredDevices - a.expiredDevices)
        .slice(0, 15);
      
      // Sort by monthly net revenue - top customers this month
      const topByMonthlyRevenue = [...companiesWithAlerts]
        .filter(c => c.monthlyNetRevenue > 0)
        .sort((a, b) => b.monthlyNetRevenue - a.monthlyNetRevenue)
        .slice(0, 15);
      
      res.json({
        totalCustomers: allCustomers.length,
        totalExpiredDevices,
        totalDevices,
        customersWithActivity: companiesWithAlerts.filter(c => c.totalOrders > 0 || c.totalRevenue > 0).length,
        totalMonthlyNetRevenue,
        currentMonth,
        currentYear,
        topByRevenue,
        topByOrders,
        topByExpiredDevices,
        topByMonthlyRevenue
      });
    } catch (error: any) {
      console.error('Error fetching alerts summary:', error);
      res.status(500).json({ 
        error: 'Failed to fetch alerts',
        message: error.message 
      });
    }
  });

  // GET all company-wide calibration alerts (from global sync table)
  // next_cal_date/last_cal_date מאוחסנים כטקסט DD/MM/YYYY. הסידור מחדש ל-YYYYMM
  // הוא immutable (substr/||), ולכן ניתן להשוואה לקסיקוגרפית ישירות ב-SQL.
  const YYYYMM = sql`substr(next_cal_date,7,4) || substr(next_cal_date,4,2)`;
  const WELL_FORMED = sql`next_cal_date ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'`;

  /** חלון ההתראות: מספר חודשים אחורה/קדימה מתחילת החודש הנוכחי */
  function alertWindow(monthsBack: number, monthsAhead: number) {
    const now = new Date();
    const shift = (m: number) => {
      const d = new Date(now.getFullYear(), now.getMonth() + m, 1);
      return `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, '0')}`;
    };
    return { from: shift(-monthsBack), to: shift(monthsAhead) };
  }

  // התראות כיול — אגרגציה בלבד.
  // קודם לכן זה החזיר את כל 452,269 השורות (165MB) והדפדפן ספר אותן בעצמו;
  // זו הייתה הסיבה העיקרית לאיטיות של עמוד הסיכום.
  app.get("/api/company/calibration-alerts", async (req, res) => {
    try {
      const monthsBack  = Math.min(Math.max(Number(req.query.monthsBack)  || 36, 0), 240);
      const monthsAhead = Math.min(Math.max(Number(req.query.monthsAhead) || 12, 0), 240);
      const w = alertWindow(monthsBack, monthsAhead);

      const [byMonth, outside, grand] = await Promise.all([
        db.execute(sql`
          SELECT substr(next_cal_date,7,4) || '-' || substr(next_cal_date,4,2) AS month,
                 COALESCE(NULLIF(location,''), 'internal') AS location,
                 COALESCE(NULLIF(type,''), 'warning')      AS type,
                 COUNT(*)::int AS count
          FROM company_calibration_alerts
          WHERE ${WELL_FORMED} AND ${YYYYMM} BETWEEN ${w.from} AND ${w.to}
          GROUP BY 1, 2, 3
          ORDER BY 1
        `),
        db.execute(sql`
          SELECT
            COUNT(*) FILTER (WHERE NOT ${WELL_FORMED})                       ::int AS unparsable,
            COUNT(*) FILTER (WHERE ${WELL_FORMED} AND ${YYYYMM} < ${w.from}) ::int AS older,
            COUNT(*) FILTER (WHERE ${WELL_FORMED} AND ${YYYYMM} > ${w.to})   ::int AS ahead
          FROM company_calibration_alerts
        `),
        db.execute(sql`SELECT COUNT(*)::int AS total FROM company_calibration_alerts`),
      ]);

      res.json({
        window:        { from: w.from, to: w.to, monthsBack, monthsAhead },
        byMonth:       byMonth.rows,
        outsideWindow: outside.rows[0] ?? { unparsable: 0, older: 0, ahead: 0 },
        grandTotal:    Number((grand.rows[0] as any)?.total ?? 0),
      });
    } catch (error: any) {
      console.error('Error fetching company calibration alerts:', error);
      res.status(500).json({ error: 'Failed to fetch calibration alerts', message: error.message });
    }
  });

  // הלקוחות עם הכי הרבה התראות בחלון — מזין את תצוגת "לפי לקוח"
  app.get("/api/company/calibration-alerts/customers", async (req, res) => {
    try {
      const location    = String(req.query.location || 'all');
      const type        = String(req.query.type || 'all');
      const limit       = Math.min(Math.max(Number(req.query.limit) || 10, 1), 200);
      const monthsBack  = Math.min(Math.max(Number(req.query.monthsBack)  || 36, 0), 240);
      const monthsAhead = Math.min(Math.max(Number(req.query.monthsAhead) || 12, 0), 240);
      const w = alertWindow(monthsBack, monthsAhead);

      const conds = [WELL_FORMED, sql`${YYYYMM} BETWEEN ${w.from} AND ${w.to}`];
      if (location !== 'all') conds.push(sql`COALESCE(NULLIF(location,''),'internal') = ${location}`);
      if (type === 'overdue')  conds.push(sql`type = 'error'`);
      if (type === 'upcoming') conds.push(sql`type <> 'error'`);

      const result = await db.execute(sql`
        SELECT customer_id AS "id", MIN(customer_name) AS "companyName", COUNT(*)::int AS "count"
        FROM company_calibration_alerts
        WHERE ${sql.join(conds, sql` AND `)}
        GROUP BY customer_id
        ORDER BY COUNT(*) DESC
        LIMIT ${limit}
      `);
      res.json(result.rows);
    } catch (error: any) {
      console.error('Error fetching alert customers:', error);
      res.status(500).json({ error: 'Failed to fetch alert customers', message: error.message });
    }
  });

  // רשימת המכשירים של חודש בודד — נטענת רק כשפותחים את השורה בממשק
  app.get("/api/company/calibration-alerts/devices", async (req, res) => {
    try {
      const month    = String(req.query.month || '');            // YYYY-MM
      const location = String(req.query.location || 'all');
      const type     = String(req.query.type || 'all');
      const limit    = Math.min(Math.max(Number(req.query.limit) || 3000, 1), 10000);
      if (!/^\d{4}-\d{2}$/.test(month)) return res.status(400).json({ error: 'month must be YYYY-MM' });

      const key   = month.replace('-', '');
      const conds = [WELL_FORMED, sql`${YYYYMM} = ${key}`];
      if (location !== 'all') conds.push(sql`COALESCE(NULLIF(location,''),'internal') = ${location}`);
      if (type === 'overdue')  conds.push(sql`type = 'error'`);
      if (type === 'upcoming') conds.push(sql`type <> 'error'`);

      const [rows, count] = await Promise.all([
        db.execute(sql`
          SELECT customer_id AS "customerId", customer_name AS "customerName",
                 device_name AS "deviceName", serial_no AS "serialNo",
                 next_cal_date AS "nextCalDate", last_cal_date AS "lastCalDate",
                 COALESCE(NULLIF(type,''),'warning')      AS type,
                 COALESCE(NULLIF(location,''),'internal') AS location
          FROM company_calibration_alerts
          WHERE ${sql.join(conds, sql` AND `)}
          ORDER BY customer_name, device_name
          LIMIT ${limit}
        `),
        db.execute(sql`SELECT COUNT(*)::int AS n FROM company_calibration_alerts WHERE ${sql.join(conds, sql` AND `)}`),
      ]);

      const total = Number((count.rows[0] as any)?.n ?? 0);
      res.json({ month, rows: rows.rows, total, truncated: total > rows.rows.length });
    } catch (error: any) {
      console.error('Error fetching calibration alert devices:', error);
      res.status(500).json({ error: 'Failed to fetch devices', message: error.message });
    }
  });

  // POST /api/sync/global-sync — trigger a global sync request from the dashboard
  // Also used by the local script to report running/complete/error status
  app.post("/api/sync/global-sync", (req, res) => {
    const { status, error: errMsg } = req.body || {};
    if (status === 'running') {
      // Local script reporting it has started
      if (!checkSyncSecret(req, res)) return;
      globalSyncState = { ...globalSyncState, status: 'running', startedAt: new Date(), error: null };
      console.log('[GLOBAL-SYNC] Status: running');
      return res.json({ ok: true, state: globalSyncState });
    }
    if (status === 'complete') {
      // Local script reporting it finished successfully
      if (!checkSyncSecret(req, res)) return;
      globalSyncState = { ...globalSyncState, status: 'complete', completedAt: new Date(), error: null };
      console.log('[GLOBAL-SYNC] Status: complete');
      return res.json({ ok: true, state: globalSyncState });
    }
    if (status === 'error') {
      // Local script reporting it failed
      if (!checkSyncSecret(req, res)) return;
      globalSyncState = { ...globalSyncState, status: 'error', completedAt: new Date(), error: errMsg || 'unknown error' };
      console.log('[GLOBAL-SYNC] Status: error:', errMsg);
      return res.json({ ok: true, state: globalSyncState });
    }
    // Dashboard trigger — no sync secret required; just marks as requested
    globalSyncState = { status: 'requested', requestedAt: new Date(), startedAt: null, completedAt: null, error: null };
    console.log('[GLOBAL-SYNC] Sync requested from dashboard');
    res.json({ ok: true, state: globalSyncState, message: 'הסנכרון התבקש. הרץ: py sync-customer-data.py --global-sync' });
  });

  // GET last global sync timestamp (derived from latest syncedAt in global tables)
  app.get("/api/company/global-sync-status", async (_req, res) => {
    try {
      const calResult = await db.execute(sql`SELECT MAX(synced_at) AS ts FROM company_calibration_alerts`);
      const retResult = await db.execute(sql`SELECT MAX(synced_at) AS ts FROM company_return_documents`);
      const custResult = await db.execute(sql`SELECT MAX(synced_at) AS ts FROM synced_customers`);
      const calTs = (calResult.rows[0] as any)?.ts ? new Date((calResult.rows[0] as any).ts) : null;
      const retTs = (retResult.rows[0] as any)?.ts ? new Date((retResult.rows[0] as any).ts) : null;
      const custTs = (custResult.rows[0] as any)?.ts ? new Date((custResult.rows[0] as any).ts) : null;
      let lastSync: Date | null = null;
      const timestamps = [calTs, retTs, custTs].filter(Boolean) as Date[];
      if (timestamps.length > 0) {
        lastSync = timestamps.reduce((max, d) => d > max ? d : max, timestamps[0]);
      }
      res.json({
        lastSync: lastSync ? lastSync.toISOString() : null,
        syncState: globalSyncState,
      });
    } catch (error: any) {
      console.error('Error fetching global sync status:', error);
      res.status(500).json({ error: error.message });
    }
  });

  // Excel export endpoint
  app.get("/api/export/customers.xlsx", async (req, res) => {
    try {
      const allCustomers = await db.select().from(syncedCustomers);
      
      const workbook = new ExcelJS.Workbook();
      workbook.creator = 'QCC Analytics';
      workbook.created = new Date();
      
      // Sheet 1: Customer Summary with contacts
      const worksheet = workbook.addWorksheet('לקוחות', {
        views: [{ rightToLeft: true }]
      });
      
      // Headers
      worksheet.columns = [
        { header: 'מספר לקוח', key: 'id', width: 12 },
        { header: 'שם לקוח', key: 'companyName', width: 35 },
        { header: 'שם איש קשר', key: 'contactName', width: 25 },
        { header: 'טלפון', key: 'phone', width: 18 },
        { header: 'מייל', key: 'email', width: 30 },
        { header: 'שם סוכן', key: 'agentName', width: 20 },
        { header: 'הכנסות 2025 (נטו)', key: 'revenue2025', width: 18 },
        { header: 'חשבוניות 2025', key: 'invoices2025', width: 15 },
        { header: 'הזמנות 2025', key: 'orders2025', width: 15 },
        { header: 'מכשירים כוילו 2025', key: 'devicesCalibrated2025', width: 20 }
      ];
      
      // Style header row
      worksheet.getRow(1).font = { bold: true };
      worksheet.getRow(1).fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'FFE0E7FF' }
      };
      
      // Sheet 2: Contacts
      const contactsSheet = workbook.addWorksheet('אנשי קשר', {
        views: [{ rightToLeft: true }]
      });
      
      contactsSheet.columns = [
        { header: 'מספר לקוח', key: 'customerId', width: 12 },
        { header: 'שם לקוח', key: 'companyName', width: 35 },
        { header: 'שם איש קשר', key: 'contactName', width: 25 },
        { header: 'תפקיד', key: 'title', width: 20 },
        { header: 'טלפון', key: 'phone', width: 18 },
        { header: 'מייל', key: 'email', width: 35 }
      ];
      
      contactsSheet.getRow(1).font = { bold: true };
      contactsSheet.getRow(1).fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'FFE0E7FF' }
      };
      
      // Sheet 3: Devices calibrated in 2025
      const devicesSheet = workbook.addWorksheet('כלים שכוילו 2025', {
        views: [{ rightToLeft: true }]
      });
      
      devicesSheet.columns = [
        { header: 'מספר לקוח', key: 'customerId', width: 12 },
        { header: 'שם לקוח', key: 'companyName', width: 35 },
        { header: 'מספר סידורי', key: 'serialNo', width: 20 },
        { header: 'דגם', key: 'model', width: 25 },
        { header: 'יצרן', key: 'manufacturer', width: 20 },
        { header: 'תאריך כיול', key: 'calibrationDate', width: 15 },
        { header: 'כיול הבא', key: 'nextCalibration', width: 15 },
        { header: 'סטטוס', key: 'status', width: 15 }
      ];
      
      devicesSheet.getRow(1).font = { bold: true };
      devicesSheet.getRow(1).fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'FFE0E7FF' }
      };
      
      // Add data rows
      allCustomers.forEach(customer => {
        const data = customer.data as any;
        const invoices = data.invoices || [];
        const devices = data.devices || [];
        const contacts = data.contacts || [];
        const financials = data.financials || [];
        
        // Get 2025 financials
        const fin2025 = financials.find((f: any) => f.year === 2025) || {};
        
        // Calculate revenue using netPrice for 2025
        const get2025Revenue = invoices
          .filter((inv: any) => Number(inv.year) === 2025)
          .reduce((sum: number, inv: any) => sum + (Number(inv.netPrice) || 0), 0);
        
        // Get primary contact
        const primaryContact = contacts[0] || {};
        
        // Count devices calibrated in 2025
        const devices2025 = devices.filter((d: any) => {
          const calDate = d.calibrationDate || d.lastCalibration || '';
          return calDate.includes('2025') || calDate.includes('/25');
        });
        
        worksheet.addRow({
          id: data.id || customer.id,
          companyName: data.companyName || customer.companyName,
          contactName: primaryContact.name || primaryContact.contactName || '',
          phone: primaryContact.phone || primaryContact.cellPhone || '',
          email: primaryContact.email || '',
          agentName: data.agentName || '',
          revenue2025: Math.round(get2025Revenue || fin2025.revenue || 0),
          invoices2025: fin2025.invoicesCount || 0,
          orders2025: fin2025.ordersCount || 0,
          devicesCalibrated2025: devices2025.length
        });
        
        // Add all contacts to the contacts sheet
        contacts.forEach((contact: any) => {
          if (contact.name || contact.email || contact.phone) {
            contactsSheet.addRow({
              customerId: data.id || customer.id,
              companyName: data.companyName || customer.companyName,
              contactName: contact.name || '',
              title: contact.title || '',
              phone: contact.phone || contact.cellPhone || '',
              email: contact.email || ''
            });
          }
        });
        
        // Add devices to the devices sheet
        devices2025.forEach((device: any) => {
          devicesSheet.addRow({
            customerId: data.id || customer.id,
            companyName: data.companyName || customer.companyName,
            serialNo: device.serialNo || device.serialNumber || '',
            model: device.model || device.partName || '',
            manufacturer: device.manufacturer || '',
            calibrationDate: device.calibrationDate || device.lastCalibration || '',
            nextCalibration: device.nextCalibration || '',
            status: device.status || ''
          });
        });
      });
      
      // Format number columns
      worksheet.getColumn('revenue2025').numFmt = '₪#,##0';
      
      // Set response headers
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', 'attachment; filename="qcc-customers-2025.xlsx"');
      
      await workbook.xlsx.write(res);
      res.end();
      
    } catch (error: any) {
      console.error('Error exporting Excel:', error);
      res.status(500).json({ error: 'Failed to export Excel', message: error.message });
    }
  });

  // ========== Settings API ==========
  
  // Get scoring configuration
  app.get("/api/settings/scoring", async (req, res) => {
    try {
      const [setting] = await db.select()
        .from(appSettings)
        .where(eq(appSettings.key, 'scoring_config'));
      
      if (setting) {
        res.json(setting.value);
      } else {
        // Return default config if not set
        res.json(defaultScoringConfig);
      }
    } catch (error: any) {
      console.error('Error getting scoring config:', error);
      res.status(500).json({ error: 'Failed to get scoring config', message: error.message });
    }
  });
  
  // Update scoring configuration
  app.put("/api/settings/scoring", async (req, res) => {
    try {
      const config = req.body;
      
      // Validate weights sum to 100
      const weightsSum = (config.weights?.tenure || 0) + (config.weights?.revenue || 0) + (config.weights?.frequency || 0);
      if (weightsSum !== 100) {
        return res.status(400).json({ error: 'Weights must sum to 100' });
      }
      
      // Upsert config
      await db.insert(appSettings)
        .values({
          key: 'scoring_config',
          value: config,
          updatedAt: new Date()
        })
        .onConflictDoUpdate({
          target: appSettings.key,
          set: {
            value: config,
            updatedAt: new Date()
          }
        });
      
      res.json({ success: true, message: 'Scoring config updated' });
    } catch (error: any) {
      console.error('Error updating scoring config:', error);
      res.status(500).json({ error: 'Failed to update scoring config', message: error.message });
    }
  });

  // Get growth rate setting
  app.get("/api/settings/growth-rate", async (req, res) => {
    try {
      const [setting] = await db.select()
        .from(appSettings)
        .where(eq(appSettings.key, 'growth_rate'));
      if (setting) {
        res.json(setting.value);
      } else {
        res.json({ rate: 6 });
      }
    } catch (error: any) {
      console.error('Error getting growth rate:', error);
      res.status(500).json({ error: 'Failed to get growth rate', message: error.message });
    }
  });

  // Save growth rate setting
  app.put("/api/settings/growth-rate", async (req, res) => {
    try {
      const { rate, mode, dailyRate, monthlyDailyRates } = req.body;
      if (typeof rate !== 'number' || rate < 0 || rate > 100) {
        return res.status(400).json({ error: 'Invalid rate value' });
      }
      const value: any = { rate };
      if (mode) value.mode = mode;
      if (typeof dailyRate === 'number') value.dailyRate = dailyRate;
      if (monthlyDailyRates && Array.isArray(monthlyDailyRates) && monthlyDailyRates.length === 12) {
        value.monthlyDailyRates = monthlyDailyRates;
      }
      await db.insert(appSettings)
        .values({ key: 'growth_rate', value, updatedAt: new Date() })
        .onConflictDoUpdate({
          target: appSettings.key,
          set: { value, updatedAt: new Date() }
        });
      res.json({ success: true });
    } catch (error: any) {
      console.error('Error saving growth rate:', error);
      res.status(500).json({ error: 'Failed to save growth rate', message: error.message });
    }
  });

  // Company days off management
  app.get("/api/company/days-off", async (req, res) => {
    try {
      const year = req.query.year ? parseInt(req.query.year as string) : new Date().getFullYear();
      const allDaysOff = await db.select().from(companyDaysOff);
      
      // Filter by year
      const filteredDaysOff = allDaysOff.filter(d => {
        const dateYear = new Date(d.date).getFullYear();
        return dateYear === year;
      });
      
      res.json(filteredDaysOff);
    } catch (error: any) {
      console.error('Error fetching days off:', error);
      res.status(500).json({ error: 'Failed to fetch days off', message: error.message });
    }
  });

  app.post("/api/company/days-off", async (req, res) => {
    try {
      const parsed = insertCompanyDayOffSchema.parse(req.body);
      
      const [newDayOff] = await db.insert(companyDaysOff).values(parsed).returning();
      
      res.json(newDayOff);
    } catch (error: any) {
      console.error('Error adding day off:', error);
      res.status(500).json({ error: 'Failed to add day off', message: error.message });
    }
  });

  app.delete("/api/company/days-off/:id", async (req, res) => {
    try {
      const { id } = req.params;
      
      await db.delete(companyDaysOff).where(eq(companyDaysOff.id, id));
      
      res.json({ success: true });
    } catch (error: any) {
      console.error('Error deleting day off:', error);
      res.status(500).json({ error: 'Failed to delete day off', message: error.message });
    }
  });

  // ========== UPS Expenses Routes ==========
  
  // Sync UPS expense from local Python script
  app.post("/api/sync/ups-expenses", async (req, res) => {
    try {
      const expense = req.body;
      
      // Validate required fields
      if (!expense.iv || !expense.source) {
        return res.status(400).json({ error: 'IV and source are required' });
      }
      
      // Create unique ID from source + iv + ivnum + doc + amount (handles multiple line items)
      // This ensures each expense line is unique even if same invoice has multiple UPS items
      const amountStr = String(expense.amount || 0).replace('.', '_');
      const uniqueId = `${expense.source}_${expense.iv}_${expense.ivnum || 'none'}_${expense.doc || 'none'}_${amountStr}`;
      
      await db.insert(upsExpenses)
        .values({
          id: uniqueId,
          iv: expense.iv,
          ivnum: expense.ivnum,
          doc: expense.doc,
          ivdate: expense.ivdate,
          cust: expense.cust,
          customerName: expense.customerName,
          currency: expense.currency,
          amount: expense.amount ? parseFloat(expense.amount) : null,
          vatPrice: expense.vatPrice ? parseFloat(expense.vatPrice) : null,
          source: expense.source,
          part: expense.part,
          data: expense.data,
          syncedAt: new Date()
        })
        .onConflictDoUpdate({
          target: upsExpenses.id,
          set: {
            ivnum: expense.ivnum,
            doc: expense.doc,
            ivdate: expense.ivdate,
            cust: expense.cust,
            customerName: expense.customerName,
            currency: expense.currency,
            amount: expense.amount ? parseFloat(expense.amount) : null,
            vatPrice: expense.vatPrice ? parseFloat(expense.vatPrice) : null,
            data: expense.data,
            syncedAt: new Date()
          }
        });
      
      res.json({ success: true });
    } catch (error: any) {
      console.error('Error syncing UPS expense:', error);
      res.status(500).json({ error: 'Failed to sync expense', message: error.message });
    }
  });

  // Get UPS expenses with monthly aggregation
  app.get("/api/expenses/ups", async (req, res) => {
    try {
      const year = req.query.year ? parseInt(req.query.year as string) : new Date().getFullYear();
      
      const allExpenses = await db.select().from(upsExpenses);
      
      // Filter by year and aggregate by month
      const yearExpenses = allExpenses.filter(e => {
        if (!e.ivdate) return false;
        const parts = e.ivdate.split('/');
        if (parts.length !== 3) return false;
        return parseInt(parts[2]) === year;
      });
      
      // Group by month
      const monthlyTotals: { [key: string]: { month: number, total: number, count: number, shipping: number, supplier: number, shippingCount: number } } = {};
      
      for (let m = 1; m <= 12; m++) {
        monthlyTotals[m] = { month: m, total: 0, count: 0, shipping: 0, supplier: 0, shippingCount: 0 };
      }
      
      yearExpenses.forEach(e => {
        const parts = e.ivdate!.split('/');
        const month = parseInt(parts[1]);
        const amount = (e.amount || 0) / 1.17; // הסרת מע"מ 17%
        
        monthlyTotals[month].total += amount;
        monthlyTotals[month].count += 1;
        
        if (e.source === 'part_7720') {
          monthlyTotals[month].shipping += amount;
          monthlyTotals[month].shippingCount += 1;  // each part_7720 = one package shipped
        } else if (e.source === 'ups_supplier') {
          monthlyTotals[month].supplier += amount;
        }
      });
      
      const monthly = Object.values(monthlyTotals).sort((a, b) => a.month - b.month);
      const yearTotal = monthly.reduce((sum, m) => sum + m.total, 0);
      const yearCount = monthly.reduce((sum, m) => sum + m.count, 0);
      
      // Group customer shipping by customer
      const customerShipping: { [key: string]: { customerId: string, customerName: string, total: number, count: number } } = {};
      yearExpenses.filter(e => e.source === 'part_7720').forEach(e => {
        const custId = e.cust || 'unknown';
        if (!customerShipping[custId]) {
          customerShipping[custId] = { 
            customerId: custId, 
            customerName: e.customerName || 'לא ידוע', 
            total: 0, 
            count: 0 
          };
        }
        customerShipping[custId].total += (e.amount || 0) / 1.17; // הסרת מע"מ 17%
        customerShipping[custId].count += 1;
      });
      
      const customerShippingList = Object.values(customerShipping)
        .sort((a, b) => b.total - a.total);
      
      res.json({
        year,
        total: yearTotal,
        count: yearCount,
        monthly,
        expenses: yearExpenses,
        customerShipping: customerShippingList
      });
    } catch (error: any) {
      console.error('Error fetching UPS expenses:', error);
      res.status(500).json({ error: 'Failed to fetch expenses', message: error.message });
    }
  });

  // Daily UPS expenses from Priority ERP data
  app.get("/api/expenses/ups/daily", async (req, res) => {
    try {
      const year  = req.query.year  ? parseInt(req.query.year  as string) : new Date().getFullYear();
      const month = req.query.month ? parseInt(req.query.month as string) : null;

      const allExpenses = await db.select().from(upsExpenses);

      // Filter by year (and optional month) — date format DD/MM/YYYY
      const filtered = allExpenses.filter(e => {
        if (!e.ivdate) return false;
        const parts = e.ivdate.split('/');
        if (parts.length !== 3) return false;
        if (parseInt(parts[2]) !== year) return false;
        if (month !== null && parseInt(parts[1]) !== month) return false;
        return true;
      });

      // Group by date
      const byDate: {
        [k: string]: { date: string; isoDate: string; count: number; supplier: number; shipping: number; net: number }
      } = {};

      filtered.forEach(e => {
        const key = e.ivdate!; // DD/MM/YYYY
        const parts = e.ivdate!.split('/');
        const isoDate = `${parts[2]}-${parts[1].padStart(2,'0')}-${parts[0].padStart(2,'0')}`;
        if (!byDate[key]) byDate[key] = { date: key, isoDate, count: 0, supplier: 0, shipping: 0, net: 0 };
        byDate[key].count++;
        const amt = (e.amount || 0) / 1.17; // הסרת מע"מ 17%
        if (e.source === 'ups_supplier') {
          byDate[key].supplier += amt;
        } else if (e.source === 'part_7720') {
          byDate[key].shipping += amt;
        }
      });

      // Compute net and sort by isoDate
      const daily = Object.values(byDate)
        .map(d => ({ ...d, net: d.shipping - d.supplier }))
        .sort((a, b) => a.isoDate.localeCompare(b.isoDate));

      const maxDay = daily.length > 0 ? daily.reduce((mx, d) => d.supplier > mx.supplier ? d : mx) : null;
      const totalSupplier = daily.reduce((s, d) => s + d.supplier, 0);
      const totalShipping = daily.reduce((s, d) => s + d.shipping, 0);
      const avgDailyCost  = daily.length > 0 ? totalSupplier / daily.length : 0;

      res.json({
        year, month,
        totalDays: daily.length,
        totalRecords: filtered.length,
        totalSupplier,
        totalShipping,
        totalNet: totalShipping - totalSupplier,
        avgDailyCost: Math.round(avgDailyCost),
        maxDay,
        daily
      });
    } catch (error: any) {
      res.status(500).json({ error: 'Failed to fetch daily UPS expenses', message: error.message });
    }
  });

  // GET last sync timestamp for UPS expenses (MAX(synced_at))
  app.get("/api/expenses/ups/last-sync", async (_req, res) => {
    try {
      const result = await db.execute(sql`SELECT MAX(synced_at) AS ts FROM ups_expenses`);
      const ts = (result.rows[0] as any)?.ts;
      res.json({ lastSync: ts ? new Date(ts).toISOString() : null });
    } catch (error: any) {
      console.error('Error fetching UPS last sync:', error);
      res.status(500).json({ error: 'Failed to fetch UPS last sync', message: error.message });
    }
  });

  // ========== Ship API (UPS Shipments) Routes ==========

  app.post("/api/sync/ship-data", async (req, res) => {
    try {
      const { shipments, syncedAt, source, clearFirst } = req.body;
      
      if (!shipments || !Array.isArray(shipments)) {
        return res.status(400).json({ error: 'shipments array is required' });
      }

      if (clearFirst) {
        await db.delete(shipShipments);
        console.log('[ship-sync] Cleared existing shipments before re-sync');
      }
      
      let synced = 0;
      let errors = 0;
      
      for (const shipment of shipments) {
        try {
          // Support both camelCase and PascalCase field names (ship.co.il uses PascalCase)
          const trackNum = shipment.TrackNumber || shipment.trackingNumber || shipment.TrackingNumber || shipment.tracking_number;
          const id = trackNum || shipment.id || shipment.shipmentId || shipment.ShipmentId || `ship_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
          const rawDate = shipment.DateShipped || shipment.shipDate || shipment.ShipDate || shipment.ship_date || shipment.date;
          const parsedDate = rawDate ? new Date(rawDate) : null;
          const shipDate = parsedDate && !isNaN(parsedDate.getTime()) ? parsedDate.toISOString().split('T')[0] : null;

          await db.insert(shipShipments)
            .values({
              id: String(id),
              shipmentId: shipment.ShipmentId || shipment.shipmentId || shipment.shipment_id || null,
              trackingNumber: trackNum || null,
              shipDate: shipDate,
              customerRef: shipment.Reference1 || shipment.customerRef || shipment.CustomerRef || shipment.customer_ref || null,
              recipientName: shipment.ConsigneeName || shipment.recipientName || shipment.RecipientName || shipment.recipient_name || null,
              recipientCity: shipment.ConsigneeCity || shipment.recipientCity || shipment.RecipientCity || shipment.recipient_city || null,
              weight: shipment.weight || shipment.Weight ? parseFloat(String(shipment.weight || shipment.Weight)) : null,
              cost: shipment.cost || shipment.Cost || shipment.price || shipment.Price ? parseFloat(String(shipment.cost || shipment.Cost || shipment.price || shipment.Price)) : null,
              currency: shipment.currency || shipment.Currency || 'ILS',
              status: String(shipment.StatusDisplayName || shipment.status || shipment.Status || ''),
              serviceType: shipment.ServiceLevel != null ? String(shipment.ServiceLevel) : (shipment.serviceType || shipment.ServiceType || null),
              data: shipment,
              syncedAt: new Date()
            })
            .onConflictDoUpdate({
              target: shipShipments.id,
              set: {
                trackingNumber: trackNum || null,
                shipDate: shipDate,
                customerRef: shipment.Reference1 || shipment.customerRef || shipment.CustomerRef || shipment.customer_ref || null,
                recipientName: shipment.ConsigneeName || shipment.recipientName || shipment.RecipientName || shipment.recipient_name || null,
                recipientCity: shipment.ConsigneeCity || shipment.recipientCity || shipment.RecipientCity || shipment.recipient_city || null,
                weight: shipment.weight || shipment.Weight ? parseFloat(String(shipment.weight || shipment.Weight)) : null,
                cost: shipment.cost || shipment.Cost || shipment.price || shipment.Price ? parseFloat(String(shipment.cost || shipment.Cost || shipment.price || shipment.Price)) : null,
                status: String(shipment.StatusDisplayName || shipment.status || shipment.Status || ''),
                data: shipment,
                syncedAt: new Date()
              }
            });
          
          synced++;
        } catch (err: any) {
          errors++;
          console.error(`Error syncing shipment:`, err.message);
        }
      }
      
      res.json({ success: true, synced, errors, total: shipments.length });
    } catch (error: any) {
      console.error('Error syncing ship data:', error);
      res.status(500).json({ error: 'Failed to sync ship data', message: error.message });
    }
  });

  app.post("/api/admin/fix-ship-fields", async (req, res) => {
    try {
      const rows = await db.select({ id: shipShipments.id, data: shipShipments.data }).from(shipShipments);
      let fixed = 0;
      let skipped = 0;
      for (const row of rows) {
        const s = row.data as any;
        if (!s) { skipped++; continue; }
        // If it's the old full-response format {Total, Shipments}, skip (can't fix without individual data)
        if (s.Total !== undefined && s.Shipments !== undefined) { skipped++; continue; }
        const trackNum = s.TrackNumber || s.trackingNumber || s.TrackingNumber || s.tracking_number;
        if (!trackNum) { skipped++; continue; }
        const rawDate = s.DateShipped || s.shipDate || s.ShipDate;
        const parsedDate = rawDate ? new Date(rawDate) : null;
        const shipDate = parsedDate && !isNaN(parsedDate.getTime()) ? parsedDate.toISOString().split('T')[0] : null;
        await db.update(shipShipments).set({
          trackingNumber: trackNum,
          shipDate,
          customerRef: s.Reference1 || s.customerRef || null,
          recipientName: s.ConsigneeName || s.recipientName || null,
          recipientCity: s.ConsigneeCity || s.recipientCity || null,
          status: String(s.StatusDisplayName || s.status || s.Status || ''),
          serviceType: s.ServiceLevel != null ? String(s.ServiceLevel) : null,
        }).where(eq(shipShipments.id, row.id));
        fixed++;
      }
      res.json({ success: true, fixed, skipped, total: rows.length });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get("/api/shipments", async (req, res) => {
    try {
      const year = req.query.year ? parseInt(req.query.year as string) : new Date().getFullYear();
      
      const allShipments = await db.select().from(shipShipments);
      
      const yearShipments = allShipments.filter(s => {
        if (!s.shipDate) return false;
        try {
          const dateStr = s.shipDate;
          const dateObj = new Date(dateStr);
          if (!isNaN(dateObj.getTime())) {
            return dateObj.getFullYear() === year;
          }
          if (dateStr.includes('/')) {
            const parts = dateStr.split('/');
            if (parts.length === 3) {
              const yearPart = parseInt(parts[2]);
              return (yearPart === year) || (yearPart < 100 && yearPart + 2000 === year);
            }
          }
          if (dateStr.includes('-')) {
            const parts = dateStr.split('-');
            if (parts.length >= 1) {
              return parseInt(parts[0]) === year;
            }
          }
          return false;
        } catch {
          return false;
        }
      });

      const monthlyData: { [key: number]: { month: number, count: number, totalCost: number, totalWeight: number } } = {};
      for (let m = 1; m <= 12; m++) {
        monthlyData[m] = { month: m, count: 0, totalCost: 0, totalWeight: 0 };
      }

      const recipientBreakdown: { [key: string]: { name: string, city: string, count: number, totalCost: number } } = {};

      yearShipments.forEach(s => {
        let month = 1;
        if (s.shipDate) {
          const dateObj = new Date(s.shipDate);
          if (!isNaN(dateObj.getTime())) {
            month = dateObj.getMonth() + 1;
          } else if (s.shipDate.includes('/')) {
            const parts = s.shipDate.split('/');
            if (parts.length === 3) {
              month = parseInt(parts[1]);
            }
          } else if (s.shipDate.includes('-')) {
            const parts = s.shipDate.split('-');
            if (parts.length >= 2) {
              month = parseInt(parts[1]);
            }
          }
        }
        if (isNaN(month) || month < 1 || month > 12) month = 1;
        
        monthlyData[month].count += 1;
        monthlyData[month].totalCost += s.cost || 0;
        monthlyData[month].totalWeight += s.weight || 0;

        const recipientKey = s.recipientName || s.customerRef || 'unknown';
        if (!recipientBreakdown[recipientKey]) {
          recipientBreakdown[recipientKey] = {
            name: s.recipientName || 'לא ידוע',
            city: s.recipientCity || '',
            count: 0,
            totalCost: 0
          };
        }
        recipientBreakdown[recipientKey].count += 1;
        recipientBreakdown[recipientKey].totalCost += s.cost || 0;
      });

      const monthly = Object.values(monthlyData).sort((a, b) => a.month - b.month);
      const recipients = Object.values(recipientBreakdown).sort((a, b) => b.totalCost - a.totalCost);

      res.json({
        year,
        totalShipments: yearShipments.length,
        totalCost: yearShipments.reduce((sum, s) => sum + (s.cost || 0), 0),
        totalWeight: yearShipments.reduce((sum, s) => sum + (s.weight || 0), 0),
        monthly,
        recipients,
        shipments: yearShipments
      });
    } catch (error: any) {
      console.error('Error fetching shipments:', error);
      res.status(500).json({ error: 'Failed to fetch shipments', message: error.message });
    }
  });

  // Daily shipments aggregation from local DB
  app.get("/api/shipments/daily", async (req, res) => {
    try {
      const year = req.query.year ? parseInt(req.query.year as string) : new Date().getFullYear();
      const month = req.query.month ? parseInt(req.query.month as string) : null;

      const parseShipDate = (dateStr: string): Date | null => {
        if (!dateStr) return null;
        const d = new Date(dateStr);
        if (!isNaN(d.getTime())) return d;
        if (dateStr.includes('/')) {
          const parts = dateStr.split('/');
          if (parts.length === 3) {
            const fullYear = parseInt(parts[2]) < 100 ? 2000 + parseInt(parts[2]) : parseInt(parts[2]);
            return new Date(fullYear, parseInt(parts[1]) - 1, parseInt(parts[0]));
          }
        }
        return null;
      };

      const allShipments = await db.select().from(shipShipments);

      const filtered = allShipments.filter(s => {
        if (!s.shipDate) return false;
        const d = parseShipDate(s.shipDate);
        if (!d || isNaN(d.getTime())) return false;
        if (d.getFullYear() !== year) return false;
        if (month !== null && d.getMonth() + 1 !== month) return false;
        return true;
      });

      const byDate: { [k: string]: { date: string; count: number; totalCost: number; totalWeight: number } } = {};
      filtered.forEach(s => {
        const d = parseShipDate(s.shipDate!);
        if (!d) return;
        const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
        if (!byDate[key]) byDate[key] = { date: key, count: 0, totalCost: 0, totalWeight: 0 };
        byDate[key].count++;
        byDate[key].totalCost += s.cost || 0;
        byDate[key].totalWeight += s.weight || 0;
      });

      const daily = Object.values(byDate).sort((a, b) => a.date.localeCompare(b.date));
      const maxDay = daily.length > 0 ? daily.reduce((mx, d) => d.totalCost > mx.totalCost ? d : mx) : null;
      const avgDailyCost = daily.length > 0 ? daily.reduce((s, d) => s + d.totalCost, 0) / daily.length : 0;

      res.json({
        year, month,
        totalDays: daily.length,
        totalShipments: filtered.length,
        totalCost: filtered.reduce((s, sh) => s + (sh.cost || 0), 0),
        avgDailyCost: Math.round(avgDailyCost),
        maxDay,
        daily
      });
    } catch (error: any) {
      res.status(500).json({ error: 'Failed to fetch daily shipments', message: error.message });
    }
  });

  // Live Ship API sync — calls the API directly and optionally saves results
  app.post("/api/ship/sync-live", async (req, res) => {
    const baseUrl = 'https://newbetaapi.ship.co.il';
    const email    = process.env.SHIP_API_EMAIL    || '';
    const password = process.env.SHIP_API_PASSWORD || '';
    const customerId = process.env.SHIP_CUSTOMER_ID || '699226';

    if (!email || !password) {
      return res.json({ success: false, error: 'חסרים פרטי התחברות (SHIP_API_EMAIL / SHIP_API_PASSWORD)' });
    }

    try {
      // 1. Authenticate — try JSON login (ship.co.il v1 API) then fallback to form-encoded /Token
      let token: string | null = null;

      // Attempt 1: POST /api/v1/users/login  (JSON body, used by the official web app)
      try {
        const authResp1 = await fetch(`${baseUrl}/api/v1/users/login`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Origin': 'https://newbetaapp.ship.co.il',
            'Referer': 'https://newbetaapp.ship.co.il/',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          },
          body: JSON.stringify({ email, password, customerId }),
          signal: AbortSignal.timeout(20000)
        });
        if (authResp1.ok) {
          const d = await authResp1.json() as any;
          token = d.access_token || d.token || d.accessToken || null;
        }
      } catch { /* try next */ }

      // Attempt 2: POST /Token  (OAuth2 form-encoded, older endpoint)
      if (!token) {
        try {
          const authResp2 = await fetch(`${baseUrl}/Token`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams({ username: email, password, scope: customerId, grant_type: 'password' }).toString(),
            signal: AbortSignal.timeout(20000)
          });
          if (authResp2.ok) {
            const d = await authResp2.json() as any;
            token = d.access_token || d.token || null;
          }
        } catch { /* failed */ }
      }

      if (!token) {
        return res.json({ success: false, stage: 'auth', error: 'ההתחברות ל-Ship API נכשלה — בדוק SHIP_API_EMAIL ו-SHIP_API_PASSWORD' });
      }

      // 2. Try shipment endpoints
      const fromDate = (req.body?.fromDate as string) || `${new Date().getFullYear()}-01-01`;
      const toDate   = (req.body?.toDate   as string) || new Date().toISOString().slice(0, 10);

      // Customer-specific endpoints first (highest chance of working), then generic
      const endpointsToTry = [
        `/api/v1/customers/${customerId}/shipments?fromDate=${fromDate}&toDate=${toDate}`,
        `/api/v1/customers/${customerId}/shipments?from=${fromDate}&to=${toDate}`,
        `/api/v1/customers/${customerId}/shipments?startDate=${fromDate}&endDate=${toDate}`,
        `/api/v1/Shipment/History?fromDate=${fromDate}&toDate=${toDate}&customerId=${customerId}`,
        `/api/v1/shipments?fromDate=${fromDate}&toDate=${toDate}&customerId=${customerId}`,
        `/api/v1/Shipment/History?fromDate=${fromDate}&toDate=${toDate}`,
        `/api/v1/shipments?fromDate=${fromDate}&toDate=${toDate}`,
        `/api/Shipments?fromDate=${fromDate}&toDate=${toDate}`,
        `/api/v1/Shipment/List?fromDate=${fromDate}&toDate=${toDate}`,
        `/api/v1/shipments?from=${fromDate}&to=${toDate}`,
      ];

      const tried: { endpoint: string; status: number; preview?: string }[] = [];

      for (const endpoint of endpointsToTry) {
        try {
          const resp = await fetch(`${baseUrl}${endpoint}`, {
            headers: { 'Authorization': `Bearer ${token}`, 'Accept': 'application/json' },
            signal: AbortSignal.timeout(15000)
          });
          const bodyText = await resp.text();
          tried.push({ endpoint, status: resp.status, preview: bodyText.slice(0, 120) });
          console.log(`[ship-live] ${resp.status} ${endpoint} → ${bodyText.slice(0, 80)}`);

          if (resp.ok) {
            let data: any;
            try { data = JSON.parse(bodyText); } catch { data = null; }

            // Extract array from various response shapes
            const raw = Array.isArray(data) ? data
              : (data?.data || data?.shipments || data?.Shipments || data?.items ||
                 data?.Items || data?.results || data?.Results || data?.list || data?.List || []);
            const shipments: any[] = Array.isArray(raw) ? raw : [];

            if (shipments.length === 0 && data !== null) {
              // Response was OK but no shipments — note it and try next endpoint
              console.log(`[ship-live] ${endpoint} → OK but 0 records, keys: ${Object.keys(data || {}).join(', ')}`);
              continue;
            }

            // Save to DB
            let saved = 0;
            for (const s of shipments) {
              try {
                const id = String(s.id || s.shipmentId || s.ShipmentId || `live_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`);
                await db.insert(shipShipments).values({
                  id,
                  shipmentId: String(s.shipmentId || s.ShipmentId || s.id || ''),
                  trackingNumber: s.trackingNumber || s.TrackingNumber || null,
                  shipDate: s.shipDate || s.ShipDate || s.date || null,
                  customerRef: s.customerRef || s.CustomerRef || s.reference || null,
                  recipientName: s.recipientName || s.RecipientName || s.toName || null,
                  recipientCity: s.recipientCity || s.RecipientCity || s.toCity || null,
                  weight: (s.weight || s.Weight) ? parseFloat(String(s.weight || s.Weight)) : null,
                  cost: (s.cost || s.Cost || s.price) ? parseFloat(String(s.cost || s.Cost || s.price)) : null,
                  currency: s.currency || s.Currency || 'ILS',
                  status: s.status || s.Status || null,
                  serviceType: s.serviceType || s.ServiceType || null,
                  data: s,
                  syncedAt: new Date()
                }).onConflictDoUpdate({ target: shipShipments.id, set: { data: s, syncedAt: new Date() } });
                saved++;
              } catch { /* skip bad record */ }
            }

            return res.json({
              success: true, authenticated: true, endpoint,
              totalReceived: shipments.length, saved,
              sample: shipments.length > 0 ? shipments[0] : (typeof data === 'object' && !Array.isArray(data) ? Object.keys(data) : data)
            });
          }
        } catch (err: any) {
          tried.push({ endpoint, status: 0, preview: err.message?.slice(0, 60) });
        }
      }

      return res.json({ success: false, authenticated: true, error: 'לא נמצא endpoint עובד', tried });
    } catch (error: any) {
      res.json({ success: false, error: error.message });
    }
  });

  // ─── Operational Query ───────────────────────────────────────────────────────
  // GET: read from PostgreSQL (data synced by local Python script)
  app.get('/api/operational-query', async (req, res) => {
    try {
      const dateFrom = (req.query.dateFrom as string) || '';
      const dateTo   = (req.query.dateTo   as string) || '';
      // limit=1 משמש את המסך כדי לשאול "אילו תאריכים בכלל קיימים" בלי למשוך את כל השורות
      const rowLimit = Math.max(0, Math.min(Number(req.query.limit) || 50000, 50000));

      if (priority.isLiveEnabled()) {
        const [page, available] = await Promise.all([
          priority.operationalRows(dateFrom, dateTo, rowLimit),
          priority.operationalAvailable(),
        ]);
        return res.json({
          rows: page.rows, total: page.total, returned: page.rows.length,
          truncated: page.total > page.rows.length,
          syncedAt: new Date().toISOString(), live: true, available,
        });
      }

      // כל תאריך מסנן בנפרד — מילוי צד אחד בלבד הוא טווח פתוח, לא ביטול הסינון
      const conds: any[] = [];
      if (dateFrom) conds.push(sql`doc_date >= ${dateFrom}`);
      if (dateTo)   conds.push(sql`doc_date <= ${dateTo}`);
      const where = conds.length ? sql`WHERE ${sql.join(conds, sql` AND `)}` : sql``;

      const [pageResult, statsResult, availableResult] = await Promise.all([
        db.execute(sql`SELECT data FROM operational_query_rows ${where} ORDER BY doc_date LIMIT ${rowLimit}`),
        db.execute(sql`SELECT COUNT(*)::int AS total, MAX(synced_at) AS synced_at FROM operational_query_rows ${where}`),
        db.execute(sql`SELECT MIN(doc_date) AS min, MAX(doc_date) AS max, COUNT(*)::int AS count
                       FROM operational_query_rows WHERE doc_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'`),
      ]);

      const result = pageResult.rows.map((r: any) => r.data as Record<string, any>);
      const stats  = (statsResult.rows[0] ?? {}) as any;
      const total  = Number(stats.total ?? result.length);

      res.json({
        rows:      result,
        total,
        returned:  result.length,
        truncated: total > result.length,
        syncedAt:  stats.synced_at ?? null,
        available: availableResult.rows[0] ?? { min: null, max: null, count: 0 },
      });
    } catch (err: any) {
      res.status(500).json({ error: err.message });
    }
  });

  // POST: receive synced data from local Python script
  // Body: { rows: Array<Record<string,any>>, syncId?: string }
  // Each row must have at minimum: תעודת משלוח, תאריך תעודת משלוח (dd/MM/yy), מספר לקוח
  app.post('/api/sync/operational-query', async (req, res) => {
    try {
      const { rows, syncId = `oq-${Date.now()}` } = req.body as {
        rows: Record<string, any>[];
        syncId?: string;
      };
      if (!Array.isArray(rows)) return res.status(400).json({ error: 'rows array required' });

      // Clear existing data for this sync range (full replace strategy)
      if (req.body.clearAll) {
        await db.delete(operationalQueryRows);
      }

      const BATCH = 200;
      let imported = 0;
      for (let i = 0; i < rows.length; i += BATCH) {
        const batch = rows.slice(i, i + BATCH);
        const inserts = batch.map(row => ({
          docNo:    String(row['תעודת משלוח'] ?? ''),
          docDate:  (() => {
            // Convert dd/MM/yy → YYYY-MM-DD for easy range queries
            const d = String(row['תאריך תעודת משלוח'] ?? '');
            const p = d.split('/');
            if (p.length === 3) {
              const yr = p[2].length === 2 ? '20' + p[2] : p[2];
              return `${yr}-${p[1].padStart(2,'0')}-${p[0].padStart(2,'0')}`;
            }
            return d;
          })(),
          custName: String(row['שם לקוח'] ?? ''),
          syncId,
          data:     row,
        }));
        await db.insert(operationalQueryRows).values(inserts);
        imported += inserts.length;
      }

      console.log(`[operational-query sync] imported ${imported} rows, syncId=${syncId}`);
      res.json({ success: true, imported, syncId });
    } catch (err: any) {
      res.status(500).json({ error: err.message });
    }
  });

  // ─── Financial Query ─────────────────────────────────────────────────────────
  app.get('/api/financial-query', async (req, res) => {
    try {
      const dateFrom = (req.query.dateFrom as string) || '';
      const dateTo   = (req.query.dateTo   as string) || '';
      // limit=1 משמש את המסך כדי לשאול "אילו תאריכים בכלל קיימים" בלי למשוך את כל השורות
      const rowLimit = Math.max(0, Math.min(Number(req.query.limit) || 50000, 50000));

      if (priority.isLiveEnabled()) {
        const [page, available] = await Promise.all([
          priority.financialRows(dateFrom, dateTo, rowLimit),
          priority.financialAvailable(),
        ]);
        return res.json({
          rows: page.rows, total: page.total, returned: page.rows.length,
          truncated: page.total > page.rows.length,
          syncedAt: new Date().toISOString(), live: true, available,
        });
      }

      // כל תאריך מסנן בנפרד — מילוי צד אחד בלבד הוא טווח פתוח, לא ביטול הסינון
      const conds: any[] = [];
      if (dateFrom) conds.push(sql`iv_date >= ${dateFrom}`);
      if (dateTo)   conds.push(sql`iv_date <= ${dateTo}`);
      const where = conds.length ? sql`WHERE ${sql.join(conds, sql` AND `)}` : sql``;

      const [pageResult, statsResult, availableResult] = await Promise.all([
        db.execute(sql`SELECT data FROM financial_query_rows ${where} ORDER BY iv_date LIMIT ${rowLimit}`),
        db.execute(sql`SELECT COUNT(*)::int AS total, MAX(synced_at) AS synced_at FROM financial_query_rows ${where}`),
        db.execute(sql`SELECT MIN(iv_date) AS min, MAX(iv_date) AS max, COUNT(*)::int AS count
                       FROM financial_query_rows WHERE iv_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'`),
      ]);

      const result = pageResult.rows.map((r: any) => r.data as Record<string, any>);
      const stats  = (statsResult.rows[0] ?? {}) as any;
      const total  = Number(stats.total ?? result.length);

      res.json({
        rows:      result,
        total,
        returned:  result.length,
        truncated: total > result.length,
        syncedAt:  stats.synced_at ?? null,
        available: availableResult.rows[0] ?? { min: null, max: null, count: 0 },
      });
    } catch (err: any) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/sync/financial-query', async (req, res) => {
    try {
      const { rows, syncId = `fq-${Date.now()}` } = req.body as {
        rows: Record<string, any>[];
        syncId?: string;
      };
      if (!Array.isArray(rows)) return res.status(400).json({ error: 'rows array required' });

      if (req.body.clearAll) {
        await db.delete(financialQueryRows);
      }

      const BATCH = 200;
      let imported = 0;
      for (let i = 0; i < rows.length; i += BATCH) {
        const batch = rows.slice(i, i + BATCH);
        const inserts = batch.map(row => ({
          ivNum:    String(row['חשבונית'] ?? ''),
          ivDate:   (() => {
            const d = String(row['תאריך החשבונית'] ?? '');
            const p = d.split('/');
            if (p.length === 3) {
              const yr = p[2].length === 2 ? '20' + p[2] : p[2];
              return `${yr}-${p[1].padStart(2,'0')}-${p[0].padStart(2,'0')}`;
            }
            return d;
          })(),
          custName: String(row['שם לקוח'] ?? ''),
          syncId,
          data:     row,
        }));
        await db.insert(financialQueryRows).values(inserts);
        imported += inserts.length;
      }

      console.log(`[financial-query sync] imported ${imported} rows, syncId=${syncId}`);
      res.json({ success: true, imported, syncId });
    } catch (err: any) {
      res.status(500).json({ error: err.message });
    }
  });

  // ─── Dept Overview Stats (merged from financial + operational query rows) ────
  app.get('/api/departments/overview-stats', async (req, res) => {
    const dateFrom = (req.query.dateFrom as string) || '';
    const dateTo   = (req.query.dateTo   as string) || '';
    try {
      if (priority.isLiveEnabled()) {
        const [live, available] = await Promise.all([
          priority.departmentsOverview(dateFrom, dateTo),
          priority.operationalAvailable(),
        ]);
        return res.json({ ...live, available, live: true });
      }
      const finFrom = dateFrom ? sql`AND iv_date >= ${dateFrom}` : sql``;
      const finTo   = dateTo   ? sql`AND iv_date <= ${dateTo}`   : sql``;
      const opFrom  = dateFrom ? sql`AND doc_date >= ${dateFrom}` : sql``;
      const opTo    = dateTo   ? sql`AND doc_date <= ${dateTo}`   : sql``;

      const [summaryResult, byAgentResult, byCalibratorResult, availableResult] = await Promise.all([
        // Per dept+year summary: revenue from financial, calls+customers from operational
        db.execute(sql`
          WITH fin AS (
            SELECT
              COALESCE(data->>'מספר מחלקה', '') AS dept_code,
              COALESCE(data->>'שם מחלקה',   '') AS dept_name,
              LEFT(iv_date, 4)                   AS year,
              SUM(CASE WHEN data->>'סהכ לשורה בחשבונית כולל חריגים (בשקלים)' ~ '^-?[0-9]+\.?[0-9]*$'
                   THEN (data->>'סהכ לשורה בחשבונית כולל חריגים (בשקלים)')::decimal ELSE 0 END) AS revenue,
              COUNT(DISTINCT data->>'מספר לקוח')::int AS customer_count_fin
            FROM financial_query_rows
            WHERE data->>'מספר מחלקה' IS NOT NULL AND data->>'מספר מחלקה' != ''
              AND iv_date IS NOT NULL AND LEFT(iv_date, 4) ~ '^[0-9]{4}$'
              ${finFrom} ${finTo}
            GROUP BY 1, 2, 3
          ),
          op AS (
            SELECT
              COALESCE(data->>'מספר מחלקה', '') AS dept_code,
              LEFT(doc_date, 4)                  AS year,
              COUNT(DISTINCT data->>'תעודת משלוח')::int AS call_count,
              COUNT(DISTINCT data->>'מספר לקוח')::int   AS customer_count_op
            FROM operational_query_rows
            WHERE data->>'מספר מחלקה' IS NOT NULL AND data->>'מספר מחלקה' != ''
              AND doc_date IS NOT NULL AND LEFT(doc_date, 4) ~ '^[0-9]{4}$'
              ${opFrom} ${opTo}
            GROUP BY 1, 2
          )
          SELECT
            COALESCE(fin.dept_code, op.dept_code)   AS dept_code,
            COALESCE(fin.dept_name, '')              AS dept_name,
            COALESCE(fin.year, op.year)              AS year,
            COALESCE(fin.revenue, 0)                 AS revenue,
            COALESCE(fin.customer_count_fin, 0)      AS customer_count,
            COALESCE(op.call_count, 0)               AS call_count
          FROM fin
          FULL OUTER JOIN op ON fin.dept_code = op.dept_code AND fin.year = op.year
          ORDER BY revenue DESC NULLS LAST
        `),
        // Per dept+year+agent (for agent drill-down)
        db.execute(sql`
          SELECT
            COALESCE(data->>'מספר מחלקה', '') AS dept_code,
            COALESCE(data->>'שם מחלקה',   '') AS dept_name,
            COALESCE(data->>'שם סוכן',    '') AS agent_name,
            LEFT(iv_date, 4)                   AS year,
            SUM(CASE WHEN data->>'סהכ לשורה בחשבונית כולל חריגים (בשקלים)' ~ '^-?[0-9]+\.?[0-9]*$'
                 THEN (data->>'סהכ לשורה בחשבונית כולל חריגים (בשקלים)')::decimal ELSE 0 END) AS revenue,
            COUNT(DISTINCT data->>'מספר לקוח')::int AS customer_count
          FROM financial_query_rows
          WHERE data->>'מספר מחלקה' IS NOT NULL AND data->>'מספר מחלקה' != ''
            AND iv_date IS NOT NULL AND LEFT(iv_date, 4) ~ '^[0-9]{4}$'
            ${finFrom} ${finTo}
          GROUP BY 1, 2, 3, 4
          ORDER BY revenue DESC NULLS LAST
        `),
        // Per dept+year+calibrator (for calibrator drill-down + filter)
        db.execute(sql`
          SELECT
            COALESCE(data->>'מספר מחלקה', '') AS dept_code,
            COALESCE(data->>'שם מחלקה',   '') AS dept_name,
            COALESCE(data->>'שם כייל',    '') AS calibrator_name,
            LEFT(doc_date, 4)                  AS year,
            COUNT(DISTINCT data->>'תעודת משלוח')::int AS call_count
          FROM operational_query_rows
          WHERE data->>'מספר מחלקה' IS NOT NULL AND data->>'מספר מחלקה' != ''
            AND doc_date IS NOT NULL AND LEFT(doc_date, 4) ~ '^[0-9]{4}$'
            ${opFrom} ${opTo}
          GROUP BY 1, 2, 3, 4
          ORDER BY call_count DESC NULLS LAST
        `),
        // הטווח שקיים בפועל בשתי הטבלאות — כדי שהמסך יבחין בין "לא סונכרן"
        // לבין "סונכרן, אבל לא לתאריכים שביקשת"
        db.execute(sql`
          SELECT MIN(d) AS min, MAX(d) AS max, SUM(n)::int AS count FROM (
            SELECT MIN(iv_date) AS d, COUNT(*) AS n FROM financial_query_rows
              WHERE iv_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            UNION ALL
            SELECT MAX(iv_date), 0 FROM financial_query_rows
              WHERE iv_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            UNION ALL
            SELECT MIN(doc_date), COUNT(*) FROM operational_query_rows
              WHERE doc_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            UNION ALL
            SELECT MAX(doc_date), 0 FROM operational_query_rows
              WHERE doc_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
          ) s
        `),
      ]);

      res.json({
        summary:       summaryResult.rows,
        byAgent:       byAgentResult.rows,
        byCalibrator:  byCalibratorResult.rows,
        available:     availableResult.rows[0] ?? { min: null, max: null, count: 0 },
      });
    } catch (err: any) {
      res.status(500).json({ error: err.message });
    }
  });

  // ─── Dept Financial Breakdown (from financialQueryRows JSONB) ───────────────
  app.get('/api/departments/financial-breakdown', async (req, res) => {
    const dateFrom = (req.query.dateFrom as string) || '';
    const dateTo   = (req.query.dateTo   as string) || '';
    try {
      if (priority.isLiveEnabled()) {
        const [rows, avail] = await Promise.all([
          priority.financialBreakdown(dateFrom, dateTo),
          priority.financialAvailable(),
        ]);
        return res.json({ rows, available: avail, live: true });
      }
      const fromFilter = dateFrom ? sql`AND iv_date >= ${dateFrom}` : sql``;
      const toFilter   = dateTo   ? sql`AND iv_date <= ${dateTo}`   : sql``;
      const available = await db.execute(sql`
        SELECT MIN(iv_date) AS min, MAX(iv_date) AS max, COUNT(*)::int AS count
        FROM financial_query_rows WHERE iv_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
      `);
      const result = await db.execute(sql`
        SELECT
          COALESCE(data->>'מספר מחלקה', '') AS dept_code,
          COALESCE(data->>'שם מחלקה',   '') AS dept_name,
          COALESCE(data->>'שם סוכן',    '') AS agent_name,
          COALESCE(data->>'שם משפחת מוצר', '') AS family_name,
          SUM(CASE WHEN data->>'סהכ לשורה בחשבונית כולל חריגים (בשקלים)' ~ '^-?[0-9]+\.?[0-9]*$'
               THEN (data->>'סהכ לשורה בחשבונית כולל חריגים (בשקלים)')::decimal ELSE 0 END) AS revenue,
          SUM(CASE WHEN data->>'כמות מיוחדת בפירוט חשבונית' ~ '^-?[0-9]+\.?[0-9]*$'
               THEN (data->>'כמות מיוחדת בפירוט חשבונית')::decimal ELSE 0 END) AS qty,
          COUNT(*)::int AS line_count
        FROM financial_query_rows
        WHERE data->>'מספר מחלקה' IS NOT NULL AND data->>'מספר מחלקה' != ''
          ${fromFilter} ${toFilter}
        GROUP BY 1, 2, 3, 4
        ORDER BY revenue DESC NULLS LAST
      `);
      res.json({ rows: result.rows, available: available.rows[0] ?? { min: null, max: null, count: 0 } });
    } catch (err: any) {
      res.status(500).json({ error: err.message });
    }
  });

  // ─── Dept Operational Breakdown (from operationalQueryRows JSONB) ─────────
  app.get('/api/departments/operational-breakdown', async (req, res) => {
    const dateFrom = (req.query.dateFrom as string) || '';
    const dateTo   = (req.query.dateTo   as string) || '';
    try {
      if (priority.isLiveEnabled()) {
        const [rows, avail] = await Promise.all([
          priority.operationalBreakdown(dateFrom, dateTo),
          priority.operationalAvailable(),
        ]);
        return res.json({ rows, available: avail, live: true });
      }
      const fromFilter = dateFrom ? sql`AND doc_date >= ${dateFrom}` : sql``;
      const toFilter   = dateTo   ? sql`AND doc_date <= ${dateTo}`   : sql``;
      const available = await db.execute(sql`
        SELECT MIN(doc_date) AS min, MAX(doc_date) AS max, COUNT(*)::int AS count
        FROM operational_query_rows WHERE doc_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
      `);
      const result = await db.execute(sql`
        SELECT
          COALESCE(data->>'מספר מחלקה', '') AS dept_code,
          COALESCE(data->>'שם מחלקה',   '') AS dept_name,
          COALESCE(data->>'שם כייל',    '') AS calibrator_name,
          COALESCE(data->>'שם משפחת מוצר', '') AS family_name,
          SUM(CASE WHEN data->>'כמות מחושבת' ~ '^-?[0-9]+\.?[0-9]*$'
               THEN (data->>'כמות מחושבת')::decimal ELSE 0 END) AS total_qty,
          COUNT(*)::int AS doc_count
        FROM operational_query_rows
        WHERE data->>'מספר מחלקה' IS NOT NULL AND data->>'מספר מחלקה' != ''
          ${fromFilter} ${toFilter}
        GROUP BY 1, 2, 3, 4
        ORDER BY total_qty DESC NULLS LAST
      `);
      res.json({ rows: result.rows, available: available.rows[0] ?? { min: null, max: null, count: 0 } });
    } catch (err: any) {
      res.status(500).json({ error: err.message });
    }
  });

  return httpServer;
}
