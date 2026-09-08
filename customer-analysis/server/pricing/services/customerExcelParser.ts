import * as XLSX from 'xlsx';
import { CustomerProductInput } from '../types';

const DESCRIPTION_KEYS = [
  'תיאור', 'תאור', 'תאור נוסף', 'תיאור נוסף', 'תאור מוצר', 'תיאור מוצר',
  'תאור פריט', 'תיאור פריט', 'תאור ציוד', 'תיאור ציוד',
  'שם', 'שם המוצר', 'שם מוצר', 'שם פריט', 'שם הציוד', 'שם ציוד',
  'פריט', 'מוצר', 'ציוד',
  'description', 'name', 'item', 'product', 'desc', 'equipment',
];

const PART_NUMBER_KEYS = [
  'מקט', 'מק"ט', 'מק״ט', 'קוד', 'קוד פריט', 'קוד מוצר',
  'מספר', 'מספר ציוד', 'מספר פריט', 'מספר זיהוי', 'מס פריט',
  'מכון נומרי מספר', 'מכון נומרי',
  'partnumber', 'part number', 'part', 'sku', 'code', 'p/n', 'pn', 'id',
];

// מספר סידורי של המכשיר הפיזי - מזהה יחידה, לא מזהה דגם. אסור להשתמש בו
// כמק"ט: הוא לעולם לא יתאים למק"ט מ.ב.א. לגיטימית, אבל *כן* עלול להתנגש
// במקרה (122 מהמק"טים במחירון הם מספרים בני 6 ספרות) ולזכות ב-100% שקרי.
// גם מספר הנכס של הלקוח נכלל כאן. הוא לא "סידורי" במובן היצרן, אבל הוא
// מזהה את אותה יחידה פיזית והוא מה שנרשם אצלנו ב-SERNUMBERS: לקוח שמנהל
// SAP שולח "SAP Number" לצד "Tech ID", ושניהם מופיעים בסידורי הרשום
// ("2025-MPL-244(70135180)"). בלי זה השורות שבהן ה-Tech ID הוא "NA" נופלות
// להתאמה טקסטואלית אף שהמכשיר מוכר לנו.
const SERIAL_KEYS = [
  'מספר סידורי', 'מס סידורי', 'סידורי', 'מספר סריאלי', 'סריאלי',
  'מספר סידורי של היצרן', 'מספר סידורי יצרן', 'שנת ייצור מספר סידורי',
  'מספר נכס', 'מק נכס', 'נכס',
  'serial', 'serial number', 'serial no', 's/n', 'sn', 'serialnumber',
  'sap', 'sap number', 'sap no', 'asset', 'asset number', 'asset no',
  'equipment number', 'equipment no',
];

// כותרות שנראות כמו "מספר" אך הן מונה שורות ולא מק"ט - לעולם לא ייבחרו כעמודת מק"ט
const PART_NUMBER_NEGATIVE_KEYS = [
  'מספר רץ', 'מס רץ', 'מסד', 'מס ד', 'סד', 'שורה', 'מונה', 'מספר שורה',
  'running', 'running number', 'row', 'row number', 'index', 'seq', 'sequence', 'no', '#',
];

// עמודות הקשר: לא משמשות כתיאור בפני עצמן, אך מצטרפות לשאילתת החיפוש
// ("קבל" לבדו חסר הקשר; "קבל MWB 100pF" ניתן להתאמה)
const MANUFACTURER_KEYS = [
  'יצרן', 'שם יצרן', 'שם היצרן', 'יצרן/ספק', 'ספק', 'חברה',
  'manufacturer', 'maker', 'brand', 'make', 'vendor', 'supplier',
];

const MODEL_KEYS = [
  'דגם', 'מודל', 'סוג', 'טיפוס', 'דגם/סוג',
  'model', 'model number', 'type', 'cat no', 'catalog', 'catalogue',
];

const ATTRIBUTE_KEYS = [
  'מאפיינים', 'מאפיין', 'טווח', 'תחום', 'תחום מדידה', 'טווח מדידה', 'מפרט',
  'נתונים טכניים', 'תכונות', 'הערות טכניות',
  'attributes', 'range', 'specs', 'specification', 'measuring range', 'properties',
];

// ערכים שאינם מוסיפים מידע להתאמה
const CONTEXT_NOISE = new Set([
  'אין', 'לא', 'ללא', 'לא ידוע', 'לא רלוונטי', 'לא רלבנטי', 'לא ידועה',
  'none', 'n/a', 'na', 'unknown', 'other', 'אחר',
]);

const CUSTOMER_KEYS = [
  'לקוח', 'שם לקוח', 'שם הלקוח', 'לקוח/פרויקט', 'שם לקוח / פרויקט',
  'customer', 'customer name', 'client', 'client name', 'client/customer',
];

const QUANTITY_KEYS = [
  'כמות', 'יחידות', 'qty', 'quantity', 'amount', 'count',
];

// עמודות תאריך (תאריך הכיול הבא וכד'). אינן מק"ט ואינן כמות, אבל באקסל הן
// מספר שלם ("46053" = תאריך סריאלי) ולכן שני הניחושים לפי תוכן נופלים עליהן.
const DATE_KEYS = [
  'תאריך', 'תאריך כיול', 'תאריך הכיול', 'תאריך כיול הבא', 'תאריך הכיול הבא',
  'כיול הבא', 'תוקף', 'תפוגה', 'תאריך תפוגה',
  'date', 'calibration date', 'next calibration date', 'next calibration',
  'due', 'due date', 'expiry', 'expiry date', 'valid until',
];

/**
 * זיהוי כותרת תאריך ברמת מילה שלמה בלבד - בלי substring, אחרת כל כותרת שמכילה
 * "date" ("Update") הייתה נפסלת.
 */
function isDateHeader(header: string): boolean {
  const n = normalize(header);
  if (!n) return false;
  const words = n.split(/\s+/);
  return DATE_KEYS.some(k => n === k || n.startsWith(k + ' ') || words.includes(k));
}

function normalize(s: string): string {
  return String(s || '')
    .replace(/^﻿/, '')
    .replace(/[\r\n\t]/g, ' ')             // newlines וטאבים → רווח
    .replace(/["׳״''""]/g, '')              // מרכאות
    .replace(/\s+/g, ' ')                   // רווחים מרובים → אחד
    .trim()
    .toLowerCase();
}

/**
 * מאתר עמודה לפי שמות מוכרים, בארבע רמות עדיפות.
 * reject מאפשר לפסול מועמד (למשל עמודת "מספר רץ" שאיננה מק"ט אמיתי).
 */
function findColumn(
  headers: string[],
  candidates: string[],
  reject?: (header: string) => boolean,
): string | null {
  const ok = (h: string) => !reject || !reject(h);
  // עדיפות 1: התאמה מדויקת לחלוטין
  for (const h of headers) {
    const n = normalize(h);
    if (ok(h) && candidates.some(c => n === c)) return h;
  }
  // עדיפות 2: כותרת מתחילה במילת מפתח (למשל "תאור נוסף" מתחיל ב-"תאור")
  for (const h of headers) {
    const n = normalize(h);
    if (ok(h) && candidates.some(c => n.startsWith(c + ' ') || n === c)) return h;
  }
  // עדיפות 3: מילת מפתח שלמה (כמילה נפרדת) מופיעה בכותרת
  for (const h of headers) {
    const n = normalize(h);
    const words = n.split(/\s+/);
    if (ok(h) && candidates.some(c => words.includes(c))) return h;
  }
  // עדיפות 4: substring רחב יותר (כאן עלולים להתפס fasle positives)
  for (const h of headers) {
    const n = normalize(h);
    if (ok(h) && candidates.some(c => c.length >= 4 && (n.includes(c) || c.includes(n)))) return h;
  }
  return null;
}

/** האם הכותרת נשמעת כמו מונה שורות ולא כמו מק"ט */
function isRunningIndexHeader(header: string): boolean {
  const n = normalize(header);
  return PART_NUMBER_NEGATIVE_KEYS.some(k => n === k || n.startsWith(k + ' ') || n.split(/\s+/).includes(k));
}

/**
 * עמודת מק"ט אמיתית חייבת להכיל ערכים שנראים כמו קוד. עמודה שכל ערכיה
 * "אין" / "-" / "לא רלוונטי" (כמו "מספר ארדן" בקבצים צבאיים) אינה מק"ט,
 * והצגתה כ"מק״ט לקוח" רק מטעה.
 */
function looksLikePartNumberColumn(
  rawRows: unknown[][], headerIdx: number, colIdx: number, hidden: Set<number>,
): boolean {
  const values: string[] = [];
  for (let r = headerIdx + 1; r < rawRows.length; r++) {
    if (hidden.has(r)) continue;
    const v = rawRows[r]?.[colIdx];
    const t = String(v ?? '').trim();
    if (!t || t === '-' || CONTEXT_NOISE.has(normalize(t))) continue;
    values.push(t);
  }
  if (values.length === 0) return false;
  const codeLike = values.filter(v => /\d/.test(v) && v.length <= 30).length;
  return codeLike / values.length >= 0.5;
}

/**
 * בדיקת תוכן: עמודה שערכיה מספרים שלמים עולים (1,2,3...) היא מונה שורות,
 * גם אם הכותרת שלה נשמעת תמימה. מונע בחירת "מספר רץ" כמק"ט הלקוח.
 */
function isRunningIndexColumn(
  rawRows: unknown[][], headerIdx: number, colIdx: number, hidden: Set<number>,
): boolean {
  const values: number[] = [];
  for (let r = headerIdx + 1; r < rawRows.length; r++) {
    if (hidden.has(r)) continue;
    const v = rawRows[r]?.[colIdx];
    if (v === null || v === undefined || String(v).trim() === '') continue;
    const s = String(v).trim();
    if (!/^\d+$/.test(s)) return false;   // ערך לא-מספרי אחד מספיק כדי לפסול
    values.push(parseInt(s, 10));
  }
  if (values.length < 3) return false;
  if (values[0] > 2) return false;         // מונה מתחיל ב-0 או ב-1
  for (let i = 1; i < values.length; i++) {
    if (values[i] <= values[i - 1]) return false;  // חייב להיות עולה ממש
    if (values[i] - values[i - 1] > 2) return false; // ובקפיצות קטנות
  }
  return true;
}

export interface ParseResult {
  items: CustomerProductInput[];
  detectedColumns: {
    description: string | null;
    partNumber: string | null;
    /** מספר סידורי של המכשיר - לתצוגה בלבד, לא משמש להתאמה */
    serial: string | null;
    quantity: string | null;
    // עמודות הקשר שמצטרפות לשאילתת ההתאמה
    manufacturer: string | null;
    model: string | null;
    attributes: string | null;
  };
  totalRows: number;
  skippedRows: number;
  /** שורות שזוהו ככותרות קטגוריה בתוך הטבלה (תיאור בלבד, שאר העמודות ריקות) */
  sectionHeaderRows: number;
  /** שורות שהוסתרו בגיליון ולכן לא תומחרו */
  hiddenRows: number;
  allHeaders: string[];
  headerRowIndex: number;
  sheetName: string;
  preview?: string[][]; // 3 שורות ראשונות לעזרה לדיבאג
}

/**
 * סורק את N השורות הראשונות ומוצא את שורת הכותרות המסתברת:
 * זו שמכילה כמה ערכי טקסט קצרים (כותרות) ושמכילה לפחות עמודה אחת
 * שתואמת תיאור / מק"ט מתוך הרשימות הידועות.
 */
/**
 * האם כותרת נתונה מייצגת אחת ממילות המפתח - באותם כללים של findColumn:
 * זהות, תחילית, מילה שלמה, ורק למילות מפתח בנות 4 תווים ומעלה גם substring.
 *
 * הסייג האחרון הוא העיקר: חיפוש substring חופשי הפך כל טקסט שמכיל צירוף בן
 * שתי אותיות לכותרת. "PNEUMATIC CRIMP TOOL" מכיל "pn", ולכן שורת נתונים
 * הוכתרה כשורת הכותרות - הכותרות האמיתיות (ובהן "Serial Number") נזרקו,
 * ואיתן היכולת להתאים לפי מספר סידורי ולהחזיר מספרי מ.ב.א.
 */
function matchesKey(header: string, candidates: string[]): boolean {
  const n = normalize(header);
  if (!n) return false;
  const words = n.split(/\s+/);
  return candidates.some(c =>
    n === c ||
    n.startsWith(c + ' ') ||
    words.includes(c) ||
    (c.length >= 4 && (n.includes(c) || c.includes(n))),
  );
}

/**
 * שורת הכותרות היא הראשונה שמזכירה עמודה מוכרת כלשהי - לא רק תיאור או מק"ט.
 * קובץ שכל מה שמסומן בו הוא "Serial Number" הוא עדיין קובץ עם כותרות, וזיהוי
 * העמודה הזו הוא מה שמאפשר את ההתאמה החזקה ביותר שיש (מכשיר רשום).
 */
function findHeaderRow(rawRows: unknown[][]): number {
  const PRIMARY_KEYS = [...DESCRIPTION_KEYS, ...PART_NUMBER_KEYS];
  const SECONDARY_KEYS = [
    ...SERIAL_KEYS, ...QUANTITY_KEYS, ...MANUFACTURER_KEYS, ...MODEL_KEYS, ...CUSTOMER_KEYS,
  ];
  const scanLimit = Math.min(20, rawRows.length);
  for (let i = 0; i < scanLimit; i++) {
    const row = rawRows[i] || [];
    const cells = row.map(c => String(c ?? '').trim()).filter(Boolean);
    if (cells.length < 1) continue;
    if (cells.some(c => matchesKey(c, PRIMARY_KEYS))) return i;
    // כותרת משנית מספיקה רק כששמות לפחות שתי עמודות. שורת כותרת אמיתית עושה
    // זאת; שורת מטא-דאטה בודדת בראש הקובץ ("רשימת ציוד, תאריך 1/1/26") לא.
    if (cells.length >= 2 && cells.some(c => matchesKey(c, SECONDARY_KEYS))) return i;
  }
  return 0;
}

/**
 * Fallback: אם לא הצלחנו לזהות עמודות לפי שמות הכותרת,
 * ננחש לפי תוכן - עמודה עם רוב טקסט = description,
 * עמודה עם רוב מספרים = quantity.
 */
function inferColumnsByContent(
  rawRows: unknown[][],
  headerIdx: number,
  headers: string[],
  // עמודות שכבר זוהו לפי שם הכותרת (סידורי, לקוח, יצרן...). בלי זה הניחוש
  // לפי תוכן חוטף אותן בחזרה - עמודת סידורי מספרית נראית בדיוק כמו כמות.
  claimed: Set<number> = new Set(),
  hidden: Set<number> = new Set(),
): { description: string | null; partNumber: string | null; quantity: string | null } {
  const numCols = headers.length;
  const stats = new Array(numCols).fill(null).map(() => ({
    numeric: 0,
    text: 0,
    avgLength: 0,
    samples: 0,
  }));

  for (let r = headerIdx + 1; r < Math.min(rawRows.length, headerIdx + 30); r++) {
    if (hidden.has(r)) continue;
    const row = rawRows[r] || [];
    for (let c = 0; c < numCols; c++) {
      const val = row[c];
      if (val === null || val === undefined || val === '') continue;
      const s = String(val).trim();
      stats[c].samples++;
      if (/^-?\d+(\.\d+)?$/.test(s)) stats[c].numeric++;
      else {
        stats[c].text++;
        stats[c].avgLength += s.length;
      }
    }
  }
  stats.forEach(s => { s.avgLength = s.text > 0 ? s.avgLength / s.text : 0; });

  // הכי טקסט וארוך = description
  let bestDescIdx = -1;
  let bestDescScore = 0;
  stats.forEach((s, i) => {
    if (claimed.has(i)) return;
    const score = s.text * (s.avgLength > 10 ? 2 : 1);
    if (score > bestDescScore) { bestDescScore = score; bestDescIdx = i; }
  });

  // עמודה עם כל ערכים מספריים קצרים = quantity (אם יש).
  // "מספרי" לבדו לא מספיק: עמודת תאריך באקסל היא מספר (46053 = תאריך סריאלי),
  // וכשהיא נבחרה ככמות כל שורה קיבלה כמות בת חמש ספרות. כמות אמיתית היא מספר
  // שלם קטן, ולכן נדרש שרוב הערכים ייראו כך.
  const plausibleQty = (v: unknown) => {
    const n = Number(String(v ?? '').trim());
    return Number.isInteger(n) && n > 0 && n <= 10000;
  };
  let qtyIdx = -1;
  stats.forEach((s, i) => {
    if (claimed.has(i) || i === bestDescIdx || qtyIdx !== -1) return;
    if (!(s.numeric > 0 && s.numeric > s.text && s.samples >= 3)) return;
    let plausible = 0;
    for (let r = headerIdx + 1; r < Math.min(rawRows.length, headerIdx + 30); r++) {
      if (hidden.has(r)) continue;
      const v = rawRows[r]?.[i];
      if (v === null || v === undefined || v === '') continue;
      if (plausibleQty(v)) plausible++;
    }
    if (plausible * 2 >= s.samples) qtyIdx = i;
  });

  // עמודה עם דפוסי קוד (מערב אותיות ומקפים) = partNumber
  let pnIdx = -1;
  for (let c = 0; c < numCols; c++) {
    if (claimed.has(c) || c === bestDescIdx || c === qtyIdx) continue;
    let codeMatches = 0;
    for (let r = headerIdx + 1; r < Math.min(rawRows.length, headerIdx + 30); r++) {
      if (hidden.has(r)) continue;
      const v = rawRows[r]?.[c];
      if (v == null) continue;
      const s = String(v).trim();
      if (/^[\w-]{3,}$/.test(s) && s.length < 25) codeMatches++;
    }
    if (codeMatches >= 3) { pnIdx = c; break; }
  }

  return {
    description: bestDescIdx >= 0 ? headers[bestDescIdx] || `עמודה ${bestDescIdx + 1}` : null,
    partNumber: pnIdx >= 0 ? headers[pnIdx] || `עמודה ${pnIdx + 1}` : null,
    quantity: qtyIdx >= 0 ? headers[qtyIdx] || `עמודה ${qtyIdx + 1}` : null,
  };
}

/**
 * קורא קובץ אקסל של לקוח ומזהה אוטומטית את העמודות.
 * - מדלג על שורות metadata בראש
 * - מזהה כותרות לפי שמות מוכרים, או לפי תוכן אם השמות לא תואמים
 * - דורש לפחות עמודת תיאור או מק"ט
 */
export function parseCustomerExcel(buffer: Buffer): ParseResult {
  // cellStyles נדרש כדי ש-sheet['!rows'] יאוכלס - שם מסומנות השורות המוסתרות
  const wb = XLSX.read(buffer, { type: 'buffer', cellStyles: true });
  const sheetName = wb.SheetNames[0];
  const sheet = wb.Sheets[sheetName];
  const rawRows = XLSX.utils.sheet_to_json<unknown[]>(sheet, { header: 1, defval: null });

  // שורה שהלקוח הסתיר בגיליון אינה חלק מהרשימה שהוא רואה: זו הדרך המקובלת
  // לומר "הפריט הזה לא בסבב הנוכחי" בלי למחוק אותו. תמחור שלה מחזיר ללקוח
  // שורות שאין להן זכר בטבלה שהוא שלח - ולכן מדלגים עליה.
  // אינדקסי '!rows' הם מוחלטים בגיליון, בעוד rawRows מתחיל בתחילת ה-range.
  const hiddenRowIdx = new Set<number>();
  {
    const rowOffset = sheet['!ref'] ? XLSX.utils.decode_range(sheet['!ref']).s.r : 0;
    const rowProps = sheet['!rows'] as Array<{ hidden?: boolean } | undefined> | undefined;
    rowProps?.forEach((rp, i) => {
      if (rp?.hidden) hiddenRowIdx.add(i - rowOffset);
    });
  }

  if (rawRows.length === 0) {
    return {
      items: [],
      detectedColumns: {
        description: null, partNumber: null, serial: null, quantity: null,
        manufacturer: null, model: null, attributes: null,
      },
      totalRows: 0,
      skippedRows: 0,
      sectionHeaderRows: 0,
      hiddenRows: 0,
      allHeaders: [],
      headerRowIndex: 0,
      sheetName,
    };
  }

  const headerRowIdx = findHeaderRow(rawRows);
  const headerRow = (rawRows[headerRowIdx] || []) as unknown[];
  const headers = headerRow.map((c, i) => String(c ?? '').trim() || `עמודה ${i + 1}`);

  // גיליון שכל שורות הנתונים שבו מוסתרות (קרה כשמסתירים הכול ומסננים ידנית,
  // או כשהקובץ נשמר עם פילטר פעיל שהסתיר את כל השורות) - עדיף לתמחר את כולן
  // מאשר להחזיר ללקוח תשובה ריקה.
  {
    let visibleDataRows = 0;
    for (let r = headerRowIdx + 1; r < rawRows.length; r++) {
      if (hiddenRowIdx.has(r)) continue;
      const row = (rawRows[r] || []) as unknown[];
      if (row.some(v => v !== null && v !== undefined && String(v).trim() !== '')) visibleDataRows++;
    }
    if (visibleDataRows === 0) hiddenRowIdx.clear();
  }

  const preview = rawRows.slice(0, Math.min(5, rawRows.length))
    .map(r => (r || []).map(c => String(c ?? '').slice(0, 50)));

  let descCol = findColumn(headers, DESCRIPTION_KEYS);
  const serialCol = findColumn(headers, SERIAL_KEYS);
  // עמודת מק"ט: פוסלים מונה שורות (לפי כותרת ולפי תוכן) ואת עמודת המספר הסידורי
  let pnCol = findColumn(headers, PART_NUMBER_KEYS, h =>
    h === serialCol
    || isDateHeader(h)
    || isRunningIndexHeader(h)
    || isRunningIndexColumn(rawRows, headerRowIdx, headers.indexOf(h), hiddenRowIdx)
    || !looksLikePartNumberColumn(rawRows, headerRowIdx, headers.indexOf(h), hiddenRowIdx),
  );
  const custCol = findColumn(headers, CUSTOMER_KEYS);
  let qtyCol = findColumn(headers, QUANTITY_KEYS);
  // עמודות הקשר - לא חובה, משפרות משמעותית את ההתאמה
  const manuCol = findColumn(headers, MANUFACTURER_KEYS);
  const modelCol = findColumn(headers, MODEL_KEYS);
  const attrCol = findColumn(headers, ATTRIBUTE_KEYS);

  // Fallback - ניחוש לפי תוכן, בלי לגעת בעמודות שכבר זוהו לפי שם
  if (!descCol && !pnCol) {
    const claimed = new Set(
      [serialCol, custCol, manuCol, modelCol, attrCol, qtyCol]
        .filter((h): h is string => !!h)
        .map(h => headers.indexOf(h)),
    );
    headers.forEach((h, i) => { if (isDateHeader(h)) claimed.add(i); });
    const inferred = inferColumnsByContent(rawRows, headerRowIdx, headers, claimed, hiddenRowIdx);
    descCol = inferred.description;
    pnCol = inferred.partNumber;
    qtyCol = qtyCol || inferred.quantity;
  }

  if (!descCol && !pnCol) {
    throw new Error(
      `לא הצלחתי לזהות עמודות תיאור או מק"ט בקובץ. ` +
      `כותרות בשורה ${headerRowIdx + 1}: ${headers.filter(Boolean).join(' | ')}`,
    );
  }

  const descIdx = descCol ? headers.indexOf(descCol) : -1;
  const pnIdx = pnCol ? headers.indexOf(pnCol) : -1;
  const custIdx = custCol ? headers.indexOf(custCol) : -1;
  const qtyIdx = qtyCol ? headers.indexOf(qtyCol) : -1;
  const serialIdx = serialCol ? headers.indexOf(serialCol) : -1;
  const manuIdx = manuCol ? headers.indexOf(manuCol) : -1;
  const modelIdx = modelCol ? headers.indexOf(modelCol) : -1;
  const attrIdx = attrCol ? headers.indexOf(attrCol) : -1;

  // כמה עמודות בכלל מכילות נתונים - כדי לזהות שורות שבהן רק התיאור מלא
  const filledColumns = new Set<number>();
  for (let r = headerRowIdx + 1; r < rawRows.length; r++) {
    if (hiddenRowIdx.has(r)) continue;
    const row = (rawRows[r] || []) as unknown[];
    row.forEach((v, c) => {
      if (v !== null && v !== undefined && String(v).trim() !== '') filledColumns.add(c);
    });
  }

  const items: CustomerProductInput[] = [];
  let skipped = 0;
  let sectionHeaderRows = 0;
  let hiddenRows = 0;

  for (let r = headerRowIdx + 1; r < rawRows.length; r++) {
    if (hiddenRowIdx.has(r)) {
      const row = (rawRows[r] || []) as unknown[];
      // שורה מוסתרת שממילא ריקה נספרת כריקה, לא כהסתרה מכוונת
      if (row.some(v => v !== null && v !== undefined && String(v).trim() !== '')) hiddenRows++;
      else skipped++;
      continue;
    }
    const row = (rawRows[r] || []) as unknown[];
    const cell = (i: number): string => {
      const t = i >= 0 ? String(row[i] ?? '').trim() : '';
      return !t || t === '-' || CONTEXT_NOISE.has(normalize(t)) ? '' : t;
    };
    const desc = descIdx >= 0 ? String(row[descIdx] ?? '').trim() : '';
    const pn = cell(pnIdx);
    const serial = cell(serialIdx);
    const customerName = custIdx >= 0 ? String(row[custIdx] ?? '').trim() : '';

    if (!desc && !pn) {
      skipped++;
      continue;
    }

    // שורת כותרת קטגוריה בתוך הטבלה: רק תא התיאור מלא בעוד שבשאר הקובץ
    // יש עוד עמודות נתונים (יצרן, דגם, ת. כיול...). לא פריט אמיתי - לא מתמחרים.
    const nonEmptyCells = row.filter(v => v !== null && v !== undefined && String(v).trim() !== '').length;
    if (desc && !pn && nonEmptyCells === 1 && filledColumns.size >= 3) {
      sectionHeaderRows++;
      continue;
    }

    let qty = 1;
    if (qtyIdx >= 0) {
      const v = row[qtyIdx];
      const n = typeof v === 'number' ? v : parseFloat(String(v));
      if (!isNaN(n) && n > 0) qty = n;
    }

    // הקשר להתאמה: יצרן + דגם + מאפיינים. נשמר בנפרד מהתיאור כדי שמפתח
    // הלמידה (customerDescription) יישאר בדיוק מה שהלקוח כתב.
    const cleanContext = (v: unknown, mustHaveDigit: boolean): string => {
      const t = String(v ?? '').replace(/\s+/g, ' ').trim();
      if (!t || t === '-' || CONTEXT_NOISE.has(normalize(t))) return '';
      // עמודת "מאפיינים" מכילה לעיתים סטטוס ולא מפרט ("יש תעודה בתוקף").
      // מפרט אמיתי כמעט תמיד מכיל מספר ("5 Nm - 25Nm", "100pF").
      if (mustHaveDigit && !/\d/.test(t)) return '';
      return t;
    };
    const context = [
      cleanContext(manuIdx >= 0 ? row[manuIdx] : '', false),
      cleanContext(modelIdx >= 0 ? row[modelIdx] : '', false),
      cleanContext(attrIdx >= 0 ? row[attrIdx] : '', true),
    ].filter(Boolean).join(' ').trim();

    items.push({
      customerDescription: desc || pn,
      customerPartNumber: pn || undefined,
      customerSerial: serial || undefined,
      customerName: customerName || undefined,
      customerContext: context || undefined,
      quantity: qty,
    });
  }

  return {
    items,
    detectedColumns: {
      description: descCol,
      partNumber: pnCol,
      serial: serialCol,
      quantity: qtyCol,
      manufacturer: manuCol,
      model: modelCol,
      attributes: attrCol,
    },
    totalRows: rawRows.length - headerRowIdx - 1,
    skippedRows: skipped,
    sectionHeaderRows,
    hiddenRows,
    allHeaders: headers,
    headerRowIndex: headerRowIdx,
    sheetName,
    preview,
  };
}
