/**
 * אינדקס "דגם → מק"ט מ.ב.א." הנבנה מהיסטוריית הכיולים בפריוריטי.
 *
 * הרעיון: כשלקוח כותב "Power Supply" זה עמום, אבל כשהוא כותב גם "E36154A"
 * זה חד-משמעי - מ.ב.א. כבר כיילה 157 מכשירים כאלה וחייבה עליהם 170312-7.
 * זו ראיה חזקה בהרבה מהתאמת טקסט מול תיאורי המחירון.
 *
 * האינדקס נטען פעם אחת לזיכרון (~65 אלף שורות, כשנייה) ומתרענן לפי TTL.
 * אם פריוריטי לא זמין - האינדקס פשוט ריק וההתאמה ממשיכה כרגיל.
 */
import { loadModelPartStats } from './priorityDb';

export interface ModelCandidate {
  part: string;   // מק"ט מ.ב.א. כפי שחויב בפועל
  n: number;      // כמה מכשירים מהדגם הזה חויבו כך
}

export interface ModelHit {
  model: string;            // הדגם שזוהה בטקסט
  candidates: ModelCandidate[]; // ממוין מהנפוץ לנדיר
  total: number;            // סה"כ מכשירים מהדגם
  share: number;            // חלקו של המועמד המוביל
}

let index: Map<string, { display: string; candidates: ModelCandidate[]; total: number }> = new Map();
let loadedAt = 0;
let loading: Promise<void> | null = null;
const TTL_MS = 12 * 60 * 60 * 1000; // האינדקס משתנה לאט - רענון פעמיים ביום

function normalizeModel(s: string): string {
  return String(s || '')
    .toLowerCase()
    .replace(/["'`״׳]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * דגם "מועמד" חייב להיות מספיק מבחין: מכיל ספרה, או מחרוזת ארוכה.
 * מונע התאמה על מילים כלליות שבמקרה רשומות כדגם ("NEW", "סט").
 */
function isDiscriminative(candidate: string): boolean {
  if (candidate.length < 3) return false;
  const hasDigit = /\d/.test(candidate);
  if (/^\d+$/.test(candidate)) return candidate.length >= 4; // מספר בלבד - דורש 4 ספרות
  return hasDigit || candidate.length >= 6;
}

export async function buildModelIndex(force = false): Promise<number> {
  if (!force && index.size > 0 && Date.now() - loadedAt < TTL_MS) return index.size;
  if (loading) { await loading; return index.size; }
  loading = (async () => {
    try {
      const rows = await loadModelPartStats();
      const next = new Map<string, { display: string; candidates: ModelCandidate[]; total: number }>();
      for (const r of rows) {
        const key = normalizeModel(r.model);
        if (!isDiscriminative(key)) continue;
        let entry = next.get(key);
        if (!entry) { entry = { display: r.model, candidates: [], total: 0 }; next.set(key, entry); }
        entry.candidates.push({ part: r.part, n: r.n });
        entry.total += r.n;
      }
      for (const e of next.values()) e.candidates.sort((a, b) => b.n - a.n);
      index = next;
      loadedAt = Date.now();
      console.log(`[pricing] model index loaded from Priority: ${index.size} models`);
    } catch (err) {
      console.warn('[pricing] could not build the model index:', (err as Error).message);
    } finally {
      loading = null;
    }
  })();
  await loading;
  return index.size;
}

export function getModelIndexSize(): number {
  return index.size;
}

/**
 * מחפש דגם מוכר בתוך טקסט חופשי ("KEYSIGHT E36154A" → "e36154a").
 * בודק צירופים של 1-4 מילים ומעדיף את הצירוף הארוך ביותר שנמצא -
 * "EA-PS 2042-20B" עדיף על "2042-20b" לבדו.
 */
export function lookupModel(text?: string | null): ModelHit | null {
  if (!text || index.size === 0) return null;
  const tokens = normalizeModel(text).split(' ').filter(Boolean);
  if (tokens.length === 0) return null;

  let best: { key: string; len: number; entry: { display: string; candidates: ModelCandidate[]; total: number } } | null = null;
  for (let size = Math.min(4, tokens.length); size >= 1; size--) {
    for (let i = 0; i + size <= tokens.length; i++) {
      const candidate = tokens.slice(i, i + size).join(' ');
      if (!isDiscriminative(candidate)) continue;
      const entry = index.get(candidate);
      if (!entry) continue;
      // צירוף ארוך יותר = ספציפי יותר; בשוויון - זה עם יותר היסטוריה
      if (!best || size > best.len || (size === best.len && entry.total > best.entry.total)) {
        best = { key: candidate, len: size, entry };
      }
    }
    if (best) break; // נמצא בגודל הזה - אין טעם לרדת לצירופים קצרים יותר
  }
  if (!best) return null;

  return {
    model: best.entry.display,
    candidates: best.entry.candidates,
    total: best.entry.total,
    share: best.entry.candidates[0].n / best.entry.total,
  };
}
