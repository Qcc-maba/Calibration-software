/**
 * מפענח קובץ אקסל "למידה" שהמשתמש מעלה: זוגות של תיאור-לקוח ↔ מק"ט מ.ב.א.
 * תקין. כל זוג נשמר כ-override קבוע, כך שבעתיד אותו תיאור יותאם אוטומטית
 * למק"ט הנכון (100% ודאות) בלי לעבור דרך המאצ'ר הפזי.
 *
 * זיהוי עמודות:
 *   - עמודת מק"ט מ.ב.א. = העמודה שרוב ערכיה תואמים תבנית מק"ט תקין (ספרות / ספרות-ספרות)
 *   - עמודת תיאור הלקוח = עמודת הטקסט הארוכה ביותר שאיננה עמודת המק"ט
 */
import * as XLSX from 'xlsx';
import { isValidPartNumber } from '../types';

export interface LearningPair {
  description: string;
  partNumber: string;
}

export interface LearningParseResult {
  pairs: LearningPair[];
  detectedColumns: { description: number; partNumber: number };
  totalRows: number;
  skippedRows: number;
  invalidPartNumbers: number;
  headers: string[];
}

function findHeaderRow(rawRows: unknown[][]): number {
  const limit = Math.min(20, rawRows.length);
  for (let i = 0; i < limit; i++) {
    const row = rawRows[i] || [];
    const nonEmpty = row.filter(c => c != null && String(c).trim() !== '').length;
    // שורת כותרות = לפחות 2 תאים, ורובם טקסט (לא מספרים)
    if (nonEmpty >= 2) {
      const textCells = row.filter(c => c != null && isNaN(Number(c)) && String(c).trim() !== '').length;
      if (textCells >= 2) return i;
    }
  }
  return 0;
}

export function parseLearningExcel(buffer: Buffer): LearningParseResult {
  const wb = XLSX.read(buffer, { type: 'buffer' });
  const sheet = wb.Sheets[wb.SheetNames[0]];
  const rawRows = XLSX.utils.sheet_to_json<unknown[]>(sheet, { header: 1, defval: null });

  if (rawRows.length === 0) {
    return {
      pairs: [], detectedColumns: { description: -1, partNumber: -1 },
      totalRows: 0, skippedRows: 0, invalidPartNumbers: 0, headers: [],
    };
  }

  const headerIdx = findHeaderRow(rawRows);
  const headers = (rawRows[headerIdx] || []).map((c, i) => String(c ?? '').trim() || `עמודה ${i + 1}`);
  const dataRows = rawRows.slice(headerIdx + 1);
  const numCols = Math.max(...rawRows.map(r => (r || []).length));

  // זיהוי עמודת מק"ט: העמודה עם הכי הרבה ערכים שתואמים תבנית מק"ט תקין
  const colPartScore = new Array(numCols).fill(0);
  const colTextLen = new Array(numCols).fill(0);
  const colTextCount = new Array(numCols).fill(0);
  for (const row of dataRows) {
    for (let c = 0; c < numCols; c++) {
      const v = row?.[c];
      if (v == null || String(v).trim() === '') continue;
      const s = String(v).trim();
      if (isValidPartNumber(s)) colPartScore[c]++;
      else {
        colTextCount[c]++;
        colTextLen[c] += s.length;
      }
    }
  }

  let partCol = -1, bestPart = 0;
  colPartScore.forEach((score, c) => { if (score > bestPart) { bestPart = score; partCol = c; } });

  // עמודת תיאור = הטקסט הארוך ביותר שאיננה עמודת המק"ט
  let descCol = -1, bestDesc = 0;
  for (let c = 0; c < numCols; c++) {
    if (c === partCol) continue;
    const avgLen = colTextCount[c] > 0 ? colTextLen[c] / colTextCount[c] : 0;
    const score = colTextCount[c] * Math.max(1, avgLen);
    if (score > bestDesc) { bestDesc = score; descCol = c; }
  }

  if (partCol < 0 || descCol < 0) {
    throw new Error(
      `לא הצלחתי לזהות עמודות. צריך עמודת תיאור-לקוח ועמודת מק"ט מ.ב.א. ` +
      `כותרות שנמצאו: ${headers.join(' | ')}`,
    );
  }

  const pairs: LearningPair[] = [];
  let skipped = 0, invalid = 0;
  for (const row of dataRows) {
    const desc = String(row?.[descCol] ?? '').trim();
    const pn = String(row?.[partCol] ?? '').trim();
    if (!desc && !pn) { skipped++; continue; }
    if (!desc || !pn) { skipped++; continue; }
    if (!isValidPartNumber(pn)) { invalid++; continue; }
    pairs.push({ description: desc, partNumber: pn });
  }

  return {
    pairs,
    detectedColumns: { description: descCol, partNumber: partCol },
    totalRows: dataRows.length,
    skippedRows: skipped,
    invalidPartNumbers: invalid,
    headers,
  };
}
