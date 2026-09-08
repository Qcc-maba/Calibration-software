/**
 * שירות העשרה מבוסס Claude API לפריטים שלא נמצאו במחירון.
 * הרעיון: עבור תיאור באנגלית/לא מזוהה, שואלים את Claude מה המכשיר ומקבלים
 * שם עברי + קטגוריה, ואז מריצים שוב את המאצ'ר עם השאילתה המועשרת.
 *
 * אופציונלי - פועל רק אם הוגדר ANTHROPIC_API_KEY ב-.env. אחרת מחזיר את התיאור המקורי.
 * תוצאות נשמרות בקובץ cache כדי לא לחזור על קריאות יקרות.
 */
import Anthropic from '@anthropic-ai/sdk';
import * as fs from 'fs';
import * as path from 'path';
import { PRICING_DATA_DIR } from '../paths';

const CACHE_PATH = path.join(PRICING_DATA_DIR, 'ai-enrichment-cache.json');

let cache: Record<string, string> = {};
try {
  if (fs.existsSync(CACHE_PATH)) {
    cache = JSON.parse(fs.readFileSync(CACHE_PATH, 'utf8'));
  }
} catch (err) {
  console.warn('[pricing] could not load AI enrichment cache:', (err as Error).message);
}

let client: Anthropic | null = null;
if (process.env.ANTHROPIC_API_KEY) {
  client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  console.log('[pricing] Claude API connected - AI enrichment of unmatched items is on');
} else {
  console.log('[pricing] Claude API not configured (no ANTHROPIC_API_KEY) - AI enrichment off');
}

export function isAiAvailable(): boolean {
  return client !== null;
}

/** האם השגיאה תחזור זהה בכל קריאה נוספת (יתרה/מפתח/הרשאה) ולא כדאי להמשיך */
function isUnrecoverable(err: unknown): boolean {
  const status = (err as { status?: number })?.status;
  if (status === 401 || status === 403) return true;
  const message = String((err as Error)?.message ?? '');
  return /credit balance is too low|invalid x-api-key|authentication_error|permission_error/i.test(message);
}

function describeError(err: unknown): string {
  const message = String((err as Error)?.message ?? '');
  if (/credit balance is too low/i.test(message)) return 'the Anthropic account is out of credit';
  if (/invalid x-api-key|authentication_error/i.test(message)) return 'the ANTHROPIC_API_KEY is not valid';
  return message.slice(0, 120);
}

function saveCache(): void {
  try {
    const dir = path.dirname(CACHE_PATH);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(CACHE_PATH, JSON.stringify(cache, null, 2), 'utf8');
  } catch (err) {
    console.warn('[pricing] could not save AI enrichment cache:', (err as Error).message);
  }
}

/**
 * שואל את Claude מה המכשיר ומחזיר תיאור מועשר.
 * הפורמט המוחזר: "<תיאור מקורי> <שם עברי> <קטגוריה>"
 * אם הקריאה נכשלת או אין API key - מחזיר את התיאור המקורי.
 */
export async function aiEnrich(description: string): Promise<string> {
  if (!client) return description;
  const key = description.trim();
  if (!key) return description;
  if (key in cache) return cache[key];

  const prompt = `אני צריך לזהות מכשיר כיול/מדידה כדי להתאים אותו למחירון מעבדת כיול בעברית.

התיאור מהלקוח: "${description}"

חפש באינטרנט מה המכשיר הזה (במיוחד אם זה שם דגם/יצרן לא מוכר), ואז החזר **רק שורה אחת בעברית** המתארת אותו לצורך חיפוש טקסטואלי:
- סוג המכשיר בעברית (למשל: "מד לחץ", "מד ספיקה", "קליבר", "מד עובי", "בודק דליפות", "מד זרימה", "אוסילוסקופ", "מד טמפרטורה")
- 1-2 מילות תכונה (למשל: "לחץ", "זרימה", "אורך", "טמפרטורה", "מתח", "זמן")
- היצרן באנגלית אם רלוונטי (Transonic / Fluke / Mitutoyo / Tinius Olsen / Keysight…)

כללים מחמירים:
- אל תכלול מילות מילוי ("מכשיר", "ציוד", "כלי", "מערכת", "הוא משמש")
- אל תיתן הסבר, מקורות, או טקסט נוסף - רק השורה
- אם גם אחרי חיפוש לא הצלחת לזהות - החזר בדיוק "לא ידוע"

דוגמה: עבור "Transonic TS420" החיפוש מגלה שזו מערכת מדידת ספיקת דם → התשובה: "מד ספיקה זרימה אולטרסוני Transonic"`;

  try {
    const response = await client.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 1024,
      tools: [
        {
          type: 'web_search_20250305',
          name: 'web_search',
          max_uses: 3,
          // כלי החיפוש המובנה של Anthropic אינו תואם לטיפוס Tool (אין לו input_schema),
          // ולכן נדרשת המרה דרך unknown
        } as unknown as Anthropic.Messages.Tool,
      ],
      messages: [{ role: 'user', content: prompt }],
    });

    // התשובה הסופית היא בלוק הטקסט האחרון בלבד. הבלוקים שלפניו הם "חשיבה בקול"
    // של המודל בין קריאות החיפוש ("אני רואה DT-36T אבל לא DT-36 בדיוק, תן לי לחפש עוד"),
    // וצירוף שלהם מכניס רעש לשאילתת ההתאמה החוזרת.
    const blocks = response.content
      .filter((c): c is Anthropic.TextBlock => c.type === 'text')
      .map(c => c.text.replace(/\s+/g, ' ').trim())
      .filter(Boolean);
    let text = blocks.length > 0 ? blocks[blocks.length - 1] : '';

    // אם המודל הדגיש את התשובה ב-**...** - זו התשובה, השאר הסבר
    const bold = text.match(/\*\*(.+?)\*\*/);
    if (bold) text = bold[1].trim();
    // "...לכן התשובה: מד לחץ דיגיטלי" → החלק שאחרי הנקודתיים האחרונות
    if (text.length > 120 && text.includes(':')) {
      text = text.slice(text.lastIndexOf(':') + 1).trim();
    }
    text = text.replace(/\*\*/g, '').replace(/^[-–—•\s]+/, '').slice(0, 150).trim();

    const cleaned = text && !/לא ידוע/.test(text) ? text : '';
    const enriched = cleaned ? `${description} ${cleaned}` : description;
    cache[key] = enriched;
    saveCache();
    return enriched;
  } catch (err) {
    // תקלה שלא תיפתר מעצמה (יתרה שנגמרה, מפתח שנפסל, חוסר הרשאה) חוזרת בדיוק
    // אותו דבר לכל פריט. בלי לכבות את ההעשרה, קובץ של 88 פריטים ייחודיים בילה
    // שתי דקות וחצי בהמתנה ל-88 כשלונות זהים לפני שהציג תוצאה שכבר הייתה מוכנה.
    if (isUnrecoverable(err)) {
      client = null;
      console.warn(
        `[pricing] AI enrichment disabled for this run - ${describeError(err)}. ` +
        `Matching continues without it; restart the server after fixing the API key.`,
      );
      return description;
    }
    console.warn(`[pricing] AI web-search enrich failed for "${description}":`, (err as Error).message);
    return description;
  }
}
