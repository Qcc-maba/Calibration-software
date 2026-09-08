/**
 * ניהול override-ים שהמשתמש קבע ידנית: לדוגמה, "Pin Gauge 1.3-4.98mm" יותאם
 * תמיד למק"ט 130903-0 בלי לעבור דרך המאצ'ר הפזי. נשמרים על דיסק בקובץ JSON
 * כך שהמיפויים נשארים בין הפעלות.
 *
 * המאגר מפוצל לשתי רמות:
 *   - מאגר כללי: כל תיקון נשמר כאן, כי "Multimeter → DMM" נכון לכל הלקוחות.
 *   - מאגר לכל לקוח: אותו תיקון נרשם גם תחת הלקוח שנבחר בזמן התיקון, כדי שיישאר
 *     נכון עבורו גם אם בעתיד לקוח אחר יתקן את אותו תיאור למק"ט אחר.
 * בחיפוש: קודם ההתאמה הספציפית של הלקוח, ואם אין - המאגר הכללי.
 */
import * as fs from 'fs';
import * as path from 'path';
import { PRICING_DATA_DIR } from '../paths';

const DATA_DIR = PRICING_DATA_DIR;
const OVERRIDES_PATH = path.join(DATA_DIR, 'customer-overrides.json');
// גיבוי חד-פעמי של הפורמט הישן (מפה שטוחה) לפני ההמרה לפורמט לפי לקוחות
const V1_BACKUP_PATH = path.join(DATA_DIR, 'customer-overrides.v1.backup.json');

type OverrideMap = Record<string, string>;

interface CustomerEntry {
  display: string;   // השם כפי שהוקלד בפעם הראשונה (לתצוגה ולהשלמה)
  map: OverrideMap;  // תיאור לקוח מנורמל → מק"ט
}

interface OverridesFileV2 {
  version: 2;
  global: OverrideMap;
  customers: Record<string, OverrideMap>;
}

// המפתח: התיאור של הלקוח (אחרי trim, case-insensitive)
// הערך: המק"ט של מ.ב.א. שבחרנו להתאים אליו
let globalMap: OverrideMap = {};
// המפתח: שם הלקוח מנורמל. הערך: השם לתצוגה + ההתאמות שלו.
let customers: Map<string, CustomerEntry> = new Map();

function normalize(s: string): string {
  return String(s || '').trim().toLowerCase();
}

/**
 * מפתח הלמידה. כשידוע דגם/יצרן, נשמר מפתח מדויק בנוסף למפתח הכללי:
 *   "caliper @@ 1108-300" → 130102-0   (זחון עד 300 - לפי הדגם)
 *   "caliper"             → 130101-0   (ברירת מחדל לתיאור כללי)
 * בחיפוש המפתח המדויק קודם, ואם אין - נופלים לכללי.
 */
function keyOf(customerDescription: string, context?: string | null): string {
  const d = normalize(customerDescription);
  const c = normalize(context || '');
  return c ? `${d} @@ ${c}` : d;
}

/** שם לקוח ריק / undefined = "ללא לקוח" → עבודה מול המאגר הכללי */
function customerKey(name?: string | null): string | null {
  const k = normalize(name || '');
  return k ? k : null;
}

function load(): void {
  try {
    if (!fs.existsSync(OVERRIDES_PATH)) return;
    const raw = JSON.parse(fs.readFileSync(OVERRIDES_PATH, 'utf8'));

    // פורמט v2 - כבר מפוצל לפי לקוחות
    if (raw && typeof raw === 'object' && raw.version === 2) {
      globalMap = raw.global || {};
      customers = new Map();
      for (const [display, map] of Object.entries((raw.customers || {}) as Record<string, OverrideMap>)) {
        customers.set(normalize(display), { display, map: map || {} });
      }
      return;
    }

    // פורמט v1 - מפה שטוחה. כל ההתאמות הקיימות נכנסות למאגר הכללי.
    globalMap = raw && typeof raw === 'object' ? raw : {};
    customers = new Map();
    if (!fs.existsSync(V1_BACKUP_PATH)) {
      fs.copyFileSync(OVERRIDES_PATH, V1_BACKUP_PATH);
      console.log(`[pricing] backed up the legacy overrides store to ${path.basename(V1_BACKUP_PATH)}`);
    }
    save();
    console.log(`[pricing] overrides store converted to the per-customer format (${Object.keys(globalMap).length} in the shared store)`);
  } catch (err) {
    console.warn('[pricing] could not load overrides:', (err as Error).message);
  }
}

function save(): void {
  try {
    if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
    const out: OverridesFileV2 = { version: 2, global: globalMap, customers: {} };
    for (const entry of customers.values()) {
      out.customers[entry.display] = entry.map;
    }
    fs.writeFileSync(OVERRIDES_PATH, JSON.stringify(out, null, 2), 'utf8');
  } catch (err) {
    console.warn('[pricing] could not save overrides:', (err as Error).message);
  }
}

/** מחזיר את מאגר ההתאמות של הלקוח (יוצר אותו אם צריך), או המאגר הכללי אם אין לקוח */
function mapFor(customerName?: string | null, create = false): OverrideMap | null {
  const key = customerKey(customerName);
  if (!key) return globalMap;
  const existing = customers.get(key);
  if (existing) return existing.map;
  if (!create) return null;
  const entry: CustomerEntry = { display: String(customerName).trim(), map: {} };
  customers.set(key, entry);
  return entry.map;
}

load();

/**
 * חיפוש התאמה: ההתאמה הספציפית של הלקוח קודמת, ואם אין לו כזו -
 * נופלים חזרה למאגר הכללי (הידע המשותף לכל הלקוחות).
 */
function lookupKey(key: string, customerName?: string | null): string | undefined {
  const ck = customerKey(customerName);
  const own = ck ? customers.get(ck)?.map[key] : undefined;
  return own ?? globalMap[key];
}

/**
 * התאמה שנלמדה עבור התיאור *והדגם* הספציפיים. זו הראיה החזקה ביותר שיש -
 * אדם תיקן בדיוק את הצירוף הזה - ולכן היא קודמת גם להיסטוריה מפריוריטי.
 */
export function getPreciseOverride(
  customerDescription: string,
  customerName?: string | null,
  context?: string | null,
): string | undefined {
  if (!context || !normalize(context)) return undefined;
  return lookupKey(keyOf(customerDescription, context), customerName);
}

/** התאמה שנלמדה עבור התיאור בלבד - ברירת מחדל, בלי קשר לדגם */
export function getGenericOverride(
  customerDescription: string,
  customerName?: string | null,
): string | undefined {
  return lookupKey(keyOf(customerDescription), customerName);
}

/** תאימות לאחור: המדויק קודם, ואם אין - הכללי */
export function getOverride(
  customerDescription: string,
  customerName?: string | null,
  context?: string | null,
): string | undefined {
  return getPreciseOverride(customerDescription, customerName, context)
    ?? getGenericOverride(customerDescription, customerName);
}

/**
 * שמירת תיקון: תמיד למאגר הכללי (כדי שיועיל לכל הלקוחות), ובנוסף תחת הלקוח
 * שנבחר - כך שאם מחר לקוח אחר יתקן את אותו תיאור אחרת, הלקוח הזה ישמור את שלו.
 */
export function setOverride(
  customerDescription: string,
  partNumber: string,
  customerName?: string | null,
  context?: string | null,
): void {
  const own = mapFor(customerName, true)!;
  const exact = keyOf(customerDescription, context);
  const generic = keyOf(customerDescription);

  // המפתח המדויק תמיד נכתב/מתעדכן
  globalMap[exact] = partNumber;
  if (own !== globalMap) own[exact] = partNumber;

  // המפתח הכללי נכתב רק אם עדיין אין ברירת מחדל לתיאור הזה. תיקון שנעשה על
  // דגם ספציפי ("Caliper 1108-300" → זחון 300) לא ידרוס ברירת מחדל קיימת
  // ("Caliper" → זחון 150) שנכונה לדגמים אחרים.
  if (exact !== generic) {
    if (!globalMap[generic]) globalMap[generic] = partNumber;
    if (own !== globalMap && !own[generic]) own[generic] = partNumber;
  }
  save();
}

/**
 * הוספת הרבה override-ים בבת אחת (ייבוא קובץ למידה). שומר פעם אחת בסוף.
 * מחזיר כמה נוספו/עודכנו.
 */
export function setOverridesBulk(
  pairs: Array<{ description: string; partNumber: string }>,
  customerName?: string | null,
): number {
  const own = mapFor(customerName, true)!;
  let count = 0;
  for (const { description, partNumber } of pairs) {
    const key = normalize(description);
    if (!key || !partNumber) continue;
    const pn = String(partNumber).trim();
    globalMap[key] = pn;
    if (own !== globalMap) own[key] = pn;
    count++;
  }
  if (count > 0) save();
  return count;
}

/** כמה התאמות זמינות בפועל: הכלליות + הספציפיות של הלקוח */
export function countOverrides(customerName?: string | null): number {
  const ck = customerKey(customerName);
  if (!ck) return Object.keys(globalMap).length;
  const own = customers.get(ck)?.map ?? {};
  return new Set([...Object.keys(globalMap), ...Object.keys(own)]).size;
}

/** ביטול תיקון: מוסר גם מהמאגר הכללי וגם מהלקוח, אחרת ההתאמה תמשיך לחזור */
export function removeOverride(
  customerDescription: string,
  customerName?: string | null,
  context?: string | null,
): void {
  const ck = customerKey(customerName);
  const own = ck ? customers.get(ck)?.map : undefined;
  const exact = keyOf(customerDescription, context);
  const generic = keyOf(customerDescription);

  // setOverride כותב, לצד המפתח המדויק, גם מפתח כללי - כשעדיין לא הייתה ברירת
  // מחדל לתיאור. מחיקה של המדויק בלבד הותירה מיפוי סמוי שהמשתמש בטוח שביטל,
  // והוא המשיך לחול על כל שורה עם אותו תיאור בלי דגם. לכן מוחקים גם את הכללי,
  // אבל רק כשהוא מצביע לאותו מק"ט - ברירת מחדל אחרת נקבעה בנפרד ואינה שלנו.
  const keys = [exact];
  if (exact !== generic && globalMap[generic] === globalMap[exact]) keys.push(generic);
  const ownKeys = [exact];
  if (own && exact !== generic && own[generic] === own[exact]) ownKeys.push(generic);

  for (const key of keys) delete globalMap[key];
  if (own) for (const key of ownKeys) delete own[key];
  save();
}

/** התאמות הזמינות ללקוח: הכלליות, כשהספציפיות שלו גוברות */
export function listOverrides(customerName?: string | null): OverrideMap {
  const ck = customerKey(customerName);
  const own = ck ? customers.get(ck)?.map ?? {} : {};
  return { ...globalMap, ...own };
}

/**
 * רישום שם לקוח גם אם עדיין אין לו התאמות - כדי שיופיע בהשלמה האוטומטית
 * בפעם הבאה. מחזיר את השם לתצוגה (השם שנרשם ראשון עבור אותו שם מנורמל).
 */
export function registerCustomer(customerName?: string | null): string | null {
  const key = customerKey(customerName);
  if (!key) return null;
  const existing = customers.get(key);
  if (existing) return existing.display;
  mapFor(customerName, true);
  save();
  return String(customerName).trim();
}

/** רשימת הלקוחות הידועים + כמה התאמות נלמדו לכל אחד (לתצוגה בהשלמה) */
export function listCustomers(): Array<{ name: string; overrides: number }> {
  return Array.from(customers.values())
    .map(c => ({ name: c.display, overrides: Object.keys(c.map).length }))
    .sort((a, b) => a.name.localeCompare(b.name, 'he'));
}
