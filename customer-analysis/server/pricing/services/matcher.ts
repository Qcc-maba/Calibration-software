import Fuse from 'fuse.js';
import { PriceListItem, CustomerProductInput, PricingResult, isValidPartNumber } from '../types';
import { enrichWithTranslations } from './translator';
import { getPreciseOverride, getGenericOverride } from './overrides';
import { externalVariant } from './calibrationRules';
import { lookupModel, ModelHit } from './modelIndex';
import { lookupSerial } from './serialIndex';

let fuseInstance: Fuse<PriceListItem> | null = null;
let cachedItems: PriceListItem[] = [];
let cachedTokens: string[][] = [];                       // טוקנים מנורמלים לכל פריט
let cachedTokenSets: Set<string>[] = [];                 // Set version להתאמה מהירה
let invertedIndex: Map<string, Set<number>> = new Map(); // token → item indices
let partNumberIndex: Map<string, number> = new Map();    // normalized part number → item index
let descriptionIndex: Map<string, number> = new Map();   // normalized description → item index
let idfMap: Map<string, number> = new Map();             // token → IDF (inverse document frequency)

const fuseOptions: ConstructorParameters<typeof Fuse<PriceListItem>>[1] = {
  includeScore: true,
  threshold: 0.8,
  ignoreLocation: true,
  minMatchCharLength: 2,
  keys: [
    { name: 'description', weight: 0.6 },
    { name: 'partNumber', weight: 0.2 },
    { name: 'manufacturer', weight: 0.1 },
    { name: 'model', weight: 0.1 },
  ],
};

function normalize(s: string): string {
  return String(s || '')
    .toLowerCase()
    .replace(/[\r\n\t]/g, ' ')
    .replace(/["׳״''""()\[\]{}]/g, '')
    .replace(/[\-_/.,;:]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

// מילות עצירה שלא יתרמו לציון התאמה (עברית + אנגלית נפוצות)
const STOP_WORDS = new Set([
  'של', 'את', 'עם', 'מן', 'על', 'או', 'גם', 'כן', 'לא', 'כי',
  'the', 'a', 'an', 'of', 'for', 'with', 'and', 'or', 'in', 'to',
]);

function tokenize(s: string): string[] {
  return normalize(s)
    .split(/\s+/)
    .filter(t => t.length >= 2 && !STOP_WORDS.has(t));
}

function itemTokens(item: PriceListItem): string[] {
  const fields = [
    item.description,
    item.partNumber,
    item.manufacturer,
    item.model,
    item.category,
  ].filter(Boolean).join(' ');
  return tokenize(fields);
}

/**
 * ציון התאמת טוקנים: חלק מטוקני הלקוח שמופיעים בפריט (בהתאמה מלאה או חלקית).
 * מילה זהה = 1.0, מילה שמכילה את האחרת = 0.7, מספר/דגם זהה = 1.5 (משקל גבוה).
 */
function structuralWeight(token: string): number {
  const hasDigits = /\d/.test(token);
  const hasLetters = /[a-zA-Zא-ת]/.test(token);
  if (hasDigits && hasLetters) return 1.5;  // מספר דגם (87V, MC6)
  if (hasLetters) return 1.0;
  return 0.3;                                // מספרים טהורים - בדרך כלל מידות
}

function getIdf(token: string, fallback = 1.0): number {
  return idfMap.get(token) ?? fallback;
}


// מילים עבריות גנריות שלא מספיקות לבדן להתאמה (קצרות + נפוצות במחירון).
// תוקנו מהמחירון בפועל: "מד" (gauge) ו"כיול"/"בהסמכה"/"במבא" - מופיעים בעשרות פריטים.
const GENERIC_SHORT_HE = new Set([
  'מד', 'סט', 'יח', 'אם', 'אב', 'בן', 'בת',
  'יום', 'אור', 'חום', 'צבע', 'עבה', 'דק', 'גז',
  'כיול', 'בהסמכה', 'במבא', 'באתרכם',
]);

/**
 * טוקן "מהותי" - שמועיל בלשמש כעוגן להתאמה. כללים:
 *   - אורך 3+ תווים בעברית או באנגלית
 *   - לא מילה גנרית נפוצה במחירון ("מד", "כיול", "אור" וכד')
 *   - או אלפא-נומרי (דגם כמו 87V)
 *
 * "פין" (3 תווים, לא גנרי) נחשב מהותי. "מד" (2 תווים, גנרי) לא.
 */
function isSubstantive(token: string): boolean {
  if (GENERIC_SHORT_HE.has(token)) return false;
  if (token.length >= 3) return true;
  const hasDigit = /\d/.test(token);
  const hasLetter = /[a-zA-Zא-ת]/.test(token);
  return hasDigit && hasLetter;
}

/**
 * ציון התאמת טוקנים משולב IDF + משקל מבני:
 * - מילה נדירה במחירון תורמת יותר ממילה נפוצה (TF-IDF)
 * - דגמים אלפא-נומריים מקבלים boost
 * - התאמה חלקית (substring) מקבלת 70%
 * מחזיר גם את מספר הטוקנים שהותאמו ואם יש לפחות התאמה מהותית אחת
 * (לסינון התאמות-מילה-בודדת ומילים-קצרות-בלבד).
 */
function tokenOverlapScore(
  queryTokens: string[],
  targetTokens: string[],
): { score: number; matches: number; substantiveMatches: number } {
  if (queryTokens.length === 0) return { score: 0, matches: 0, substantiveMatches: 0 };
  const targetSet = new Set(targetTokens);
  let total = 0;
  let maxPossible = 0;
  let matches = 0;
  let substantiveMatches = 0;

  for (const q of queryTokens) {
    const weight = structuralWeight(q) * getIdf(q);
    maxPossible += weight;

    if (targetSet.has(q)) {
      total += weight;
      matches++;
      if (isSubstantive(q)) substantiveMatches++;
      continue;
    }
    // התאמה חלקית: q הוא substring של טוקן אחר או להפך.
    // משקל מופחת חזק (0.3) כי הרבה פעמים זה מקרי - לדוגמה "אור" (light)
    // מתאים חלקית ל"אורך" (length) למרות שאלו מילים שונות לחלוטין.
    // דרישת אורך מינימלי 4 לכל הצדדים כדי לסנן שיתוף שורש 3-אותיות מקרי.
    let partial = 0;
    for (const t of targetTokens) {
      if (t.length >= 4 && q.length >= 4) {
        if (t.includes(q) || q.includes(t)) {
          partial = Math.max(partial, 0.3);
        }
      }
    }
    if (partial > 0) {
      matches++;
      // התאמה חלקית לעולם לא נחשבת "מהותית" - רק התאמה מדויקת
    }
    total += weight * partial;
  }

  return {
    score: maxPossible > 0 ? total / maxPossible : 0,
    matches,
    substantiveMatches,
  };
}

export function buildIndex(items: PriceListItem[]): void {
  cachedItems = items;
  cachedTokens = items.map(itemTokens);
  cachedTokenSets = cachedTokens.map(t => new Set(t));

  // אינדקסים להתאמה מדויקת מהירה
  partNumberIndex = new Map();
  descriptionIndex = new Map();
  items.forEach((it, idx) => {
    if (it.partNumber) partNumberIndex.set(normalize(it.partNumber), idx);
    if (it.description) descriptionIndex.set(normalize(it.description), idx);
  });

  // אינדקס הפוך: token → אינדקסים של פריטים שמכילים את הטוקן
  invertedIndex = new Map();
  cachedTokens.forEach((tokens, idx) => {
    const seen = new Set<string>();
    for (const t of tokens) {
      if (seen.has(t)) continue;
      seen.add(t);
      let set = invertedIndex.get(t);
      if (!set) {
        set = new Set();
        invertedIndex.set(t, set);
      }
      set.add(idx);
    }
  });

  // IDF: log(N / df). מילה נדירה (df קטן) -> IDF גבוה -> משקל רב בהתאמה.
  // מגבילים df מינימלי ל-1% מהקורפוס כדי שמילה בפריט בודד (לרוב מילה
  // אנגלית שמופיעה רק בפריט אחד באנגלית, כמו "MICROMETER" ב-LASER SCAN)
  // לא תקבל משקל עצום ותנצח את המקבילה העברית הנפוצה ("מיקרומטר", 23 פריטים).
  idfMap = new Map();
  const N = items.length;
  const dfFloor = Math.max(1, Math.floor(N * 0.01));
  for (const [token, docSet] of invertedIndex) {
    const df = Math.max(docSet.size, dfFloor);
    idfMap.set(token, Math.log(N / df));
  }

  fuseInstance = new Fuse(items, fuseOptions);
}

export function getItemCount(): number {
  return cachedItems.length;
}


/**
 * מציאת פריט במחירון לפי מק"ט מדויק (משמש להזנה ידנית של override).
 */
export function findItemByPartNumber(partNumber: string): PriceListItem | null {
  const trimmed = String(partNumber || '').trim();
  if (!trimmed) return null;
  return cachedItems.find(it => it.partNumber === trimmed) ?? null;
}

/**
 * השלמה אוטומטית - מחזיר פריטים מהמחירון שתואמים לטקסט שהוקלד,
 * לפי מק"ט או תיאור. מדרג: התאמה בתחילת המק"ט > תחילת התיאור > הכלה.
 */
export function suggestItems(query: string, limit = 10): PriceListItem[] {
  const q = String(query || '').trim().toLowerCase();
  if (q.length < 1) return [];

  const scored: Array<{ item: PriceListItem; rank: number }> = [];
  for (const it of cachedItems) {
    const pn = it.partNumber.toLowerCase();
    const desc = (it.description || '').toLowerCase();
    let rank = 0;
    if (pn === q) rank = 100;
    else if (pn.startsWith(q)) rank = 90;
    else if (desc.startsWith(q)) rank = 70;
    else if (pn.includes(q)) rank = 50;
    else if (desc.includes(q)) rank = 40;
    if (rank > 0) scored.push({ item: it, rank });
  }

  scored.sort((a, b) => b.rank - a.rank || a.item.partNumber.localeCompare(b.item.partNumber));
  return scored.slice(0, limit).map(s => s.item);
}

function findExactMatch(input: CustomerProductInput): PriceListItem | null {
  // מק"ט הלקוח מתקבל כמק"ט מ.ב.א. רק אם הוא בפורמט מק"ט תקין (ספרות / ספרות-ספרות).
  // מזהי יחידה כמו "T24102265" או "4-31005622" לא ייבדקו כלל - התאמה שלהם
  // יכולה להיות רק מקרית, והיא הייתה מנצחת ב-100% על פני התאמת התיאור.
  if (input.customerPartNumber && isValidPartNumber(input.customerPartNumber)) {
    const idx = partNumberIndex.get(normalize(input.customerPartNumber));
    if (idx !== undefined) return cachedItems[idx];
  }
  const idx = descriptionIndex.get(normalize(input.customerDescription));
  if (idx !== undefined) return cachedItems[idx];
  return null;
}

/**
 * מדרג את כל המחירון מול שאילתה אחת ומחזיר מועמדים עם ציון.
 * מופרד מ-findMatch כדי שאפשר יהיה לדרג כמה ניסוחים של אותו פריט
 * (תיאור בלבד / תיאור + יצרן ודגם) ולקחת לכל מועמד את הציון הטוב ביותר.
 */
function rankQuery(rawQuery: string): Array<{ item: PriceListItem; score: number; tokenScore: number }> {
  // העשרת השאילתה בתרגום עברי של מונחים אנגליים נפוצים בכיול:
  // "Transonic Flowprobe" → "Transonic Flowprobe מד זרימה פרוב זרימה" →
  // מאפשר התאמה למחירון העברי שלא היה מתאים אחרת.
  const query = enrichWithTranslations(rawQuery);
  const queryTokens = tokenize(query);

  // 1. שימוש ב-inverted index: מוצא רק פריטים שחולקים לפחות טוקן אחד עם השאילתה.
  // טוקנים נפוצים מדי (>40% מהקורפוס) - מדלגים, אחרת כל שאילתה תיתפוס את כל המחירון.
  const commonThreshold = Math.max(50, Math.floor(cachedItems.length * 0.4));
  const candidateIndices = new Set<number>();
  const usefulQueryTokens = queryTokens.filter(t => {
    const items = invertedIndex.get(t);
    return !items || items.size < commonThreshold;
  });
  // אם כל הטוקנים נפוצים - נשתמש בהם בכל זאת אבל בהגבלה
  const tokensToUse = usefulQueryTokens.length > 0 ? usefulQueryTokens : queryTokens;

  for (const t of tokensToUse) {
    const items = invertedIndex.get(t);
    if (items) items.forEach(i => candidateIndices.add(i));
  }

  // 2. דירוג מועמדים ע"י token overlap. הכלל המרכזי: חייבת לפחות התאמה מדויקת מהותית
  //    אחת (לא חלקית, לא מילה גנרית כמו "מד"/"סט"/"כיול"). בלי זה - קנס חמור 0.1x
  //    שמדכא כמעט לאפס. זה מבטיח ש"Pin Gauge" יעדיף "פין מדויק" על פני "מד קרינה/אור".
  const combined: Array<{ item: PriceListItem; score: number; tokenScore: number }> = [];
  for (const i of candidateIndices) {
    const { score: rawScore, substantiveMatches } =
      tokenOverlapScore(queryTokens, cachedTokens[i]);
    if (rawScore <= 0) continue;
    const adjusted = substantiveMatches >= 1 ? rawScore : rawScore * 0.1;
    combined.push({ item: cachedItems[i], score: adjusted, tokenScore: adjusted });
  }

  // 3. כשאין מועמדים מספיק חזקים - מפעילים Fuse כ-fallback אגרסיבי.
  //    שתי שכבות: התאמה חזקה (>0.55) שמתחרה עם token candidates,
  //    והתאמה חלשה (>0.3) שמשמשת רק כשאין כלום אחר.
  const bestTokenScore = combined.length > 0 ? Math.max(...combined.map(c => c.score)) : 0;
  if (bestTokenScore < 0.55) {
    const fuseResults = fuseInstance!.search(query, { limit: 10 });
    for (const r of fuseResults) {
      const fuseScore = 1 - (r.score ?? 1);
      if (fuseScore <= 0.3) continue;
      const weighted = fuseScore * 0.5;
      const existing = combined.findIndex(c => c.item === r.item);
      if (existing >= 0) {
        // אם הפריט כבר נבחר ע"י tokens - לוקחים את המקסימום
        if (weighted > combined[existing].score) {
          combined[existing].score = weighted;
          combined[existing].tokenScore = weighted;
        }
      } else {
        combined.push({ item: r.item, score: weighted, tokenScore: weighted });
      }
    }
  }

  // 4. Fallback אחרון: אם עדיין אין מועמדים, חיפוש substring על הטוקן הכי מבחין.
  //    משמש למקרים נדירים שבהם השאילתה לא משתפת אף טוקן עם שום פריט.
  if (combined.length === 0 && queryTokens.length > 0) {
    const distinctive = [...queryTokens]
      .filter(t => t.length >= 4 || /\d/.test(t))
      .sort((a, b) => (getIdf(b) - getIdf(a)) || (b.length - a.length));
    for (const t of distinctive.slice(0, 3)) {
      cachedItems.forEach((item, idx) => {
        const desc = normalize(item.description);
        if (desc.includes(t)) {
          combined.push({ item, score: 0.18, tokenScore: 0.18 });
        }
      });
      if (combined.length > 0) break;
    }
  }

  return combined;
}

/**
 * מחפש את המוצר הקרוב ביותר במחירון בשתי שכבות:
 *   1. התאמה מדויקת (מק"ט / תיאור זהים)
 *   2. ציון משולב: 60% token overlap + 40% Fuse fuzzy
 *
 * הציון המוחזר (matchScore) הוא 0-1, כאשר 1 = זהה.
 * threshold קובע מתי לסמן כ-"none" (חוסר התאמה משמעותית).
 */
/**
 * ממיר מק"ט מההיסטוריה לפריט שקיים במחירון הפעיל. אם הווריאנט המדויק
 * (למשל 170342-7) לא במחירון, מנסים את אותו בסיס עם סיומת שירות אחרת.
 */
function resolveToPriceList(partNumber: string): PriceListItem | null {
  const direct = findItemByPartNumber(partNumber);
  if (direct) return direct;
  // "170334" (בסיס בלי סיומת) או "170342-7" שאיננו במחירון הפעיל:
  // מנסים את אותו בסיס עם סיומות השירות, מהנפוצה לנדירה
  const base = partNumber.match(/^(\d+)(?:-\d+)?$/)?.[1];
  if (!base) return null;
  for (const suffix of ['0', '7', '1', '8', '2']) {
    const alt = findItemByPartNumber(`${base}-${suffix}`);
    if (alt) return alt;
  }
  return null;
}

/**
 * התאמה לפי היסטוריית הדגם. strong = יש מספיק ראיות (3+ מכשירים מהדגם,
 * והמוביל מופיע לפחות פעמיים) כדי להעדיף אותה על ברירת מחדל כללית שנלמדה.
 */
function matchFromHistory(input: CustomerProductInput): { result: PricingResult; strong: boolean } | null {
  const hit: ModelHit | null = lookupModel(input.customerContext);
  if (!hit) return null;

  const resolved: Array<{ item: PriceListItem; score: number; n: number }> = [];
  const seen = new Set<string>();
  for (const cand of hit.candidates) {
    const item = resolveToPriceList(cand.part);
    if (!item || seen.has(item.partNumber)) continue;
    seen.add(item.partNumber);
    resolved.push({ item, score: cand.n / hit.total, n: cand.n });
  }
  if (resolved.length === 0) return null;

  const best = resolved[0];
  // הציון משקף עד כמה ההיסטוריה חד-משמעית: 99% מהמכשירים → 0.94, 31% → 0.54
  const score = Math.min(0.97, 0.35 + 0.6 * best.score);
  let matched: PriceListItem | null = best.item;
  const ext = externalVariant(matched, findItemByPartNumber);
  if (ext) matched = ext;

  return {
    strong: hit.total >= 3 && best.n >= 2,
    result: {
      input,
      matched,
      matchType: 'close',
      matchScore: score,
      matchSource: 'history',
      matchNote: `לפי דגם ${hit.model} — ${best.n} מתוך ${hit.total} מכשירים בהיסטוריה`,
      alternatives: resolved.slice(1, 5).map(r => ({ item: r.item, score: r.score })),
    },
  };
}

export function findMatch(
  input: CustomerProductInput,
  threshold = 0.15,
  overrideDescription?: string,
): PricingResult {
  if (!fuseInstance || cachedItems.length === 0) {
    return {
      input,
      matched: null,
      matchType: 'none',
      matchScore: 0,
      alternatives: [],
    };
  }

  // אם הלקוח קבע override ידני (לדוגמה: "Pin Gauge X.XXmm" → "130903-0") -
  // משתמשים בו ישירות בלי לעבור דרך המאצ'ר הפזי.
  // כשהוגדר שם לקוח, מחפשים אך ורק בהתאמות שנלמדו מאותו לקוח (סינון קשיח).
  // שלב 0: המכשיר עצמו כבר רשום אצלנו - אין מה לנחש.
  // מחזיר את המק"ט שחויב בפועל בכיול האחרון, כולל ההחלטה פנים/חוץ.
  //
  // המזהה נבדק משתי עמודות. הסיבה: המספר שמזהה מכשיר אצל הלקוח מגיע לא פעם
  // בעמודה שכותרתה "מק"ט" ולא "מספר סידורי" - הלקוח מנהל מספור פנימי משלו,
  // ייחודי אצלו, ומ.ב.א. שומרת אותו כסידורי עם קידומת קוד הלקוח
  // ("340021" בקובץ = "2506-340021" בפריוריטי). כשנבדק רק customerSerial,
  // קבצים כאלה לא התאימו לאף מכשיר רשום ולכן חזרו בלי מספר מ.ב.א. ובלי מחיר,
  // אף שהמכשיר מוכר לנו היטב.
  //
  // הבדיקה בטוחה כי האינדקס מוגבל ללקוח הזה בלבד: התאמת שווא דורשת שללקוח
  // עצמו יהיה מכשיר שהסידורי שלו זהה למק"ט שהוא כתב באותה שורה. הסידורי
  // המפורש עדיף תמיד, והמק"ט משמש רק כשאין אחד.
  const serialHit =
    lookupSerial(input.customerName, input.customerSerial) ??
    lookupSerial(input.customerName, input.customerPartNumber);
  if (serialHit) {
    const item = resolveToPriceList(serialHit.part);
    if (item) {
      return {
        input,
        matched: item,
        matchType: 'exact',
        matchScore: 1,
        matchSource: 'serial',
        matchNote: serialHit.fromCharge
          ? `מכשיר רשום — חויב ${serialHit.part} בכיול האחרון`
          : `מכשיר רשום — מק"ט ${serialHit.part}`,
        mbaNumber: serialHit.mbaNum || undefined,
        lastChargedPart: serialHit.fromCharge ? serialHit.part : undefined,
        alternatives: [],
      };
    }
  }

  // סדר העדיפויות:
  //   1. תיקון אנושי לתיאור *ולדגם* הספציפיים
  //   2. היסטוריית כיולים חזקה לפי דגם (3+ מכשירים) - ספציפית יותר מברירת מחדל כללית
  //   3. תיקון אנושי לתיאור בלבד
  //   4. היסטוריה חלשה (1-2 מכשירים)
  //   5. התאמה מדויקת במחירון, ואז המאצ'ר הפזי
  const precisePn = getPreciseOverride(input.customerDescription, input.customerName, input.customerContext);
  const preciseItem = precisePn ? cachedItems.find(it => it.partNumber === precisePn) : undefined;
  if (preciseItem) {
    return {
      input,
      matched: preciseItem,
      matchType: 'exact',
      matchScore: 1,
      matchSource: 'override',
      matchNote: 'תיקון שנלמד לדגם הזה',
      alternatives: [],
    };
  }

  const history = matchFromHistory(input);
  if (history?.strong) return history.result;

  const genericPn = getGenericOverride(input.customerDescription, input.customerName);
  const genericItem = genericPn ? cachedItems.find(it => it.partNumber === genericPn) : undefined;
  if (genericItem) {
    return {
      input,
      matched: genericItem,
      matchType: 'exact',
      matchScore: 1,
      matchSource: 'override',
      matchNote: 'התאמה שנלמדה',
      alternatives: [],
    };
  }

  if (history) return history.result;

  const exact = findExactMatch(input);
  if (exact) {
    return {
      input,
      matched: exact,
      matchType: 'exact',
      matchScore: 1,
      matchSource: input.customerPartNumber && isValidPartNumber(input.customerPartNumber) ? 'partNumber' : 'description',
      matchNote: 'התאמה מדויקת במחירון',
      alternatives: [],
    };
  }


  // מדרגים כמה ניסוחים של אותו פריט ולוקחים לכל מועמד את הציון הגבוה מביניהם.
  // כך ההקשר (יצרן/דגם/מאפיינים) יכול רק לחשוף התאמה נוספת - לעולם לא לדלל
  // את הציון של התיאור הנקי (למשל "DMM" לבדו).
  const queries = overrideDescription
    ? [overrideDescription]
    : [
        input.customerDescription,
        input.customerContext
          ? `${input.customerDescription} ${input.customerContext}`
          : null,
      ].filter((q): q is string => !!q && q.trim().length > 0);

  // הניסוח הראשון (התיאור הנקי) הוא הזול והמדויק ביותר. את הניסוח עם ההקשר
  // מריצים רק כשהתיאור לבדו לא נתן התאמה טובה - חוסך חצי מזמן ההתאמה בקבצים גדולים.
  const CONTEXT_SKIP_SCORE = 0.8;
  const bestByItem = new Map<PriceListItem, { item: PriceListItem; score: number; tokenScore: number }>();
  for (const q of queries) {
    let bestSoFar = 0;
    bestByItem.forEach(c => { if (c.score > bestSoFar) bestSoFar = c.score; });
    if (bestByItem.size > 0 && bestSoFar >= CONTEXT_SKIP_SCORE) break;
    for (const c of rankQuery(q)) {
      const prev = bestByItem.get(c.item);
      if (!prev || c.score > prev.score) bestByItem.set(c.item, c);
    }
  }
  const combined = Array.from(bestByItem.values());

  combined.sort((a, b) => b.score - a.score);

  if (combined.length === 0) {
    return {
      input,
      matched: null,
      matchType: 'none',
      matchScore: 0,
      alternatives: [],
    };
  }

  // מציגים את המועמד הטוב ביותר רק אם הציון מעל רעש:
  //   close = ציון מעל הסף (התאמה אמינה)
  //   weak  = ציון 15%-סף (ניחוש סביר - הלקוח יבדוק)
  //   none  = ציון מתחת ל-15% או 0 (רעש; AI יקבל הזדמנות לזהות)
  // הסף הנמוך (0.15) מבטיח שמילה משותפת אחת חלשה לא תוצג כ"ניחוש".
  const WEAK_FLOOR = 0.15;
  const best = combined[0];
  let matchType: 'close' | 'weak' | 'none';
  if (best.score >= threshold) matchType = 'close';
  else if (best.score >= WEAK_FLOOR) matchType = 'weak';
  else matchType = 'none';

  let matched = matchType === 'none' ? null : best.item;
  const alternatives = combined.slice(matched ? 1 : 0, 5);

  // חוק מ.ב.א.: מוצרים שתמיד מכוילים בחוץ (תנורים/מאזניים/מכונות מתיחה) -
  // אם נבחרה גרסת הפנים (-0/-1), מחליפים לגרסת החוץ (-7/-8) המקבילה.
  if (matched) {
    const ext = externalVariant(matched, findItemByPartNumber);
    if (ext) matched = ext;
  }

  return {
    input,
    matched,
    matchType,
    matchScore: best.score,
    matchSource: 'fuzzy',
    alternatives,
  };
}
