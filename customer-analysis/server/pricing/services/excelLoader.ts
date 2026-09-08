import * as XLSX from 'xlsx';
import * as path from 'path';
import * as fs from 'fs';
import { PriceListItem, isValidPartNumber } from '../types';
import { PRICING_DATA_DIR } from '../paths';

// המפתחות כתובים לאחר ניקוי (ללא מרכאות, lower case)
const HEADER_MAP: Record<string, keyof PriceListItem> = {
  'מקט': 'partNumber',
  'partnumber': 'partNumber',
  'part number': 'partNumber',
  'sku': 'partNumber',
  'קוד': 'partNumber',
  'קוד פריט': 'partNumber',
  'מקט פריט': 'partNumber',

  'תיאור': 'description',
  'תאור': 'description',
  'תאור מוצר': 'description',
  'תיאור מוצר': 'description',
  'תאור פריט': 'description',
  'תיאור פריט': 'description',
  'description': 'description',
  'שם המוצר': 'description',
  'שם מוצר': 'description',
  'שם': 'description',
  'name': 'description',

  'יצרן': 'manufacturer',
  'manufacturer': 'manufacturer',
  'יצרנית': 'manufacturer',

  'דגם': 'model',
  'model': 'model',

  'קטגוריה': 'category',
  'category': 'category',
  'משפחה': 'category',

  'מחיר': 'price',
  'price': 'price',

  'מטבע': 'currency',
  'currency': 'currency',

  'יחידה': 'unit',
  'unit': 'unit',
  'יח': 'unit',

  'הערות': 'notes',
  'notes': 'notes',
  'הערה': 'notes',
};

function normalizeHeader(raw: string): keyof PriceListItem | null {
  if (!raw) return null;
  const key = String(raw)
    .replace(/^﻿/, '')           // BOM
    .replace(/["׳״''""]/g, '')         // מרכאות מסוגים שונים
    .trim()
    .toLowerCase();
  return HEADER_MAP[key] ?? null;
}

/**
 * מאתר את שורת הכותרות באקסל - סורק את 20 השורות הראשונות
 * ומחפש את הראשונה שמכילה גם partNumber וגם description.
 * זה מאפשר תמיכה בקבצים עם metadata בתחילתם.
 */
function findHeaderRow(rawRows: unknown[][]): number {
  const scanLimit = Math.min(20, rawRows.length);
  for (let i = 0; i < scanLimit; i++) {
    const row = rawRows[i] || [];
    const mapped = row.map(cell => normalizeHeader(String(cell ?? '')));
    const hasPart = mapped.includes('partNumber');
    const hasDesc = mapped.includes('description');
    if (hasPart && hasDesc) return i;
  }
  return 0; // fallback: שורה ראשונה
}

/**
 * טוען את קובץ האקסל וממפה את העמודות בצורה גמישה לפי כותרות.
 * תומך בקבצים עם שורות metadata בתחילתם - מזהה אוטומטית איפה הכותרות.
 * אם חסרה עמודת מק"ט/תיאור - השורה תידחה.
 */
export function loadPriceList(filePath: string): PriceListItem[] {
  const absolute = path.isAbsolute(filePath)
    ? filePath
    : path.join(PRICING_DATA_DIR, filePath);

  if (!fs.existsSync(absolute)) {
    console.warn(`[pricing] price list file not found: ${absolute}`);
    return [];
  }

  // קוראים את הקובץ ידנית ולא ב-XLSX.readFile: בבנייה ל-ESM ה-API שנוגע
  // במערכת הקבצים לא נחשף (XLSX.readFile הוא undefined), ו-read על buffer
  // עובד זהה בשני המצבים.
  const workbook = XLSX.read(fs.readFileSync(absolute), { type: 'buffer', cellDates: false });
  const sheetName = workbook.SheetNames[0];
  const sheet = workbook.Sheets[sheetName];

  // קריאה גולמית כדי למצוא את שורת הכותרות
  const rawRows = XLSX.utils.sheet_to_json<unknown[]>(sheet, {
    header: 1,
    defval: null,
  });

  if (rawRows.length === 0) return [];

  const headerRowIdx = findHeaderRow(rawRows);
  const headerRow = (rawRows[headerRowIdx] || []) as unknown[];
  const headerStrings = headerRow.map(c => String(c ?? ''));

  console.log(`[pricing] header row detected at row ${headerRowIdx + 1} (${headerStrings.filter(Boolean).length} columns)`);

  // מיפוי אינדקס עמודה → שדה
  const columnMap: Record<number, keyof PriceListItem> = {};
  headerStrings.forEach((h, idx) => {
    const mapped = normalizeHeader(h);
    if (mapped) columnMap[idx] = mapped;
  });

  const items: PriceListItem[] = [];
  for (let i = headerRowIdx + 1; i < rawRows.length; i++) {
    const row = (rawRows[i] || []) as unknown[];
    const item: Partial<PriceListItem> = {};

    for (const [idxStr, mappedField] of Object.entries(columnMap)) {
      const idx = parseInt(idxStr, 10);
      const val = row[idx];
      if (val === null || val === undefined || val === '') continue;
      if (mappedField === 'price') {
        const num = typeof val === 'number'
          ? val
          : parseFloat(String(val).replace(/[^\d.-]/g, ''));
        if (!isNaN(num)) item.price = num;
      } else {
        (item as Record<string, unknown>)[mappedField] = String(val).trim();
      }
    }

    if (item.description && isValidPartNumber(item.partNumber)) {
      items.push(item as PriceListItem);
    }
  }

  console.log(`[pricing] loaded ${items.length} price list items (rows with an invalid part number were dropped)`);
  return items;
}
