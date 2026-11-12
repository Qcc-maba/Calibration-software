/**
 * התאמה לפי מספר סידורי - הראיה החזקה ביותר שיש.
 *
 * אם הלקוח כבר כייל אצלנו את המכשיר הזה, אין צורך לנחש כלום: המכשיר רשום
 * ב-SERNUMBERS עם המק"ט שחויב בפועל בכיול האחרון (כולל ההחלטה פנים/חוץ)
 * ועם מספר מ.ב.א. של המסמך.
 *
 * הסידורי נשמר במ.ב.א. עם קידומת מספר הלקוח ("10251-MY63001116"), ולעיתים
 * עם נקודות/מקפים נוספים, ולכן ההשוואה מתבצעת על צורה מנורמלת.
 *
 * שני הצדדים של ההשוואה אינם סימטריים, וזה העיקר כאן: הצורה שבפריוריטי נושאת
 * קידומת לקוח שצריך להסיר, והצורה שהלקוח הקליד איננה. נרמול זהה לשני הצדדים
 * הוא בדיוק מה שגרם לכך ש-34 שורות אצל לקוח 1343 חזרו בלי מספר מ.ב.א. אף
 * שהמכשיר רשום (MBA-1027), ולכן יש כאן שתי פונקציות נרמול ולא אחת.
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

/**
 * איך ההתאמה נמצאה. 'typo' הוא היחיד שאיננו ודאי: הסידורי שהלקוח כתב איננו
 * זהה לזה שרשום אצלנו אלא רחוק ממנו תו או שניים, ולכן הוא מדווח כהתאמה קרובה
 * עם ציון מופחת ולא כהתאמה מדויקת.
 */
export type SerialMatchVia = 'exact' | 'component' | 'digits' | 'typo';

export interface SerialMatch {
  hit: SerialHit;
  via: SerialMatchVia;
  edits: number;       // מספר התווים שנבדלים (0 בכל דרך שאיננה 'typo')
  confidence: number;  // 0-1
  note?: string;       // הסבר קצר בעברית, מצטרף להסבר של השורה
}

/**
 * השדות הנוספים של אותה שורה בקובץ הלקוח. משמשים להכרעה בין מועמדים כשהסידורי
 * לבדו איננו מכריע - ולא להתאמה עצמה.
 */
export interface SerialContext {
  description?: string | null;
  context?: string | null;      // יצרן / דגם
  partNumber?: string | null;   // מק"ט הלקוח
}

interface CustomerEntry {
  at: number;
  devices: Map<string, SerialHit>;
  /**
   * מפתח משני: רק הספרות של הסידורי, בלי אפסים מובילים. פריוריטי מחזיק אצל
   * אותו לקוח גם "2506-340021" וגם "2506-GI340040" - אותה שיטת מספור, עם
   * תחילית אותיות אצל חלק מהרישומים. הלקוח מזין בקובץ את המספר בלבד
   * ("340040"), ולכן בלי המפתח הזה הרישומים עם התחילית לא נמצאים.
   *
   * האפסים המובילים מוסרים משני הצדדים כי פריוריטי מרפד אותם והלקוח לא:
   * "2227-070418343" מול "70418343" בקובץ. בלי ההסרה מפתח הספרות - שכל תפקידו
   * לגשר על הפרשי כתיב - דווקא פספס את הרישום.
   *
   * כאן נשמרים *כל* המועמדים ולא רק מועמד יחיד: הסרת האפסים מגדילה את מספר
   * ההתנגשויות, וההכרעה ביניהן נעשית בזמן החיפוש לפי הדגם והמק"ט של השורה.
   */
  byDigits: Map<string, SerialHit[]>;
  /**
   * מפתח שלישי: רכיב בודד בתוך הסידורי. פריוריטי מחזיק אצל חלק מהלקוחות
   * סידורי מורכב שמאחד כמה מזהים - "2025-MPL-244(70135180)" הוא מספר הנכס של
   * הלקוח (MPL-244) יחד עם מספר ה-SAP שלו (70135180). בקובץ שהלקוח שולח כל
   * אחד מהם מופיע בעמודה נפרדת, ולכן הצורה המלאה לעולם לא זהה ומפתח הספרות גם
   * הוא לא ("24470135180" מול "244").
   *
   * הפיצול חל על שני הצדדים: גם הלקוח כותב לפעמים סידורי מורכב
   * ("91610262 / 3090") ששני חלקיו רשומים אצלנו כשני מכשירים נפרדים.
   */
  byPart: Map<string, SerialHit[]>;
  /** מפתחות devices, לשלב סטיית התו. נשמר כמערך כדי לא לבנותו מחדש בכל שורה. */
  keys: string[];
}

const cache = new Map<string, CustomerEntry>();
const TTL_MS = 60 * 60 * 1000; // שעה - מכשירים נוספים במהלך היום

/** אורך מינימלי שבו סטייה של תו בודד עדיין אומרת משהו. מתחת לזה כל סידורי דומה לכל סידורי. */
const MIN_LEN_FOR_TYPO = 5;
/** מרחק עריכה מקסימלי שנבדק בכלל. */
const MAX_EDITS = 2;
/**
 * תו אחד איננו סידורי. רצפת האורך הוסרה מבניית האינדקס כדי לא להשמיט מכשירים
 * בעלי סידורי קצר, ולכן היא נדרשת כאן: בלעדיה ערך כמו "1" בשורה היה מתאים
 * במדויק למכשיר שרשום כ-"2227-1" וגורר את המק"ט והמחיר שלו.
 */
const MIN_QUERY_LEN = 2;
/**
 * המק"ט של הלקוח הוא מזהה חלופי חלש, שנבדק רק כשאין סידורי מפורש. ערך קצר
 * בעמודה הזאת הוא כמעט תמיד כמות או מספר שורה ("1"), ולא מזהה מכשיר, ולכן
 * הרצפה שלו גבוהה יותר.
 */
export const MIN_FALLBACK_LEN = 3;

/**
 * צורה מנורמלת של מה שהלקוח הקליד: אותיות גדולות, בלי תווים שאינם אות/ספרה.
 *
 * אין כאן הסרת קידומת: המספר שהלקוח כתב הוא הסידורי כולו. "0439-2" הוא סידורי
 * שלם, וכך גם "9452-7" - הסרת "0439-" הותירה "2", שנפסל כקצר מדי, והשורה חזרה
 * בלי מספר מ.ב.א. אף שהמכשיר רשום כ-"2227-0439-2".
 */
export function normalizeSerial(serial: string): string {
  return String(serial || '')
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '')
    .trim();
}

/**
 * צורה מנורמלת של הסידורי כפי שהוא נשמר בפריוריטי: כאן *כן* מוסרת קידומת מספר
 * הלקוח, כי SERNUM הוא "<קוד לקוח>-<סידורי>".
 */
export function normalizeStoredSerial(serial: string): string {
  return normalizeSerial(
    String(serial || '')
      .toUpperCase()
      .replace(/^\d+\s*-\s*/, ''),   // קידומת מספר הלקוח
  );
}

/**
 * מפתח הספרות של צורה שכבר נורמלה - בלי אפסים מובילים.
 * "070418343" ו-"70418343" מצטמצמים לאותו מפתח, וכך גם "GI340040" ו-"340040".
 */
export function serialDigitsKey(normalized: string): string {
  return normalized.replace(/[^0-9]/g, '').replace(/^0+/, '');
}

/** מפתח הספרות ישירות מערך גולמי שהלקוח הקליד. */
export function serialDigits(serial: string): string {
  return serialDigitsKey(normalizeSerial(serial));
}

/**
 * המזהים הנפרדים שמרכיבים סידורי מורכב, בצורה מנורמלת.
 * "2025-MPL-244(70135180)" -> ["MPL244", "70135180"]
 *
 * הפיצול הוא על סוגריים / לוכסן / פסיק / רווח בלבד. מקף איננו מפריד: הוא חלק
 * מהמזהה עצמו ("MPL-244"), ופיצול לפיו היה מייצר "MPL" ו-"244" שמתאימים
 * לעשרות מכשירים. (\s ב-JS כולל רווח קשיח, שמופיע בקבצים שיוצאו מ-Excel.)
 *
 * stripPrefix נכון רק לצד של פריוריטי. בצד של הלקוח קידומת מספרית היא חלק
 * מהמזהה, כמו ב-normalizeSerial.
 */
export function serialComponents(serial: string, stripPrefix = false): string[] {
  let body = String(serial || '').toUpperCase();
  if (stripPrefix) body = body.replace(/^\d+\s*-\s*/, '');
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

const completeness = (h: SerialHit) => (h.fromCharge ? 2 : 0) + (h.mbaNum ? 1 : 0);
/** מי מהרישומים מתאר את המצב הנוכחי של המכשיר: הכיול המאוחר, ואז הרשומה השלמה. */
const better = (a: SerialHit, b: SerialHit) =>
  a.lastDoc !== b.lastDoc ? a.lastDoc > b.lastDoc : completeness(a) > completeness(b);

function push(map: Map<string, SerialHit[]>, key: string, hit: SerialHit): void {
  const list = map.get(key);
  if (list) list.push(hit); else map.set(key, [hit]);
}

/** מרחק עריכה (Levenshtein) עם יציאה מוקדמת מעל cap - רוב ההשוואות נחתכות מיד. */
function editDistance(a: string, b: string, cap: number): number {
  if (Math.abs(a.length - b.length) > cap) return cap + 1;
  let prev = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    const cur = new Array<number>(b.length + 1);
    cur[0] = i;
    let rowMin = i;
    for (let j = 1; j <= b.length; j++) {
      cur[j] = Math.min(
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1),
      );
      if (cur[j] < rowMin) rowMin = cur[j];
    }
    if (rowMin > cap) return cap + 1;
    prev = cur;
  }
  return prev[b.length];
}

/** האותיות בלבד - המזהה שמבדיל בין "EQP-130" ל-"MPL-130" אצל אותו לקוח. */
function letters(normalized: string): string {
  return normalized.replace(/[^A-Z]/g, '');
}

/** אסימוני דגם באורך 3 ומעלה, לבדיקת תימוכין. */
function modelTokens(text?: string | null): string[] {
  return String(text || '')
    .toUpperCase()
    .split(/[^A-Z0-9]+/)
    .filter(t => t.length >= 3);
}

/**
 * האם שדה אחר באותה שורה תומך במועמד הזה. מחזיר הסבר קצר, או null.
 * הבדיקה היא על *קלט* השורה בלבד (תיאור, יצרן/דגם, מק"ט לקוח) - לא על תוצאה
 * שההתאמה עצמה הפיקה.
 */
function corroboration(hit: SerialHit, ctx?: SerialContext): string | null {
  if (!ctx) return null;
  const haystack = normalizeSerial(`${ctx.description || ''} ${ctx.context || ''}`);
  if (haystack) {
    for (const token of modelTokens(hit.model)) {
      if (haystack.includes(token)) return `דגם ${token}`;
    }
  }
  const part = normalizeSerial(ctx.partNumber || '');
  if (part && hit.part && normalizeSerial(hit.part) === part) return `מק"ט ${hit.part}`;
  return null;
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

  const empty = (): CustomerEntry =>
    ({ at: Date.now(), devices: new Map(), byDigits: new Map(), byPart: new Map(), keys: [] });

  try {
    const cust = await findCustomerId(customerName!);
    if (!cust) { cache.set(key, empty()); return 0; }
    const rows: CustomerDevice[] = await loadCustomerDevices(cust);
    const devices = new Map<string, SerialHit>();
    for (const d of rows) {
      // אין כאן רצפת אורך. קודם נפסל כל רישום שהסידורי המנורמל שלו קצר מ-3
      // תווים, וכך 23 מ-1,044 המכשירים של לקוח 1343 נעלמו מהאינדקס לגמרי -
      // סידורי "003" או "20" הוא לגיטימי אצל לקוחות שמנהלים מספור משלהם.
      // הסיכון להתאמת שווא נשאר, אבל מקומו בצד החיפוש, שם יש את שדות השורה
      // להכריע לפיהם, ולא בהשמטה שקטה של המכשיר מהאינדקס.
      const norm = normalizeStoredSerial(d.serial);
      if (!norm) continue;
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
      const prev = devices.get(norm);
      if (!prev || better(hit, prev)) devices.set(norm, hit);
    }

    // המפתחות המשניים נבנים מהתוצאה הסופית, אחרי שההתנגשויות על המפתח הראשי
    // כבר הוכרעו. שניהם מחזיקים את כל המועמדים - ההכרעה ביניהם בזמן החיפוש.
    const byDigits = new Map<string, SerialHit[]>();
    const byPart = new Map<string, SerialHit[]>();
    for (const hit of devices.values()) {
      const digits = serialDigitsKey(normalizeStoredSerial(hit.serial));
      if (digits) push(byDigits, digits, hit);
      for (const comp of serialComponents(hit.serial, true)) {
        // רכיב שהוא גם סידורי שלם של מכשיר אחר - הרישום השלם גובר, ולכן הרכיב
        // לא יגנוב ממנו את ההתאמה
        if (devices.has(comp)) continue;
        push(byPart, comp, hit);
      }
    }

    cache.set(key, { at: Date.now(), devices, byDigits, byPart, keys: [...devices.keys()] });
    console.log(`[pricing] loaded ${devices.size} registered devices for "${customerName}"`);
    return devices.size;
  } catch (err) {
    console.warn('[pricing] could not load the customer devices:', (err as Error).message);
    cache.set(key, empty());
    return 0;
  }
}

/**
 * הכרעה בין כמה מועמדים שהגיעו מאותו מפתח.
 *
 * קודם תימוכין משדה אחר של השורה. אם כולם נתמכים או אף אחד לא, נבדק אם מדובר
 * בכלל באותו מכשיר: כמה רישומים של *אותו מק"ט* אינם עמימות אמיתית - המחיר זהה
 * בכל מקרה ורק מספר המסמך שונה, ולכן נבחר הרישום העדכני. זה המצב של
 * "2227-U110213000305" מול "2227-0110213000305", שבגללו שורה אחת קיבלה מספר
 * מ.ב.א. משנת 2013 במקום זה של 2025. מק"טים שונים הם מכשירים שונים, ושם עדיף
 * בלי התאמה מאשר מק"ט ומחיר של מכשיר אחר.
 */
function disambiguate(
  cands: SerialHit[],
  ctx: SerialContext | undefined,
  keyNote: string,
): SerialMatch | null {
  if (cands.length === 1) {
    return { hit: cands[0], via: 'digits', edits: 0, confidence: 1, note: keyNote };
  }
  const supported = cands
    .map(hit => ({ hit, why: corroboration(hit, ctx) }))
    .filter((c): c is { hit: SerialHit; why: string } => !!c.why);
  if (supported.length === 1) {
    return {
      hit: supported[0].hit, via: 'digits', edits: 0, confidence: 1,
      note: `${keyNote}, ${supported[0].why}`,
    };
  }
  const pool = supported.length > 1 ? supported.map(c => c.hit) : cands;
  if (new Set(pool.map(h => h.part)).size === 1) {
    const latest = pool.reduce((a, b) => (better(a, b) ? a : b));
    return {
      hit: latest, via: 'digits', edits: 0, confidence: 1,
      note: `${keyNote}, ${pool.length} רישומים של ${latest.part}`,
    };
  }
  return null;
}

/**
 * חיפוש סינכרוני אחרי שה-cache נטען (ensureCustomerSerials).
 * מהחזק לחלש:
 *   1. הצורה המנורמלת המלאה
 *   2. רכיב שלם בתוך סידורי מורכב, בשני הכיוונים
 *   3. מפתח הספרות, שמכסה תחילית אותיות ואפסי ריפוד בצד אחד בלבד
 *   4. סטייה של תו-שניים מסידורי רשום - רק כמוצא אחרון, ועם ציון מופחת
 */
export function lookupSerial(
  customerName?: string | null,
  serial?: string | null,
  ctx?: SerialContext,
): SerialMatch | null {
  if (!customerName || !serial) return null;
  const entry = cache.get(customerKey(customerName));
  if (!entry) return null;

  const norm = normalizeSerial(serial);
  if (norm.length < MIN_QUERY_LEN) return null;

  const exact = entry.devices.get(norm);
  if (exact) return { hit: exact, via: 'exact', edits: 0, confidence: 1 };

  // הלקוח כתב סידורי מורכב ("91610262 / 3090") ושני חלקיו רשומים אצלנו בנפרד
  const typedParts = serialComponents(serial);
  for (const comp of typedParts) {
    const hit = entry.devices.get(comp);
    if (hit) return { hit, via: 'component', edits: 0, confidence: 1, note: `רכיב ${comp}` };
  }

  const candidateKeys = [norm, ...typedParts];
  for (const candidate of candidateKeys) {
    const bucket = entry.byPart.get(candidate);
    if (!bucket) continue;
    const resolved = disambiguate(bucket, ctx, `רכיב ${candidate}`);
    // הרכיב מתאים לכמה מכשירים שונים - אין הכרעה, ואין טעם לנסות מפתח חלש יותר
    return resolved ? { ...resolved, via: 'component' } : null;
  }

  for (const candidate of candidateKeys) {
    const digits = serialDigitsKey(candidate);
    if (!digits) continue;
    const bucket = entry.byDigits.get(digits);
    if (!bucket) continue;

    // מפתח הספרות נועד למקרה שצד אחד רשם תחילית אותיות והשני לא ("GI340040"
    // מול "340040"), ולכן הוא מתעלם מהאותיות לגמרי. כשיש אותיות בשני הצדדים
    // הן דווקא המזהה: אצל לקוח שמחזיק גם "EQP-130" וגם "MPL-130" שניהם
    // מצטמצמים ל-"130", וההתאמה נפלה על המכשיר האחר - כלומר מק"ט ומחיר של
    // מכשיר שאינו זה שבשורה.
    //
    // כאן האותיות *מסננות* מועמדים במקום לפסול את החיפוש כולו. קודם די היה
    // במועמד אחד שאותיותיו אינן מסכימות כדי להחזיר כלום, וכך אבדו רישומים שרק
    // אות אחת מפרידה בינם ובין מה שהלקוח כתב. אם לא נותר מועמד, שלב סטיית התו
    // ישפוט אותם במפורש - עם תימוכין וציון מופחת.
    const queryLetters = letters(candidate);
    const survivors = queryLetters
      ? bucket.filter(hit => {
          const hitLetters = letters(normalizeStoredSerial(hit.serial));
          return !hitLetters || hitLetters === queryLetters;
        })
      : bucket;
    if (survivors.length === 0) continue;
    return disambiguate(survivors, ctx, `ספרות ${digits}`);
  }

  // מוצא אחרון: הלקוח כתב את הסידורי עם שגיאת תו. "SHHTNC210024" מול
  // "SHHTNCH210024" שרשום אצלנו, או "Al23091201-5" מול "A123091201-5" (L קטנה
  // במקום הספרה 1). תו אחד - הסידורי עצמו כבר ראיה חזקה; שני תווים - נדרש
  // תימוכין משדה אחר של השורה. בשני המקרים ההתאמה מדווחת כקרובה, לא מדויקת,
  // כדי שהציון בעמודת הסטטוס יראה שהיא הוכרעה ולא נמצאה.
  if (norm.length < MIN_LEN_FOR_TYPO) return null;
  let bestEdits = MAX_EDITS + 1;
  let bestKeys: string[] = [];
  for (const key of entry.keys) {
    const edits = editDistance(norm, key, MAX_EDITS);
    if (edits > MAX_EDITS) continue;
    if (edits < bestEdits) { bestEdits = edits; bestKeys = [key]; }
    else if (edits === bestEdits) bestKeys.push(key);
  }
  if (bestKeys.length === 0) return null;

  const cands = bestKeys.map(k => entry.devices.get(k)).filter((h): h is SerialHit => !!h);
  const label = (hit: SerialHit) =>
    `סידורי רשום ${normalizeStoredSerial(hit.serial)} — ${bestEdits === 1 ? 'תו אחד' : 'שני תווים'} שונה`;

  if (cands.length === 1) {
    const hit = cands[0];
    if (bestEdits === 1) return { hit, via: 'typo', edits: 1, confidence: 0.85, note: label(hit) };
    const why = corroboration(hit, ctx);
    return why ? { hit, via: 'typo', edits: 2, confidence: 0.75, note: `${label(hit)}, ${why}` } : null;
  }

  // כמה מועמדים באותו מרחק - רק תימוכין יחיד מכריע
  const supported = cands
    .map(hit => ({ hit, why: corroboration(hit, ctx) }))
    .filter((c): c is { hit: SerialHit; why: string } => !!c.why);
  if (supported.length !== 1) return null;
  const { hit, why } = supported[0];
  return {
    hit, via: 'typo', edits: bestEdits,
    confidence: bestEdits === 1 ? 0.75 : 0.7,
    note: `${label(hit)}, ${why}`,
  };
}

export function getLoadedSerialCount(customerName?: string | null): number {
  if (!customerName) return 0;
  return cache.get(customerKey(customerName))?.devices.size ?? 0;
}
