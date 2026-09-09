import sql from 'mssql';
import { OPERATIONAL_SQL, FINANCIAL_SQL } from './priority-queries';

/**
 * קריאות חיות מ-Priority.
 *
 * עד עכשיו המסכים קראו מטבלאות מקומיות שסקריפטי פייתון מילאו מדי פעם, ולכן
 * הנתונים היו תמיד ישנים ולפעמים כפולים. השרת יושב בתוך הרשת ורואה את Priority
 * ישירות, אז אין סיבה לשכפל את הנתונים — הוא שואל אותם בזמן אמת.
 *
 * שתי הגנות על ה-ERP התפעולי:
 *   1. מטמון בזיכרון לפי (שאילתה, טווח) — רענון מסך חוזר לא נוגע ב-Priority.
 *   2. תקרת שורות, כדי ששאילתה רחבה בטעות לא תמשוך מיליון שורות.
 */

const CACHE_TTL_MS = Number(process.env.PRIORITY_CACHE_TTL_MS) || 5 * 60 * 1000;
const REQUEST_TIMEOUT_MS = Number(process.env.PRIORITY_TIMEOUT_MS) || 120_000;

export function isLiveEnabled(): boolean {
  const mode = (process.env.DATA_SOURCE || '').toLowerCase();
  if (mode === 'local') return false;
  if (mode === 'live') return true;
  return Boolean(process.env.SQL_SERVER_ADDR); // ברירת מחדל: חי אם Priority מוגדר
}

// ─── חיבור ────────────────────────────────────────────────────────────────────
let poolPromise: Promise<sql.ConnectionPool> | null = null;

function buildConfig(): sql.config {
  const addr = process.env.SQL_SERVER_ADDR || '';
  const [serverPart, portPart] = addr.split(',');
  const [server, instance] = serverPart.split('\\');
  return {
    server,
    port: parseInt(portPart) || undefined as any,
    user: process.env.SQL_UID || '',
    password: process.env.SQL_PWD || '',
    database: process.env.SQL_DATABASE || 'amaba',
    options: {
      encrypt: false,
      trustServerCertificate: true,
      enableArithAbort: true,
      instanceName: instance || undefined,
    },
    pool: { max: 4, min: 0, idleTimeoutMillis: 60_000 },
    connectionTimeout: 30_000,
    requestTimeout: REQUEST_TIMEOUT_MS,
  };
}

async function getPool(): Promise<sql.ConnectionPool> {
  if (!poolPromise) {
    poolPromise = new sql.ConnectionPool(buildConfig()).connect().catch(err => {
      poolPromise = null; // אל תנעל כישלון חיבור זמני לתמיד
      throw err;
    });
  }
  return poolPromise;
}

export async function checkConnection(): Promise<{ ok: boolean; error?: string }> {
  try {
    const pool = await getPool();
    await pool.request().query('SELECT 1 AS ok');
    return { ok: true };
  } catch (err: any) {
    return { ok: false, error: err?.message || String(err) };
  }
}

// ─── מטמון ────────────────────────────────────────────────────────────────────
type Entry = { at: number; value: any };
const cache = new Map<string, Entry>();
const inflight = new Map<string, Promise<any>>();

async function cached<T>(key: string, run: () => Promise<T>): Promise<T> {
  const hit = cache.get(key);
  if (hit && Date.now() - hit.at < CACHE_TTL_MS) return hit.value as T;

  // מונע עדר: כמה טעינות מקבילות של אותו מסך יריצו שאילתה אחת בלבד
  const running = inflight.get(key);
  if (running) return running as Promise<T>;

  const p = run()
    .then(value => { cache.set(key, { at: Date.now(), value }); return value; })
    .finally(() => inflight.delete(key));
  inflight.set(key, p);
  return p;
}

export function clearCache() { cache.clear(); }

// ─── עזרי שאילתה ──────────────────────────────────────────────────────────────
/** ISO yyyy-mm-dd → Date מקומי בחצות. פרמטר DATE נמנע מאי-בהירות של פורמט טקסט. */
function toDate(iso: string, endOfDay = false): Date {
  const [y, m, d] = iso.split('-').map(Number);
  return endOfDay ? new Date(y, m - 1, d, 23, 59, 59, 999) : new Date(y, m - 1, d);
}

/** גבולות רחבים כשהמשתמש נתן רק צד אחד של הטווח */
const WIDE_FROM = '1988-01-01';
const WIDE_TO   = '2099-12-31';

/**
 * ב-Priority יש כ-24 שנות היסטוריה (1.7 מיליון שורות בשאילתה התפעולית).
 * כשהמסך לא ביקש טווח כלל, סריקה של הכל לוקחת דקות ואין בה טעם — מסכי
 * המחלקות ממילא משווים את שלוש השנים האחרונות. לכן זו ברירת המחדל.
 */
export const DEFAULT_YEARS_BACK = 2;

export function defaultRange(): { from: string; to: string } {
  const now = new Date();
  const p = (n: number) => String(n).padStart(2, '0');
  return {
    from: `${now.getFullYear() - DEFAULT_YEARS_BACK}-01-01`,
    to:   `${now.getFullYear()}-${p(now.getMonth() + 1)}-${p(now.getDate())}`,
  };
}

/** ממלא צד חסר בטווח בברירת המחדל, כדי שלא תיווצר סריקה של כל ההיסטוריה */
function bounded(dateFrom: string, dateTo: string) {
  if (dateFrom && dateTo) return { from: dateFrom, to: dateTo };
  const d = defaultRange();
  return { from: dateFrom || d.from, to: dateTo || d.to };
}

async function runBase(baseSql: string, dateFrom: string, dateTo: string, top?: number) {
  const pool = await getPool();
  const req = pool.request();
  req.input('dateFrom', sql.DateTime, toDate(dateFrom || WIDE_FROM));
  req.input('dateTo',   sql.DateTime, toDate(dateTo   || WIDE_TO, true));
  const text = top ? baseSql.replace(/^\s*SELECT/i, `SELECT TOP ${top}`) : baseSql;
  const res = await req.query(text);
  return res.recordset as Record<string, any>[];
}

/**
 * מריץ אגרגציה מעל שאילתת הבסיס בלי למשוך את השורות עצמן.
 * `tail` (WHERE/GROUP BY) חייב לבוא אחרי ה-FROM, ולכן הוא פרמטר נפרד מ-`select`.
 */
async function runAggregate(baseSql: string, select: string, tail: string, dateFrom: string, dateTo: string) {
  const pool = await getPool();
  const req = pool.request();
  req.input('dateFrom', sql.DateTime, toDate(dateFrom || WIDE_FROM));
  req.input('dateTo',   sql.DateTime, toDate(dateTo   || WIDE_TO, true));
  const res = await req.query(`${select}\nFROM (\n${baseSql}\n) AS t\n${tail}`);
  return res.recordset as Record<string, any>[];
}

/**
 * שאילתות הבסיס מחזירות את התאריך כטקסט dd/MM/yy, ולכן השנה נגזרת מהטקסט.
 * זה בדיוק מה שגרסת ה-Postgres עשתה (LEFT(doc_date,4) על YYYY-MM-DD).
 */
const YEAR_OF = (col: string) => `('20' + RIGHT(${col}, 2))`;
const OP_YEAR  = YEAR_OF('[תאריך תעודת משלוח]');
const FIN_YEAR = YEAR_OF('[תאריך החשבונית]');
const HAS_DEPT = `WHERE [מספר מחלקה] IS NOT NULL AND [מספר מחלקה] <> ''`;

// ─── טווח הנתונים הקיים ב-Priority ────────────────────────────────────────────
const ISO = (d: any): string | null => {
  if (!d) return null;
  const dt = d instanceof Date ? d : new Date(d);
  if (isNaN(dt.getTime())) return null;
  const p = (n: number) => String(n).padStart(2, '0');
  return `${dt.getFullYear()}-${p(dt.getMonth() + 1)}-${p(dt.getDate())}`;
};

export async function operationalAvailable() {
  return cached('op:available', async () => {
    const pool = await getPool();
    const r = await pool.request().query(`
      SELECT MIN(DATEADD(minute, CURDATE, '01/01/1988')) AS mn,
             MAX(DATEADD(minute, CURDATE, '01/01/1988')) AS mx,
             COUNT(*) AS n
      FROM amaba.dbo.DOCUMENTS WHERE TYPE = 'D'`);
    const row = r.recordset[0] || {};
    return { min: ISO(row.mn), max: ISO(row.mx), count: Number(row.n) || 0 };
  });
}

export async function financialAvailable() {
  return cached('fin:available', async () => {
    const pool = await getPool();
    const r = await pool.request().query(`
      SELECT MIN(DATEADD(minute, IVDATE, '01/01/1988')) AS mn,
             MAX(DATEADD(minute, IVDATE, '01/01/1988')) AS mx,
             COUNT(*) AS n
      FROM amaba.dbo.INVOICES
      WHERE IVDATE > 0`);   // 0 = ה-epoch של Priority, כלומר "אין תאריך"
    const row = r.recordset[0] || {};
    return { min: ISO(row.mn), max: ISO(row.mx), count: Number(row.n) || 0 };
  });
}

// ─── השאילתות שהמסכים משתמשים בהן ─────────────────────────────────────────────
export type QueryPage = { rows: Record<string, any>[]; total: number };

async function pageAndCount(baseSql: string, dateFrom: string, dateTo: string, limit: number): Promise<QueryPage> {
  const [rows, countRows] = await Promise.all([
    runBase(baseSql, dateFrom, dateTo, limit),
    runAggregate(baseSql, 'SELECT COUNT(*) AS n', '', dateFrom, dateTo),
  ]);
  return { rows, total: Number(countRows[0]?.n) || rows.length };
}

/**
 * בלי טווח תאריכים אין שאילתה אמיתית לבצע — זו קריאת ה-meta של המסך, שרק רוצה
 * לדעת אילו תאריכים קיימים. COUNT על 24 שנות היסטוריה לוקח ~8 שניות ואינו משמש
 * לכלום, ולכן מדלגים עליו.
 */
const NO_RANGE: QueryPage = { rows: [], total: 0 };

export function operationalRows(dateFrom: string, dateTo: string, limit: number) {
  if (!dateFrom && !dateTo) return Promise.resolve(NO_RANGE);
  return cached(`op:rows:${dateFrom}:${dateTo}:${limit}`,
    () => pageAndCount(OPERATIONAL_SQL, dateFrom, dateTo, limit));
}

export function financialRows(dateFrom: string, dateTo: string, limit: number) {
  if (!dateFrom && !dateTo) return Promise.resolve(NO_RANGE);
  return cached(`fin:rows:${dateFrom}:${dateTo}:${limit}`,
    () => pageAndCount(FINANCIAL_SQL, dateFrom, dateTo, limit));
}

// ─── אגרגציות מסך המחלקות ─────────────────────────────────────────────────────
const N = (v: any) => Number(v) || 0;

export function departmentsOverview(dateFromRaw: string, dateToRaw: string) {
  const { from: dateFrom, to: dateTo } = bounded(dateFromRaw, dateToRaw);
  return cached(`dept:overview:${dateFrom}:${dateTo}`, async () => {
    const [fin, op, agent, calib] = await Promise.all([
      runAggregate(FINANCIAL_SQL,
        `SELECT [מספר מחלקה] AS dept_code, MIN([שם מחלקה]) AS dept_name, ${FIN_YEAR} AS yr,
                SUM([סהכ לשורה בחשבונית כולל חריגים (בשקלים)]) AS revenue,
                COUNT(DISTINCT [מספר לקוח]) AS customer_count`,
        `${HAS_DEPT} GROUP BY [מספר מחלקה], ${FIN_YEAR}`, dateFrom, dateTo),

      runAggregate(OPERATIONAL_SQL,
        `SELECT [מספר מחלקה] AS dept_code, ${OP_YEAR} AS yr,
                COUNT(DISTINCT [תעודת משלוח]) AS call_count,
                COUNT(DISTINCT [מספר לקוח])   AS customer_count`,
        `${HAS_DEPT} GROUP BY [מספר מחלקה], ${OP_YEAR}`, dateFrom, dateTo),

      runAggregate(FINANCIAL_SQL,
        `SELECT [מספר מחלקה] AS dept_code, MIN([שם מחלקה]) AS dept_name,
                [שם סוכן] AS agent_name, ${FIN_YEAR} AS yr,
                SUM([סהכ לשורה בחשבונית כולל חריגים (בשקלים)]) AS revenue,
                COUNT(DISTINCT [מספר לקוח]) AS customer_count`,
        `${HAS_DEPT} GROUP BY [מספר מחלקה], [שם סוכן], ${FIN_YEAR}`, dateFrom, dateTo),

      runAggregate(OPERATIONAL_SQL,
        `SELECT [מספר מחלקה] AS dept_code, MIN([שם מחלקה]) AS dept_name,
                [שם כייל] AS calibrator_name, ${OP_YEAR} AS yr,
                COUNT(DISTINCT [תעודת משלוח]) AS call_count`,
        `${HAS_DEPT} GROUP BY [מספר מחלקה], [שם כייל], ${OP_YEAR}`, dateFrom, dateTo),
    ]);

    // צירוף כספי+תפעולי לפי מחלקה ושנה, כמו הגרסה שרצה מול Postgres
    const key = (d: any, y: any) => `${d}|${y}`;
    const merged = new Map<string, any>();
    for (const r of fin) {
      merged.set(key(r.dept_code, r.yr), {
        dept_code: r.dept_code, dept_name: r.dept_name || '', year: String(r.yr),
        revenue: N(r.revenue), customer_count: N(r.customer_count), call_count: 0,
      });
    }
    for (const r of op) {
      const k = key(r.dept_code, r.yr);
      const hit = merged.get(k);
      if (hit) hit.call_count = N(r.call_count);
      else merged.set(k, {
        dept_code: r.dept_code, dept_name: '', year: String(r.yr),
        revenue: 0, customer_count: 0, call_count: N(r.call_count),
      });
    }

    return {
      summary: Array.from(merged.values()).sort((a, b) => b.revenue - a.revenue),
      byAgent: agent.map(r => ({
        dept_code: r.dept_code, dept_name: r.dept_name || '', agent_name: r.agent_name || '',
        year: String(r.yr), revenue: N(r.revenue), customer_count: N(r.customer_count),
      })).sort((a, b) => b.revenue - a.revenue),
      byCalibrator: calib.map(r => ({
        dept_code: r.dept_code, dept_name: r.dept_name || '', calibrator_name: r.calibrator_name || '',
        year: String(r.yr), call_count: N(r.call_count),
      })).sort((a, b) => b.call_count - a.call_count),
    };
  });
}

export function financialBreakdown(dateFromRaw: string, dateToRaw: string) {
  const { from: dateFrom, to: dateTo } = bounded(dateFromRaw, dateToRaw);
  return cached(`dept:fin:${dateFrom}:${dateTo}`, async () => {
    const rows = await runAggregate(FINANCIAL_SQL,
      `SELECT [מספר מחלקה] AS dept_code, MIN([שם מחלקה]) AS dept_name,
              [שם סוכן] AS agent_name, [שם משפחת מוצר] AS family_name,
              SUM([סהכ לשורה בחשבונית כולל חריגים (בשקלים)]) AS revenue,
              SUM([כמות מיוחדת בפירוט חשבונית]) AS qty,
              COUNT(*) AS line_count`,
      `${HAS_DEPT} GROUP BY [מספר מחלקה], [שם סוכן], [שם משפחת מוצר]`, dateFrom, dateTo);
    return rows.map(r => ({
      dept_code: r.dept_code, dept_name: r.dept_name || '',
      agent_name: r.agent_name || '', family_name: r.family_name || '',
      revenue: N(r.revenue), qty: N(r.qty), line_count: N(r.line_count),
    })).sort((a, b) => b.revenue - a.revenue);
  });
}

export function operationalBreakdown(dateFromRaw: string, dateToRaw: string) {
  const { from: dateFrom, to: dateTo } = bounded(dateFromRaw, dateToRaw);
  return cached(`dept:op:${dateFrom}:${dateTo}`, async () => {
    const rows = await runAggregate(OPERATIONAL_SQL,
      `SELECT [מספר מחלקה] AS dept_code, MIN([שם מחלקה]) AS dept_name,
              [שם כייל] AS calibrator_name, [שם משפחת מוצר] AS family_name,
              SUM([כמות מחושבת]) AS total_qty,
              COUNT(*) AS doc_count`,
      `${HAS_DEPT} GROUP BY [מספר מחלקה], [שם כייל], [שם משפחת מוצר]`, dateFrom, dateTo);
    return rows.map(r => ({
      dept_code: r.dept_code, dept_name: r.dept_name || '',
      calibrator_name: r.calibrator_name || '', family_name: r.family_name || '',
      total_qty: N(r.total_qty), doc_count: N(r.doc_count),
    })).sort((a, b) => b.total_qty - a.total_qty);
  });
}
