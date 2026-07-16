# מסמכי מכשירים / Device Documents

תיקייה זו מרכזת את כל המסמכים הטכניים של המכשירים הנתמכים בשרת ה-VCT:
דפי נתונים (datasheets), מדריכי פרוטוקול תקשורת, נהלי כיול, וערכי ייחוס של מאסטרים.

תיקייה זו היא **תיעוד/עזר בלבד** — אין כאן קוד. קוד לוגיקת המכשירים חי תחת
`Systems/Hydra-Group/ComServer/ComServerBL/` (ה-`BLCore` וה-`DeviceBL` לכל מכשיר).

## מבנה — תיקייה לכל מכשיר

| תיקייה | מכשיר | טוקן זיהוי (SN) | מחלקת BL בקוד |
|--------|-------|------------------|----------------|
| `Fluke-Hydra-2625A/` | Fluke Hydra 2625A | `2625` / `FLUKE` | `Hydra2DeviceBL` |
| `Fluke-Hydra-2638A/` | Fluke Hydra 2638A | `2638` | `Hydra3DeviceBL` |
| `Agilent-34401A/`    | Agilent/Keysight 34401A | `HEWLETT` | `Agilent34401aBLCore` |
| `Additel/`           | Additel (מד לחץ) | `TAU` | `AdditelBLCore` |
| `Optidew/`           | Optidew (לחות/טל) | Modbus → `Optidew` | `OptidewBLCore` |
| `TTI/`               | TTI | `TTI` | `TTIBLCore` |
| `Instek/`            | Instek | `Instek` | `InstekBLCore` |
| `_template/`         | תבנית לתיעוד מכשיר חדש | — | — |

## מה לשים בכל תיקיית מכשיר

ראו `_template/README.md`. בקצרה, כל תיקיית מכשיר צריכה להכיל:

- `datasheet.pdf` — דף נתונים / מפרט יצרן
- `protocol.md` — פקודות התקשורת הרלוונטיות (SCPI / Modbus / דיאלקט ייעודי) והתשובות
- `calibration-procedure.md` — נוהל הכיול והחיבור הפיזי (COM/baud, כתובת IP, ערוצים)
- `masters.md` — מזהי המאסטרים (ערכי ייחוס) המשמשים למכשיר זה וקישור לערכי התיקון ב-DB
