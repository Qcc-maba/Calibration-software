export interface PriceListItem {
  partNumber: string;        // מק"ט מ.ב.א. הזורע
  description: string;       // תיאור המוצר
  manufacturer?: string;     // יצרן
  model?: string;            // דגם
  category?: string;         // קטגוריה
  price?: number;            // מחיר
  currency?: string;         // מטבע
  unit?: string;             // יחידת מידה
  notes?: string;            // הערות
}

// מק"ט תקין של מ.ב.א. הזורע: ספרות-ספרות (לדוגמה "130709-0") או רק ספרות
// (לדוגמה "20001" - חוטי תרמוקל). מק"טים עם אותיות (RO6578915, 10BAR) נדחים.
export const VALID_PART_NUMBER_RE = /^\d+(-\d+)?$/;

export function isValidPartNumber(pn: string | undefined | null): boolean {
  if (!pn) return false;
  return VALID_PART_NUMBER_RE.test(String(pn).trim());
}

export interface CustomerProductInput {
  customerDescription: string;  // התיאור שהלקוח הזין
  customerPartNumber?: string;  // מק"ט הלקוח (אופציונלי)
  customerName?: string;       // שם הלקוח (אופציונלי)
  // יצרן / דגם / מאפיינים מהקובץ - מצטרף לשאילתת ההתאמה בלבד, לא למפתח הלמידה
  customerContext?: string;
  // מספר סידורי של המכשיר הפיזי - מוצג ומיוצא, לא משתתף בהתאמה
  customerSerial?: string;
  quantity?: number;
}

export interface PricingResult {
  input: CustomerProductInput;
  matched: PriceListItem | null;                  // המוצר שנמצא (אם נמצא)
  matchType: 'exact' | 'close' | 'weak' | 'none'; // סוג ההתאמה
  matchScore: number;                             // ציון התאמה 0-1 (1 = זהה)
  // מאיפה הגיעה ההתאמה - לשקיפות מול המשתמש
  matchSource?: 'serial' | 'override' | 'partNumber' | 'description' | 'history' | 'fuzzy';
  matchNote?: string;                             // הסבר קצר (למשל: לפי דגם, 157 מכשירים)
  // מספר מ.ב.א. של הכיול האחרון למכשיר הזה (כשההתאמה נעשתה לפי מספר סידורי)
  mbaNumber?: string;
  lastChargedPart?: string;                       // המק"ט שחויב בפועל בכיול האחרון
  alternatives: Array<{ item: PriceListItem; score: number }>; // 3 הצעות נוספות
}
