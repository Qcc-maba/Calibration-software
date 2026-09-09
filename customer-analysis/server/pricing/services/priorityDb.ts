import sql from 'mssql';
import { PriceListItem, isValidPartNumber } from '../types';

let pool: sql.ConnectionPool | null = null;

/**
 * התמחור והדשבורד מדברים עם אותו Priority (amaba), אבל הגיעו עם שמות משתני
 * סביבה שונים. כדי שלא תהיה כאן הגדרה שנייה שאפשר לשכוח לעדכן, PRIORITY_DB_*
 * ממשיך לגבור אם הוגדר, ואחרת נופלים להגדרה של הדשבורד (SQL_SERVER_ADDR וחבריו,
 * בפורמט "maba-priority\\pri" או "host,1433").
 */
function analyticsPriorityEnv(): { server?: string; instance?: string; port?: string } {
  const addr = process.env.SQL_SERVER_ADDR;
  if (!addr) return {};
  const [serverPart, portPart] = addr.split(',');
  const [server, instance] = serverPart.split('\\');
  return { server: server || undefined, instance: instance || undefined, port: portPart || undefined };
}

function getConfig(): sql.config {
  const fallback = analyticsPriorityEnv();
  const instance = process.env.PRIORITY_DB_INSTANCE || fallback.instance;
  const config: sql.config = {
    server: process.env.PRIORITY_DB_SERVER || fallback.server || 'localhost',
    database: process.env.PRIORITY_DB_NAME || process.env.SQL_DATABASE || 'priority',
    user: process.env.PRIORITY_DB_USER || process.env.SQL_UID || 'sa',
    password: process.env.PRIORITY_DB_PASSWORD || process.env.SQL_PWD || '',
    options: {
      encrypt: process.env.PRIORITY_DB_ENCRYPT === 'true',
      trustServerCertificate: process.env.PRIORITY_DB_TRUST_CERT !== 'false',
      // אם יש instance name (named instance), הפורט נקבע דינמית ע"י SQL Browser
      ...(instance ? { instanceName: instance } : {}),
    },
    pool: { max: 5, min: 0, idleTimeoutMillis: 30000 },
  };
  // ציון פורט רק אם אין instance (named instance + port = קונפליקט)
  if (!instance) {
    config.port = parseInt(process.env.PRIORITY_DB_PORT || fallback.port || '1433', 10);
  }
  return config;
}

export async function getPool(): Promise<sql.ConnectionPool> {
  if (pool && pool.connected) return pool;
  pool = await new sql.ConnectionPool(getConfig()).connect();
  return pool;
}

export async function isAvailable(): Promise<boolean> {
  try {
    const p = await getPool();
    await p.request().query('SELECT 1 AS ok');
    return true;
  } catch (err) {
    return false;
  }
}

/**
 * שאילתה לטבלת PART של מ.ב.א. הזורע פריוריטי.
 * מבנה בפועל: PARTNAME הוא המק"ט החיצוני (מחרוזת כמו "110101-0"),
 * PART הוא ה-ID הפנימי (int). FAMILY ו-CURRENCY הם FK ולכן נעשה JOIN.
 *
 * מסנן: רק פריטים שיש להם PARTNAME מלא ו-PARTDES (תיאור) -
 * זה מסנן פריטים מערכתיים פנימיים.
 */
export async function loadFromPriority(): Promise<PriceListItem[]> {
  const p = await getPool();
  // PARTNAME = מק"ט חיצוני (טקסט), PART = ID פנימי (int).
  // CURRENCIES.NAME = שם המטבע (עברית), CODE = סימול (3 תווים).
  // FAMILY.FAMILYDES = שם המשפחה. ב-מ.ב.א. אין FK מוצהר אז משתמשים בקונבנציה.
  const result = await p.request().query(`
    SELECT
      P.PARTNAME    AS partNumber,
      P.PARTDES     AS description,
      F.FAMILYDES   AS category,
      P.PRICE       AS price,
      C.CODE        AS currency,
      U.UNITNAME    AS unit
    FROM PART P
    LEFT JOIN FAMILY F     ON F.FAMILY = P.FAMILY
    LEFT JOIN CURRENCIES C ON C.CURRENCY = P.CURRENCY
    LEFT JOIN UNIT U       ON U.UNIT = P.UNIT
    WHERE P.PARTNAME IS NOT NULL
      AND P.PARTDES IS NOT NULL
      AND LTRIM(RTRIM(P.PARTNAME)) <> ''
      AND P.PART > 0
  `);

  const items = result.recordset.map((r): PriceListItem => ({
    partNumber: String(r.partNumber ?? '').trim(),
    description: String(r.description ?? '').trim(),
    category: r.category ? String(r.category).trim() : undefined,
    price: typeof r.price === 'number' && r.price > 0 ? r.price : undefined,
    currency: r.currency ? String(r.currency).trim() : undefined,
    unit: r.unit ? String(r.unit).trim() : undefined,
  })).filter(i => i.description && isValidPartNumber(i.partNumber));

  return items;
}

/**
 * שמות לקוחות מטבלת CUSTOMERS - לשימוש בהשלמה האוטומטית של שדה "לקוח" בלבד.
 * לא משמש לחיפוש מחירים (המחירון נשאר אקסל בלבד).
 * CUSTNAME = קוד הלקוח בפריוריטי, CUSTDES = שם הלקוח לתצוגה.
 */
export interface PriorityCustomer {
  cust: number;   // מפתח פנימי בפריוריטי - דרוש לשליפת המכשירים של הלקוח
  code: string;   // CUSTNAME - קוד הלקוח כפי שמופיע במסכים
  name: string;
  inactive: boolean;  // CUSTSTATS.INACTIVE - הרשומה סומנה בפריוריטי כ"לא פעיל"
  // קודים של רשומות כפולות באותו שם שנוקו בדה-דופ. נשמרים כדי שחיפוש לפי
  // הקוד הישן ימשיך למצוא את הלקוח ולא יחזיר "אין תוצאות".
  altCodes: string[];
}

let customerCache: { at: number; rows: PriorityCustomer[] } | null = null;
const CUSTOMER_CACHE_TTL_MS = 30 * 60 * 1000; // חצי שעה - רשימת לקוחות משתנה לאט

export async function loadCustomerNames(): Promise<PriorityCustomer[]> {
  const p = await getPool();
  const result = await p.request().query(`
    SELECT C.CUST AS cust, C.CUSTNAME AS code, C.CUSTDES AS name,
           CASE WHEN S.INACTIVE = 'Y' THEN 1 ELSE 0 END AS inactive
    FROM CUSTOMERS C
    LEFT JOIN CUSTSTATS S ON S.CUSTSTAT = C.CUSTSTAT
    WHERE C.CUSTDES IS NOT NULL
      AND LTRIM(RTRIM(C.CUSTDES)) <> ''
      -- רשומות שסומנו בפריוריטי כלא בשימוש לא מוצעות בהשלמה
      AND C.CUSTDES NOT LIKE N'%לא בשימוש%'
    -- הפעיל ראשון בתוך כל שם: הדה-דופ למטה שומר את הרשומה הראשונה, וללקוח
    -- שיש לו גם רשומה היסטורית "לא פעיל" זה מה שקובע איזה קוד ישרוד.
    ORDER BY C.CUSTDES, inactive, C.CUST DESC
  `);
  // כמה רשומות בפריוריטי חולקות שם זהה (סניפים / כפילויות היסטוריות).
  // להשלמה האוטומטית שם אחד מספיק, וכפילות גם שוברת את מפתחות הרשימה בממשק.
  const byName = new Map<string, PriorityCustomer>();
  for (const r of result.recordset as Array<{ cust: unknown; code: unknown; name: unknown; inactive: unknown }>) {
    const name = String(r.name ?? '').trim();
    if (!name) continue;
    const key = name.toLowerCase();
    const code = String(r.code ?? '').trim();
    const existing = byName.get(key);
    if (existing) {
      // הקוד של הכפילות עדיין חייב להיות ניתן לחיפוש
      if (code && code !== existing.code && !existing.altCodes.includes(code)) existing.altCodes.push(code);
      continue;
    }
    byName.set(key, {
      cust: Number(r.cust) || 0,
      code,
      name,
      inactive: Number(r.inactive) === 1,
      altCodes: [],
    });
  }
  return [...byName.values()];
}

/**
 * גרסה עם cache שלא זורקת: אם פריוריטי לא זמין מחזירה רשימה ריקה,
 * כך שההשלמה ממשיכה לעבוד על השמות המקומיים בלבד.
 */
export async function getCustomerNamesCached(force = false): Promise<PriorityCustomer[]> {
  if (!force && customerCache && Date.now() - customerCache.at < CUSTOMER_CACHE_TTL_MS) {
    return customerCache.rows;
  }
  try {
    const rows = await loadCustomerNames();
    customerCache = { at: Date.now(), rows };
    return rows;
  } catch (err) {
    console.warn('[pricing] could not load customer names from Priority:', (err as Error).message);
    // שומרים cache ריק לזמן קצר כדי לא לנסות מחדש בכל הקלדה
    customerCache = { at: Date.now() - CUSTOMER_CACHE_TTL_MS + 60_000, rows: customerCache?.rows ?? [] };
    return customerCache.rows;
  }
}

/**
 * היסטוריית הכיולים של מ.ב.א. לפי דגם: לכל (דגם, מק"ט שחויב) - כמה פעמים.
 * מקור: MBA_SERNUMBERS - 657 אלף מכשירים שכוילו, מתוכם ~261 אלף עם דגם רשום.
 * זו התשובה האמיתית לשאלה "מה מ.ב.א. גובה עבור המכשיר הזה", במקום ניחוש טקסטואלי.
 */
export interface ModelPartStat {
  model: string;
  part: string;
  n: number;
}

export async function loadModelPartStats(): Promise<ModelPartStat[]> {
  const p = await getPool();
  const result = await p.request().query(`
    SELECT LTRIM(RTRIM(S.MODEL)) model, P.PARTNAME part, COUNT(*) n
    FROM MBA_SERNUMBERS S JOIN PART P ON P.PART = S.LASTPART
    WHERE S.LASTPART > 0
      AND S.MODEL IS NOT NULL AND LEN(LTRIM(RTRIM(S.MODEL))) >= 3
      AND P.PARTNAME IS NOT NULL
    GROUP BY LTRIM(RTRIM(S.MODEL)), P.PARTNAME
  `);
  return (result.recordset as Array<{ model: unknown; part: unknown; n: unknown }>)
    .map(r => ({
      model: String(r.model ?? '').trim(),
      part: String(r.part ?? '').trim(),
      n: Number(r.n) || 0,
    }))
    .filter(r => r.model && r.part && r.n > 0);
}

/**
 * המכשירים הרשומים על לקוח מסוים, עם המק"ט שחויב בפועל בכיול האחרון.
 * SERNUMBERS.SERNUM = הסידורי כפי שנרשם במ.ב.א., עם קידומת מספר הלקוח
 * ("10251-MY63001116"). SERNUMBERS.PART הוא מק"ט הבסיס (בלי סיומת שירות),
 * ואילו SERVCALLS.PART הוא מה שחויב בפועל - כולל ההחלטה פנים/חוץ.
 */
export interface CustomerDevice {
  serial: string;       // SERNUM כפי שנשמר
  basePart: string;     // מק"ט בסיס (ללא סיומת)
  chargedPart: string;  // המק"ט שחויב בכיול האחרון (עם סיומת)
  mbaNum: string;       // מספר מ.ב.א. של המסמך האחרון
  model: string;
  // מספר המסמך של קריאת השירות האחרונה. משמש להכרעה בין שני רישומים של אותו
  // מכשיר: אותו סידורי נרשם לא פעם פעמיים ("...093" ו-"...093."), ובלי מדד
  // עדכניות ההכרעה ביניהם הייתה סדר השורות מה-SQL.
  lastDoc: number;
}

export async function loadCustomerDevices(cust: number): Promise<CustomerDevice[]> {
  const p = await getPool();
  const result = await p.request().query(`
    SELECT S.SERNUM serial, PB.PARTNAME basePart, PC.PARTNAME chargedPart,
           MD.MBANUM mbaNum, MS.MODEL model, LC.DOC lastDoc
    FROM SERNUMBERS S
    LEFT JOIN PART PB ON PB.PART = S.PART
    OUTER APPLY (
      SELECT TOP 1 SC.PART, SC.DOC FROM SERVCALLS SC WHERE SC.SERN = S.SERN ORDER BY SC.DOC DESC
    ) LC
    LEFT JOIN PART PC ON PC.PART = LC.PART
    -- מספר מ.ב.א. האחרון *שקיים*: לא כל קריאת שירות מייצרת מסמך, ולכן מחפשים
    -- אחורה עד הכיול האחרון שיש לו מספר (893 מתוך 940 לעומת 714 בלי זה)
    OUTER APPLY (
      SELECT TOP 1 MD.MBANUM
      FROM SERVCALLS SC2 JOIN MBA_DOCUMENTS MD ON MD.DOC = SC2.DOC
      WHERE SC2.SERN = S.SERN AND MD.MBANUM IS NOT NULL AND LTRIM(RTRIM(MD.MBANUM)) <> ''
      ORDER BY SC2.DOC DESC
    ) MD
    LEFT JOIN MBA_SERNUMBERS MS ON MS.SERN = S.SERN
    WHERE S.CUST = ${Math.trunc(cust)}
    -- סדר קבוע: בלעדיו שתי הרצות על אותם נתונים יכלו להחזיר מכשירים שונים
    ORDER BY LC.DOC DESC, S.SERN DESC
  `);
  return (result.recordset as Array<Record<string, unknown>>)
    .map(r => ({
      serial: String(r.serial ?? '').trim(),
      basePart: String(r.basePart ?? '').trim(),
      chargedPart: String(r.chargedPart ?? '').trim(),
      mbaNum: String(r.mbaNum ?? '').trim(),
      model: String(r.model ?? '').trim(),
      lastDoc: Number(r.lastDoc) || 0,
    }))
    .filter(d => d.serial && (d.chargedPart || d.basePart));
}

/**
 * אם הוזן קוד לקוח ("10251") במקום שם - מחזיר את שם הלקוח המלא.
 * כך ההתאמה לפי מספר סידורי עובדת גם כשהמשתמש הקליד קוד.
 */
export async function resolveCustomerName(input: string): Promise<string> {
  const raw = String(input || '').trim();
  if (!raw) return raw;
  const rows = await getCustomerNamesCached();
  const lower = raw.toLowerCase();
  if (rows.some(c => c.name.trim().toLowerCase() === lower)) return raw; // כבר שם
  const byCode = rows.find(c => c.code.trim().toLowerCase() === lower);
  return byCode ? byCode.name : raw;
}

/** מציאת מפתח הלקוח בפריוריטי לפי שם (מהרשימה שכבר במטמון) */
export async function findCustomerId(name: string): Promise<number | null> {
  const target = String(name || '').trim().toLowerCase();
  if (!target) return null;
  const rows = await getCustomerNamesCached();
  const hit = rows.find(c => c.name.trim().toLowerCase() === target);
  return hit && hit.cust > 0 ? hit.cust : null;
}

export async function closePool(): Promise<void> {
  if (pool) {
    await pool.close();
    pool = null;
  }
}
