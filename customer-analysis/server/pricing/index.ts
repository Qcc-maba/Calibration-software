/**
 * מערכת תמחור המוצרים של מ.ב.א. הזורע, כמודול של הדשבורד.
 *
 * עד כה זה היה שרת נפרד (Express משלו על פורט 4000 + build נפרד של הפרונט).
 * הקוד עצמו לא השתנה - השירותים תחת services/ הם אותם קבצים - רק נקודת
 * החיבור: במקום app.listen משלו, ה-router נתלה על שרת הדשבורד תחת /api/pricing.
 *
 * התחילית חובה: גם התמחור וגם הדשבורד מגדירים /api/customers, ובלעדיה
 * אחד מהם היה חוטף את הבקשות של השני.
 */
import type { Express } from 'express';
import pricingRouter from './routes';
import { loadPriceList } from './services/excelLoader';
import { isAvailable as isPriorityUp, loadFromPriority } from './services/priorityDb';
import { buildIndex, getItemCount } from './services/matcher';
import { buildModelIndex } from './services/modelIndex';
import { PriceListItem } from './types';

export const PRICING_API_PREFIX = '/api/pricing';

/**
 * טעינת המחירון ואינדקס ההתאמה.
 *
 * המחירון נטען סינכרונית כדי שהתמחור יעבוד מהבקשה הראשונה, ואילו כל מה שתלוי
 * בפריוריטי (מקור priority, אינדקס הדגמים) רץ ברקע: הדשבורד עולה גם כשפריוריטי
 * לא זמין, ואסור שהתמחור ישנה את זה.
 */
function bootstrapPricing(): void {
  const fileName = process.env.PRICE_LIST_FILE || 'pricelist.xlsx';
  const preferredSource = (process.env.PRICE_SOURCE || 'excel').toLowerCase();

  buildIndex(loadPriceList(fileName));
  console.log(`[pricing] price list ready from Excel: ${getItemCount()} items`);

  void (async () => {
    let priorityAvailable = false;
    try {
      priorityAvailable = await isPriorityUp();
    } catch {
      priorityAvailable = false;
    }
    console.log(`[pricing] Priority: ${priorityAvailable ? 'connected' : 'unavailable'}`);
    if (!priorityAvailable) return;

    if (preferredSource === 'priority') {
      try {
        const items: PriceListItem[] = await loadFromPriority();
        if (items.length > 0) {
          buildIndex(items);
          console.log(`[pricing] price list reloaded from Priority: ${items.length} items`);
        }
      } catch (err) {
        console.warn('[pricing] could not load the price list from Priority:', (err as Error).message);
      }
    }

    // אינדקס הדגמים לוקח כשנייה ואינו חוסם - בלעדיו ההתאמה פשוט לא משתמשת בהיסטוריה
    buildModelIndex().catch(err =>
      console.warn('[pricing] model index:', (err as Error).message),
    );
  })();
}

export function registerPricingRoutes(app: Express): void {
  app.use(PRICING_API_PREFIX, pricingRouter);
  bootstrapPricing();
}
