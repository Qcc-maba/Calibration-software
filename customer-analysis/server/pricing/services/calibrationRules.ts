/**
 * חוקי מיקום כיול של מ.ב.א. הזורע:
 *   - כיול פנים (במבא):  מק"ט מסתיים ב- -0 או -1
 *   - כיול חוץ (באתרכם): מק"ט מסתיים ב- -7 או -8
 *
 * חלק מסוגי המוצרים מכוילים *תמיד* בחוץ (באתר הלקוח) כי הם כבדים/נייחים -
 * תנורים, מאזניים, מכונות מתיחה. עבורם, אם המאצ'ר בחר את גרסת הפנים (-0/-1),
 * מחליפים אוטומטית לגרסת החוץ (-7/-8) של אותו מק"ט בסיס.
 *
 * הרשימה נטענת מקובץ data/always-external.json (אם קיים) כדי שאפשר יהיה
 * ללמוד/להרחיב אותה בלי שינוי קוד. אם הקובץ חסר - משתמשים בברירת המחדל.
 */
import * as fs from 'fs';
import * as path from 'path';
import { PriceListItem } from '../types';
import { PRICING_DATA_DIR } from '../paths';

const CONFIG_PATH = path.join(PRICING_DATA_DIR, 'always-external.json');

const DEFAULT_KEYWORDS = ['תנור', 'מאזני', 'מאזניים', 'מכונת מתיחה'];

let alwaysExternalKeywords: string[] = DEFAULT_KEYWORDS;

function load(): void {
  try {
    if (fs.existsSync(CONFIG_PATH)) {
      const parsed = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
      if (Array.isArray(parsed) && parsed.length > 0) {
        alwaysExternalKeywords = parsed.map(String);
      }
    } else {
      // יוצרים קובץ ברירת מחדל כדי שיהיה קל לערוך
      save();
    }
  } catch (err) {
    console.warn('[pricing] could not load always-external.json:', (err as Error).message);
  }
}

function save(): void {
  try {
    const dir = path.dirname(CONFIG_PATH);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(CONFIG_PATH, JSON.stringify(alwaysExternalKeywords, null, 2), 'utf8');
  } catch (err) {
    console.warn('[pricing] could not save always-external.json:', (err as Error).message);
  }
}

load();

export function getAlwaysExternalKeywords(): string[] {
  return [...alwaysExternalKeywords];
}

export function setAlwaysExternalKeywords(keywords: string[]): void {
  alwaysExternalKeywords = [...new Set(keywords.map(s => String(s).trim()).filter(Boolean))];
  save();
}

export function addAlwaysExternalKeywords(keywords: string[]): number {
  const before = alwaysExternalKeywords.length;
  const merged = new Set(alwaysExternalKeywords);
  for (const k of keywords) {
    const clean = String(k).trim();
    if (clean) merged.add(clean);
  }
  alwaysExternalKeywords = [...merged];
  save();
  return alwaysExternalKeywords.length - before;
}

/** האם תיאור שייך לקטגוריה שתמיד מכוילת בחוץ */
export function isAlwaysExternal(description: string): boolean {
  const d = String(description || '');
  return alwaysExternalKeywords.some(k => d.includes(k));
}

/** סיומת המק"ט: 'internal' (-0/-1), 'external' (-7/-8), או null */
export function calibrationLocation(partNumber: string): 'internal' | 'external' | null {
  const m = String(partNumber || '').match(/-(\d+)$/);
  if (!m) return null;
  const suffix = m[1];
  if (suffix === '0' || suffix === '1') return 'internal';
  if (suffix === '7' || suffix === '8') return 'external';
  return null;
}

/**
 * אם הפריט שייך לקטגוריה "תמיד בחוץ" אך נבחרה גרסת הפנים (-0/-1) -
 * מחזיר את פריט החוץ המקביל (אותו בסיס, -7/-8). אחרת null.
 */
export function externalVariant(
  item: PriceListItem,
  lookup: (partNumber: string) => PriceListItem | null,
): PriceListItem | null {
  if (!isAlwaysExternal(item.description)) return null;
  if (calibrationLocation(item.partNumber) !== 'internal') return null;
  const base = item.partNumber.replace(/-(\d+)$/, '');
  return lookup(`${base}-7`) ?? lookup(`${base}-8`) ?? null;
}
