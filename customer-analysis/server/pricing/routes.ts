import { Router, Request, Response, NextFunction } from 'express';
import multer from 'multer';
import * as fs from 'fs';
import * as path from 'path';
import { findMatch, getItemCount, buildIndex, findItemByPartNumber, suggestItems } from './services/matcher';
import { loadPriceList } from './services/excelLoader';
import { isAvailable as isPriorityUp, loadFromPriority, getCustomerNamesCached, resolveCustomerName } from './services/priorityDb';
import { buildModelIndex, getModelIndexSize } from './services/modelIndex';
import { ensureCustomerSerials } from './services/serialIndex';
import { parseCustomerExcel } from './services/customerExcelParser';
import { aiEnrich, isAiAvailable } from './services/aiEnricher';
import { setOverride, removeOverride, listOverrides, setOverridesBulk, countOverrides, registerCustomer, listCustomers } from './services/overrides';
import { parseLearningExcel } from './services/learningImporter';
import { CustomerProductInput, PriceListItem } from './types';
import { PRICING_DATA_DIR } from './paths';

const router = Router();
const threshold = parseFloat(process.env.FUZZY_THRESHOLD || '0.4');
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB - מתאים לקבצי לקוח גדולים
});

/**
 * שמות לטיניים שמורים בפריוריטי הפוך: "GNIGAMI NEVIG" הוא GIVEN IMAGING.
 * נבדק על כל המאגר - מתוך 679 לקוחות ללא אות עברית, 376 זוהו כהפוכים ואף אחד
 * לא כתקין. המשמעות: חיפוש "given" בבורר הלקוחות החזיר אפס תוצאות, ומי שחיפש
 * לקוח כזה לא יכול היה למצוא אותו - ולכן קיבל תמחור בלי מספרי מ.ב.א., כי
 * המכשירים רשומים תחת לקוח אחר לגמרי.
 *
 * מוחזר null לשם שיש בו עברית (שם עברי נשמר כתקין).
 */
function readableName(name: string): string | null {
  if (/[֐-׿]/.test(name)) return null;
  if (!/[A-Za-z]/.test(name)) return null;
  return name.split('').reverse().join('');
}

/** קריאת שם לקוח מ-body/query. ריק או חסר = ללא לקוח (המאגר הכללי). */
function readCustomerName(value: unknown): string | undefined {
  const raw = Array.isArray(value) ? value[0] : value;
  const name = typeof raw === 'string' ? raw.trim() : '';
  return name || undefined;
}

// טיפול אחיד בשגיאות multer (גודל קובץ, סוג קובץ וכד') - מחזיר 400 עם הודעת JSON
// במקום 500 גנרי שהקליינט מציג כ"Request failed with status code 500".
function multerErrorHandler(err: unknown, _req: Request, res: Response, next: NextFunction) {
  if (err instanceof multer.MulterError) {
    const message =
      err.code === 'LIMIT_FILE_SIZE'
        ? 'הקובץ גדול מהמותר (עד 50MB)'
        : `שגיאה בהעלאת הקובץ: ${err.message}`;
    return res.status(400).json({ error: message });
  }
  if (err) return res.status(400).json({ error: (err as Error).message });
  next();
}

router.get('/health', (_req: Request, res: Response) => {
  res.json({ ok: true, itemsLoaded: getItemCount() });
});

// מצב התקדמות גלובלי - אצלנו רק משתמש אחד מעלה בכל רגע, אז מספיק לעקוב אחר עבודה אחת.
// הפרונט מבצע polling ל-/progress ומציג "X/Y פריטים" לפי השלב הנוכחי.
type ProgressPhase = 'idle' | 'parsing' | 'matching' | 'ai' | 'done';
interface UploadProgress {
  phase: ProgressPhase;
  done: number;
  total: number;
  startedAt: number;
}
const progress: UploadProgress = { phase: 'idle', done: 0, total: 0, startedAt: 0 };

function setProgress(phase: ProgressPhase, done: number, total: number) {
  progress.phase = phase;
  progress.done = done;
  progress.total = total;
  if (phase === 'parsing') progress.startedAt = Date.now();
}

router.get('/progress', (_req: Request, res: Response) => {
  res.json(progress);
});

/**
 * שמירת override ידני: customerDescription → partNumber.
 * בפעמים הבאות שתופיע אותה שאילתת לקוח, היא תותאם אוטומטית למק"ט שנבחר.
 * Body: { customerDescription: string, partNumber: string, rematch?: CustomerProductInput }
 * אם rematch נמצא - מחזיר גם את ההתאמה החדשה כדי שהפרונט יוכל לעדכן את התצוגה.
 */
router.post('/override', (req: Request, res: Response) => {
  const { customerDescription, partNumber, rematch } = req.body || {};
  const customerName = readCustomerName(req.body?.customerName);
  if (!customerDescription || typeof customerDescription !== 'string') {
    return res.status(400).json({ error: 'חסר customerDescription' });
  }
  if (!partNumber || typeof partNumber !== 'string') {
    return res.status(400).json({ error: 'חסר partNumber' });
  }
  setOverride(customerDescription, partNumber, customerName, req.body?.customerContext);
  if (rematch) {
    const input = { ...(rematch as CustomerProductInput), customerName: customerName ?? (rematch as CustomerProductInput).customerName };
    const result = findMatch(input, threshold);
    return res.json({ ok: true, result });
  }
  res.json({ ok: true });
});

router.delete('/override', (req: Request, res: Response) => {
  const desc = req.body?.customerDescription;
  if (!desc) return res.status(400).json({ error: 'חסר customerDescription' });
  removeOverride(desc, readCustomerName(req.body?.customerName), req.body?.customerContext);
  res.json({ ok: true });
});

router.get('/overrides', (req: Request, res: Response) => {
  res.json(listOverrides(readCustomerName(req.query.customerName)));
});

/**
 * רשימת לקוחות להשלמה אוטומטית בשדה "לקוח".
 * מאחדת שני מקורות: לקוחות שכבר נלמדו מהם התאמות (מקומי, מוצגים ראשונים)
 * ורשימת הלקוחות מפריוריטי (CUSTOMERS) - לשמות בלבד, לא למחירים.
 * GET /api/customers?q=דן&limit=20
 */
router.get('/customers', async (req: Request, res: Response) => {
  const q = String(Array.isArray(req.query.q) ? req.query.q[0] : (req.query.q ?? '')).trim().toLowerCase();
  const limit = Math.min(parseInt(String(req.query.limit ?? '20'), 10) || 20, 100);

  const priorityRows = await getCustomerNamesCached();
  const byName = new Map(priorityRows.map(c => [c.name.trim().toLowerCase(), c]));

  // לקוח שכבר נלמד ממנו מקבל את קוד הפריוריטי שלו, אחרת אי אפשר לחפש אותו
  // לפי הקוד ("10251") ברגע שהוא נרשם מקומית
  const local = listCustomers().map(c => {
    const hit = byName.get(c.name.trim().toLowerCase());
    return {
      name: c.name,
      overrides: c.overrides,
      source: 'local' as const,
      code: hit?.code,
      altCodes: hit?.altCodes ?? [],
    };
  });
  const localNames = new Set(local.map(c => c.name.trim().toLowerCase()));

  const priority = priorityRows
    .filter(c => !localNames.has(c.name.trim().toLowerCase()))
    .map(c => ({ name: c.name, overrides: 0, source: 'priority' as const, code: c.code, altCodes: c.altCodes }));

  const match = (name: string, code?: string, altCodes: string[] = []) => {
    if (!q) return true;
    const readable = readableName(name);
    return name.toLowerCase().includes(q)
      || (readable ?? '').toLowerCase().includes(q)
      || (code ?? '').toLowerCase().includes(q)
      || altCodes.some(a => a.toLowerCase().includes(q));
  };

  // דירוג: התאמה מדויקת לקוד קודמת, אחריה שם שמתחיל בחיפוש, ואז השאר
  const rank = (c: { name: string; code?: string; altCodes?: string[] }) => {
    const name = c.name.toLowerCase();
    const readable = (readableName(c.name) ?? '').toLowerCase();
    const code = (c.code ?? '').toLowerCase();
    const alts = (c.altCodes ?? []).map(a => a.toLowerCase());
    if (q && (code === q || alts.includes(q))) return 0;
    if (q && (name.startsWith(q) || readable.startsWith(q))) return 1;
    if (q && (code.startsWith(q) || alts.some(a => a.startsWith(q)))) return 2;
    return 3;
  };

  const customers = [...local, ...priority]
    .filter(c => match(c.name, c.code, c.altCodes))
    .sort((a, b) => rank(a) - rank(b))
    .slice(0, limit)
    // display בלבד. name נשאר הערך הקנוני של פריוריטי - הוא המפתח של מאגר
    // הלמידה ושל חיפוש המכשירים, ושינוי שלו היה מנתק אותם.
    .map(c => ({ ...c, display: readableName(c.name) ?? undefined }));

  res.json({ customers, priorityAvailable: priorityRows.length > 0 });
});

/**
 * רישום שם לקוח חדש (כדי שיופיע בהשלמה גם לפני שנלמדה ממנו התאמה).
 * POST /api/customers  body: { name }
 */
router.post('/customers', (req: Request, res: Response) => {
  const name = readCustomerName(req.body?.name);
  if (!name) return res.status(400).json({ error: 'חסר שם לקוח' });
  const display = registerCustomer(name);
  res.json({ ok: true, name: display });
});

/**
 * בדיקה אם מק"ט נתון קיים במחירון, ומחזיר את הפריט המלא.
 * משמש את הפרונט להזנה ידנית של מק"ט - מאמת לפני שמירה כ-override.
 */
router.get('/item/:partNumber', (req: Request, res: Response) => {
  const pn = Array.isArray(req.params.partNumber) ? req.params.partNumber[0] : req.params.partNumber;
  const item = findItemByPartNumber(pn);
  if (!item) return res.status(404).json({ error: 'מק"ט לא נמצא במחירון' });
  res.json({ item });
});

/**
 * השלמה אוטומטית מתוך המחירון בלבד (לא Priority).
 * GET /api/suggest?q=130903&limit=10
 */
router.get('/suggest', (req: Request, res: Response) => {
  const q = Array.isArray(req.query.q) ? req.query.q[0] : req.query.q;
  const limit = Math.min(parseInt(String(req.query.limit ?? '10'), 10) || 10, 25);
  const items = suggestItems(String(q ?? ''), limit);
  res.json({ items });
});

router.get('/source-status', async (_req: Request, res: Response) => {
  const priorityUp = await isPriorityUp();
  res.json({
    excelLoaded: getItemCount() > 0,
    priorityConnected: priorityUp,
    itemsInIndex: getItemCount(),
    modelsInIndex: getModelIndexSize(),
  });
});

/**
 * רענון נתונים - טוען מחדש את המחירון ואת אינדקס הדגמים.
 *
 * המקור נקבע לפי PRICE_SOURCE, בדיוק כמו בעליית השרת. קודם הרענון העדיף תמיד
 * את פריוריטי כשהיה זמין, כך שלחיצה על "רענון נתונים" החליפה בשקט מחירון מוקפד
 * של ~875 פריטים בטבלת PART המלאה (5,400+) עד ההפעלה הבאה - שינוי התאמות שלם
 * מאחורי כפתור שכתוב עליו "רענון".
 */
router.post('/refresh', async (_req: Request, res: Response) => {
  try {
    let items: PriceListItem[] = [];
    let source = 'excel';

    if ((process.env.PRICE_SOURCE || 'excel').toLowerCase() === 'priority') {
      try {
        if (await isPriorityUp()) {
          items = await loadFromPriority();
          source = 'priority';
        }
      } catch (e) {
        console.warn('[pricing] Priority unavailable, loading from Excel:', (e as Error).message);
      }
    }

    if (items.length === 0) {
      const fileName = process.env.PRICE_LIST_FILE || 'pricelist.xlsx';
      items = loadPriceList(fileName);
      source = 'excel';
    }

    buildIndex(items);
    const models = await buildModelIndex(true).catch(() => 0);
    res.json({ ok: true, source, count: items.length, models });
  } catch (err) {
    res.status(500).json({ ok: false, error: (err as Error).message });
  }
});

/**
 * תמחור מוצר בודד.
 * body: { customerDescription, customerPartNumber?, quantity? }
 */
router.post('/price', (req: Request, res: Response) => {
  const input = req.body as CustomerProductInput;
  if (!input || !input.customerDescription) {
    return res.status(400).json({ error: 'חסר שדה customerDescription' });
  }
  const result = findMatch(input, threshold);
  res.json(result);
});

/**
 * תמחור באצווה (כמה מוצרים בבת אחת).
 * body: { items: CustomerProductInput[] }
 */
router.post('/price/batch', (req: Request, res: Response) => {
  const inputs = req.body?.items as CustomerProductInput[];
  if (!Array.isArray(inputs)) {
    return res.status(400).json({ error: 'נדרש מערך items' });
  }
  // שם לקוח ברמת הבקשה חל על כל הפריטים (אלא אם לפריט יש שם משלו)
  const customerName = readCustomerName(req.body?.customerName);
  if (customerName) registerCustomer(customerName);
  const results = inputs.map(i => findMatch({ ...i, customerName: i.customerName ?? customerName }, threshold));
  res.json({ results });
});

/**
 * העלאת קובץ המחירון (אדמין). שומר ל-data/pricelist.xlsx, בונה אינדקס חדש.
 */
router.post('/upload-pricelist', upload.single('file'), multerErrorHandler, async (req: Request, res: Response) => {
  if (!req.file) {
    return res.status(400).json({ error: 'לא הועלה קובץ' });
  }
  try {
    const dataDir = PRICING_DATA_DIR;
    if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });

    const fileName = process.env.PRICE_LIST_FILE || 'pricelist.xlsx';
    const targetPath = path.join(dataDir, fileName);
    fs.writeFileSync(targetPath, req.file.buffer);

    const items = loadPriceList(fileName);
    buildIndex(items);

    res.json({
      ok: true,
      savedTo: targetPath,
      count: items.length,
      originalName: req.file.originalname,
    });
  } catch (err) {
    res.status(500).json({ ok: false, error: (err as Error).message });
  }
});

/**
 * ייבוא קובץ "למידה": אקסל עם זוגות תיאור-לקוח ↔ מק"ט מ.ב.א. נכון.
 * כל זוג נשמר כ-override קבוע. מאמת שהמק"ט קיים במחירון.
 */
router.post('/learn', upload.single('file'), multerErrorHandler, (req: Request, res: Response) => {
  if (!req.file) {
    return res.status(400).json({ error: 'לא הועלה קובץ' });
  }
  try {
    const customerName = readCustomerName(req.body?.customerName);
    const parsed = parseLearningExcel(req.file.buffer);

    // מאמתים שכל מק"ט קיים במחירון; שומרים רק זוגות תקפים
    const validPairs = parsed.pairs.filter(p => findItemByPartNumber(p.partNumber) !== null);
    const notInPricelist = parsed.pairs.length - validPairs.length;

    // כשהוגדר לקוח, הלמידה נשמרת תחתיו בלבד ולא זולגת ללקוחות אחרים
    const learned = setOverridesBulk(validPairs, customerName);

    res.json({
      ok: true,
      learned,
      customerName: customerName ?? null,
      totalOverrides: countOverrides(customerName),
      detectedColumns: {
        description: parsed.headers[parsed.detectedColumns.description] ?? `עמודה ${parsed.detectedColumns.description + 1}`,
        partNumber: parsed.headers[parsed.detectedColumns.partNumber] ?? `עמודה ${parsed.detectedColumns.partNumber + 1}`,
      },
      totalRows: parsed.totalRows,
      skippedRows: parsed.skippedRows,
      invalidPartNumbers: parsed.invalidPartNumbers,
      notInPricelist,
      sampleLearned: validPairs.slice(0, 5),
    });
  } catch (err) {
    res.status(400).json({ ok: false, error: (err as Error).message });
  }
});

/**
 * העלאת קובץ אקסל של הלקוח עם כל המוצרים שלו.
 * זיהוי אוטומטי של עמודות תיאור / מק"ט / כמות.
 * מחזיר את הפריטים שזוהו + תוצאות התמחור שלהם.
 */
router.post('/upload', upload.single('file'), multerErrorHandler, async (req: Request, res: Response) => {
  if (!req.file) {
    return res.status(400).json({ error: 'לא הועלה קובץ' });
  }
  try {
    // סינון קשיח לפי לקוח: אם נבחר לקוח, ההתאמות הנלמדות שייבדקו הן שלו בלבד
    // אם הוקלד קוד לקוח - מתרגמים לשם המלא לפני כל השאר
    const rawCustomer = readCustomerName(req.body?.customerName);
    const customerName = rawCustomer ? await resolveCustomerName(rawCustomer) : undefined;
    let registeredDevices = 0;
    if (customerName) {
      registerCustomer(customerName);
      // המכשירים שכבר רשומים על הלקוח בפריוריטי - התאמה ודאית לפי סידורי
      registeredDevices = await ensureCustomerSerials(customerName);
    }

    setProgress('parsing', 0, 0);
    const t0 = Date.now();
    const parsed = parseCustomerExcel(req.file.buffer);
    const tParse = Date.now() - t0;

    // Memoization: שאילתות זהות מקבלות אותה תוצאה - חוסך זמן רב על קבצים גדולים.
    //
    // המפתח חייב לכלול את המספר הסידורי: הוא מזהה *מכשיר*, וההתאמה לפיו מחזירה
    // מק"ט ומספר מ.ב.א. השייכים לאותו מכשיר בלבד. בלעדיו כל השורות שחלקו תיאור
    // ("Crimp tool") קיבלו את התוצאה של הראשונה, כלומר תשעה מכשירים שונים הוצגו
    // עם אותו מספר קליטה קודם.
    setProgress('matching', 0, parsed.items.length);
    const cache = new Map<string, ReturnType<typeof findMatch>>();
    const tMatchStart = Date.now();
    const results = parsed.items.map((raw, idx) => {
      const i = customerName ? { ...raw, customerName } : raw;
      const key = `${i.customerDescription}||${i.customerPartNumber ?? ''}||${i.customerContext ?? ''}||${i.customerName ?? ''}||${i.customerSerial ?? ''}`;
      let r = cache.get(key);
      if (!r) {
        r = findMatch(i, threshold);
        cache.set(key, r);
      } else {
        // החזרה עם input של הפריט הנוכחי (לשמור את הכמות הנכונה)
        r = { ...r, input: i };
      }
      // עדכון התקדמות כל 5 פריטים כדי לא להעמיס
      if (idx % 5 === 0 || idx === parsed.items.length - 1) {
        setProgress('matching', idx + 1, parsed.items.length);
      }
      return r;
    });
    const tMatch = Date.now() - tMatchStart;

    // העשרת AI עם חיפוש אינטרנט: שולחים ל-Claude כל פריט עם ביטחון התאמה מתחת ל-80%.
    // Claude מחפש באינטרנט מה המכשיר באמת ומחזיר תיאור עברי, ואז מריצים שוב את המאצ'ר.
    // התאמות exact (100%) או close גבוהות (>=80%) לא נשלחות - הן כבר טובות.
    // קורה רק אם הוגדר ANTHROPIC_API_KEY. מוגבל ל-100 פריטים ייחודיים.
    const AI_CONFIDENCE_FLOOR = 0.8; // מתחת לזה -> חיפוש אינטרנט
    let aiEnriched = 0;
    let tAi = 0;
    if (isAiAvailable()) {
      const tAiStart = Date.now();
      const candidateIndices: number[] = [];
      const seenDescriptions = new Set<string>();
      results.forEach((r, idx) => {
        const lowConfidence = r.matchType !== 'exact' && r.matchScore < AI_CONFIDENCE_FLOOR;
        if (lowConfidence && !seenDescriptions.has(r.input.customerDescription)) {
          seenDescriptions.add(r.input.customerDescription);
          candidateIndices.push(idx);
        }
      });
      const toProcess = candidateIndices.slice(0, 100);
      setProgress('ai', 0, toProcess.length);
      // Caching לפי תיאור מקורי כדי שכל המופעים של אותה שאילתה ישתפו תוצאה
      const aiResults = new Map<string, ReturnType<typeof findMatch>>();
      let processed = 0;
      for (const idx of toProcess) {
        const input = results[idx].input;
        // ניסוח ראשון כולל יצרן/דגם ("SVERKER 750 PROGRAMMA" מזוהה טוב בהרבה מ-"SVERKER").
        // אם זה לא שיפר - מנסים את התיאור הנקי, כי לפעמים דגם לא מוכר מבלבל את החיפוש
        // ("רציפות הארקה" לבדו מזוהה, "רציפות הארקה DAMNAR GMC-25" לא).
        const aiQueries = input.customerContext
          ? [`${input.customerDescription} ${input.customerContext}`, input.customerDescription]
          : [input.customerDescription];
        let bestRematch: ReturnType<typeof findMatch> | null = null;
        for (const aiQuery of aiQueries) {
          const enriched = await aiEnrich(aiQuery);
          if (enriched === aiQuery) continue;  // המודל לא זיהה
          const rematch = findMatch(input, threshold, enriched);
          if (!bestRematch || rematch.matchScore > bestRematch.matchScore) bestRematch = rematch;
          if (bestRematch.matchScore >= AI_CONFIDENCE_FLOOR) break;  // מספיק טוב
        }
        processed++;
        setProgress('ai', processed, toProcess.length);
        if (bestRematch && bestRematch.matchScore > results[idx].matchScore) {
          aiResults.set(input.customerDescription, bestRematch);
        }
      }
      // החלת התוצאות גם על שורות עם תיאור זהה
      results.forEach((r, idx) => {
        const better = aiResults.get(r.input.customerDescription);
        if (better && better.matchScore > r.matchScore) {
          results[idx] = { ...better, input: r.input };
          aiEnriched++;
        }
      });
      tAi = Date.now() - tAiStart;
    }

    console.log(`[pricing] /upload: parse=${tParse}ms, match=${tMatch}ms, ai=${tAi}ms (${aiEnriched} enriched), rows=${results.length}, unique=${cache.size}`);
    setProgress('done', results.length, results.length);

    res.json({
      customerName: customerName ?? null,
      registeredDevices,
      detectedColumns: parsed.detectedColumns,
      totalRows: parsed.totalRows,
      skippedRows: parsed.skippedRows,
      sectionHeaderRows: parsed.sectionHeaderRows,
      hiddenRows: parsed.hiddenRows,
      sheetName: parsed.sheetName,
      headerRowIndex: parsed.headerRowIndex,
      allHeaders: parsed.allHeaders,
      preview: parsed.preview,
      results,
      timing: { parseMs: tParse, matchMs: tMatch, aiMs: tAi, uniqueQueries: cache.size, aiEnriched },
    });
  } catch (err) {
    // מדפיסים את ה-stack ל-stdout כדי שיהיה אפשר לדבג מהלוג של ה-backend
    console.error('[pricing] /upload failed:', err);
    setProgress('idle', 0, 0);
    res.status(400).json({
      error: (err as Error).message || 'שגיאה בקריאת הקובץ',
    });
  }
});

export default router;
