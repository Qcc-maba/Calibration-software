import * as path from 'path';

/**
 * תיקיית הנתונים של התמחור: המחירון, ההתאמות שנלמדו, מטמון ה-AI וחוקי הכיול.
 *
 * במערכת המקורית הנתיב נגזר מ-__dirname, אבל כאן אותו קוד רץ בשני מצבים -
 * בפיתוח כ-ESM דרך tsx (אין __dirname), ובפרודקשן כ-bundle CJS יחיד. לכן
 * הנתיב נגזר מתיקיית ההרצה, בדיוק כמו שה-.env נטען ממנה (dotenv/config).
 * PRICING_DATA_DIR מאפשר להצביע על תיקייה אחרת כשההרצה נעשית ממקום אחר.
 *
 * זו תיקייה שנכתבת בזמן ריצה: כל תיקון ידני שהמשתמש מאשר נשמר כאן, ואובדן
 * שלה = אובדן כל הלמידה. אין ליצור אותה מחדש בפריסה חדשה בלי להעתיק תוכן.
 */
export const PRICING_DATA_DIR = process.env.PRICING_DATA_DIR
  ? path.resolve(process.env.PRICING_DATA_DIR)
  : path.resolve(process.cwd(), 'data', 'pricing');
