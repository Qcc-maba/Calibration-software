/**
 * התאמה לפי מספר סידורי - הראיה החזקה ביותר שיש.
 *
 * אם הלקוח כבר כייל אצלנו את המכשיר הזה, אין צורך לנחש כלום: המכשיר רשום
 * ב-SERNUMBERS עם המק"ט שחויב בפועל בכיול האחרון (כולל ההחלטה פנים/חוץ)
 * ועם מספר מ.ב.א. של המסמך.
 *
 * הסידורי נשמר במ.ב.א. עם קידומת מספר הלקוח ("10251-MY63001116"), ולעיתים
 * עם נקודות/מקפים נוספים, ולכן ההשוואה מתבצעת על צורה מנורמלת.
 */
import { CustomerDevice, findCustomerId, loadCustomerDevices } from './priorityDb';

export interface SerialHit {
  serial: string;
  part: string;      // המק"ט שחויב בפועל (או הבסיס אם אין היסטוריית חיוב)
  mbaNum: string;
  model: string;
  fromCharge: boolean; // true = מק"ט שחויב בפועל, false = מק"ט בסיס בלבד
  lastDoc: number;     // מסמך קריאת השירות האחרונה - מדד העדכניות של הרישום
}

interface CustomerEntry {
  at: number;
  devices: Map<string, SerialHit>;
  /**
   * מפתח משני: רק הספרות של הסידורי. פריוריטי מחזיק אצל אותו לקוח גם
   * "2506-340021" וגם "2506-GI340040" - אותה שיטת מספור, עם תחילית אותיות
   * אצל חלק מהרישומים. הלקוח מזין בקובץ את המספר בלבד ("340040"), ולכן בלי
   * המפתח הזה הרישומים עם התחילית לא נמצאים.
   *
   * נכללים כאן רק מספרים שמזהים מכשיר *יחיד* אצל הלקוח. אם שני מכשירים
   * מצטמצמים לאותן ספרות, אין דרך להכריע ביניהם והמפתח נפסל - עדיף בלי
   * התאמה מאשר התאמה שגויה שתגרור מק"ט ומחיר של מכשיר אחר.
   */
  byDigits: Map<string, SerialHit | null>;
  /**
   * מפתח שלישי: רכיב בודד בתוך הסידורי הרשום. פריוריטי מחזיק אצל חלק
   * מהלקוחות סידורי מורכב שמאחד כמה מזהים - "2025-MPL-244(70135180)" הוא
   * מספר הנכס של הלקוח (MPL-244) יחד עם מספר ה-SAP שלו (70135180). בקובץ
   * שהלקוח שולח כל אחד מהם מופיע בעמודה נפרדת, ולכן הצורה המלאה לעולם לא
   * זהה ומפתח הספרות גם הוא לא ("24470135180" מול "244").
   *
   * אותו כלל הכרעה כמו byDigits: רכיב שמתאים ליותר ממכשיר אחד נפסל.
   */
  byPart: Map<string, SerialHit | null>;
}

const cache = new Map<string, CustomerEntry>();
const TTL_MS = 60 * 60 * 1000; // שעה - מכשירים נוספים במהלך היום

/** צורה מנורמלת להשוואה: בלי קידומת לקוח, בלי תווים שאינם אות/ספרה */
export function normalizeSerial(serial: string): string {
  return String(serial || '')
    .toUpperCase()
    .replace(/^\d+\s*-\s*/, '')      // קידומת מספר הלקוח
    .replace(/[^A-Z0-9]/g, '')
    .trim();
}

/** רק הספרות של הסידורי המנורמל - "GI340040" ו-"340040" מצטמצמים לאותו מפתח. */
export function serialDigits(serial: string): string {
  return normalizeSerial(serial).replace(/[^0-9]/g, '');
}

/**
 * המזהים הנפרדים שמרכיבים סידורי מורכב, בצורה מנורמלת.
 * "2025-MPL-244(70135180)" -> ["MPL244", "70135180"]
 *
 * הפיצול הוא על סוגריים / לוכסן / פסיק / רווח בלבד. מקף איננו מפריד: הוא
 * חלק מהמזהה עצמו ("MPL-244"), ופיצול לפיו היה מייצר "MPL" ו-"244" שמתאימים
 * לעשרות מכשירים.
 */
export function serialComponents(serial: string): string[] {
  const body = String(serial || '')
    .toUpperCase()
    .replace(/^\d+\s*-\s*/, '');   // קידומת מספר הלקוח, כמו ב-normalizeSerial
  const parts = body
    .split(/[()[\]{}/\\,;|\s]+/)
    .map(s => s.replace(/[^A-Z0-9]/g, ''))
    .filter(s => s.length >= 3);
  // הצורה המלאה כבר מאונדקסת ב-devices; כאן רק פיצול אמיתי מוסיף מידע
  return parts.length > 1 ? [...new Set(parts)] : [];
}

function customerKey(name: string): string {
  return String(name || '').trim().toLowerCase();
}

/**
 * טוען לזיכרון את המכשירים של הלקוח (כ-100ms ללקוח בינוני).
 * מוחזר מספר המכשירים; 0 אם הלקוח לא זוהה בפריוריטי או שאין לו מכשירים.
 */
export async function ensureCustomerSerials(customerName?: string | null): Promise<number> {
  const key = customerKey(customerName || '');
  if (!key) return 0;
  const cached = cache.get(key);
  if (cached && Date.now() - cached.at < TTL_MS) return cached.devices.size;

  try {
    const cust = await findCustomerId(customerName!);
    if (!cust) { cache.set(key, { at: Date.now(), devices: new Map(), byDigits: new Map(), byPart: new Map() }); return 0; }
    const rows: CustomerDevice[] = await loadCustomerDevices(cust);
    const devices = new Map<string, SerialHit>();
    for (const d of rows) {
      const norm = normalizeSerial(d.serial);
      if (norm.length < 3) continue;   // סידורי קצר מדי - סיכון להתאמת שווא
      const hit: SerialHit = {
        serial: d.serial,
        part: d.chargedPart || d.basePart,
        mbaNum: d.mbaNum,
        model: d.model,
        fromCharge: !!d.chargedPart,
        lastDoc: d.lastDoc,
      };
      // אותו מכשיר רשום בפריוריטי לא פעם פעמיים - "10251-MY63001093" לצד
      // "10251-MY63001093." - ואחרי הנרמול שניהם אותו מפתח. 27 אלף התנגשויות
      // כאלה קיימות במאגר, ולכן ההכרעה חייבת להיות מוגדרת: מנצח הרישום שהכיול
      // האחרון שלו מאוחר יותר, כי הוא המצב הנוכחי של המכשיר. קודם ההכרעה נפלה
      // על סדר השורות מה-SQL, ולכן הוחזר לפעמים מספר מ.ב.א. של כיול ישן.
      // שוויון בעדכניות (למשל שני רישומים בלי היסטוריית קריאות) נשבר לפי
      // שלמות הרשומה: חיוב בפועל שווה יותר ממק"ט בסיס, ומספר מ.ב.א. מוסיף עוד.
      const completeness = (h: SerialHit) => (h.fromCharge ? 2 : 0) + (h.mbaNum ? 1 : 0);
      const better = (a: SerialHit, b: SerialHit) =>
        a.lastDoc !== b.lastDoc ? a.lastDoc > b.lastDoc : completeness(a) > completeness(b);
      const prev = devices.get(norm);
      if (!prev || better(hit, prev)) devices.set(norm, hit);
    }

    // המפתח המשני נבנה מהתוצאה הסופית, אחרי שההתנגשויות על המפתח הראשי כבר
    // הוכרעו. null מסמן מספר ספרות שמתאים ליותר ממכשיר אחד ולכן פסול לחיפוש.
    const byDigits = new Map<string, SerialHit | null>();
    const byPart = new Map<string, SerialHit | null>();
    for (const hit of devices.values()) {
      const digits = serialDigits(hit.serial);
      if (digits.length >= 3) byDigits.set(digits, byDigits.has(digits) ? null : hit);
      for (const comp of serialComponents(hit.serial)) {
        // רכיב שהוא גם סידורי שלם של מכשיר אחר - הרישום השלם גובר, ולכן
        // המפתח נפסל ולא יגנוב את ההתאמה ממנו
        if (devices.has(comp)) { byPart.set(comp, null); continue; }
        byPart.set(comp, byPart.has(comp) ? null : hit);
      }
    }

    cache.set(key, { at: Date.now(), devices, byDigits, byPart });
    console.log(`[pricing] loaded ${devices.size} registered devices for "${customerName}"`);
    return devices.size;
  } catch (err) {
    console.warn('[pricing] could not load the customer devices:', (err as Error).message);
    cache.set(key, { at: Date.now(), devices: new Map(), byDigits: new Map(), byPart: new Map() });
    return 0;
  }
}

/**
 * חיפוש סינכרוני אחרי שה-cache נטען (ensureCustomerSerials).
 * מהחזק לחלש: הצורה המנורמלת המלאה, אחריה רכיב שלם בתוך סידורי מורכב
 * ("MPL-244" בתוך "2025-MPL-244(70135180)"), ולבסוף מפתח הספרות שמכסה
 * רישומים שיש להם תחילית אותיות בפריוריטי אך לא בקובץ של הלקוח.
 */
export function lookupSerial(customerName?: string | null, serial?: string | null): SerialHit | null {
  if (!customerName || !serial) return null;
  const entry = cache.get(customerKey(customerName));
  if (!entry) return null;

  const norm = normalizeSerial(serial);
  if (norm.length < 3) return null;

  const exact = entry.devices.get(norm);
  if (exact) return exact;

  // null = הרכיב מתאים לכמה מכשירים; אין הכרעה, ולכן אין התאמה.
  const byPart = entry.byPart?.get(norm);
  if (byPart) return byPart;
  if (byPart === null) return null;

  const digits = serialDigits(serial);
  if (digits.length < 3) return null;
  const hit = entry.byDigits?.get(digits) ?? null;
  if (!hit) return null;

  // מפתח הספרות נועד למקרה שצד אחד רשם תחילית אותיות והשני לא ("GI340040"
  // מול "340040"), ולכן הוא מתעלם מהאותיות לגמרי. כשיש אותיות בשני הצדדים
  // הן דווקא המזהה: אצל לקוח שמחזיק גם "EQP-130" וגם "MPL-130" שניהם
  // מצטמצמים ל-"130", וההתאמה נפלה על המכשיר האחר - כלומר מק"ט ומחיר של
  // מכשיר שאינו זה שבשורה. אם שני הצדדים סימנו אותיות, הן חייבות להסכים.
  const queryLetters = norm.replace(/[^A-Z]/g, '');
  const hitLetters = normalizeSerial(hit.serial).replace(/[^A-Z]/g, '');
  if (queryLetters && hitLetters && queryLetters !== hitLetters) return null;
  return hit;
}

export function getLoadedSerialCount(customerName?: string | null): number {
  if (!customerName) return 0;
  return cache.get(customerKey(customerName))?.devices.size ?? 0;
}
