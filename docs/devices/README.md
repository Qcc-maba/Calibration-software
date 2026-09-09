# מסמכי מכשירים / Device Documents

תיקייה זו מרכזת את כל המסמכים הטכניים של המכשירים הנתמכים בשרת ה-VCT:
דפי נתונים (datasheets), מדריכי פרוטוקול תקשורת, נהלי כיול, וערכי ייחוס של מאסטרים.

תיקייה זו היא **תיעוד/עזר בלבד** — אין כאן קוד. קוד לוגיקת המכשירים חי תחת
`Systems/Hydra-Group/ComServer/ComServerBL/` (ה-`BLCore` וה-`DeviceBL` לכל מכשיר).

## מבנה — שתי משפחות, תיקייה לכל מכשיר

המכשירים מחולקים לפי מה שהם מודדים או מייצרים, וזו גם החלוקה על שולחן העבודה:

### ⚡ [`electronics/`](electronics/) — גדלים חשמליים

| תיקייה | מכשיר | סוג | טוקן זיהוי (SN) | מחלקת BL |
|---|---|---|---|---|
| `Fluke-5522A/` | Fluke 5522A | מכייל רב-תכליתי (מקור) | `5522A` | `Fluke5522aBL` |
| `HP-53181A/` | HP 53181A | מונה תדר | `53181A` | `Hp53181aBL` |
| `Prodigit-3111/` | PRODIGIT 3111 | עומס אלקטרוני DC | `PRODIGIT_3111` | `Prodigit3111BL` |
| `Siglent-SDG6052X/` | Siglent SDG6052X | מחולל גלים (מקור) | `SDG6052X` | `Sdg6052xBL` |
| `Pendulum-CNT-90/` | Pendulum CNT-90 | מונה תדר/טיימר | `CNT-90` | `Cnt90BL` |
| `Keysight-EDUX1002A/` | Keysight EDU-X 1002A | אוסילוסקופ | `EDUX1002A` | `KeysightEdux1002aBL` |
| `Datron-9100/` | Datron/Wavetek 9100 | מכייל (מקור) | `Datron9100` | `Datron9100BL` |
| `Fluke-5322A/` | Fluke 5322A | מכייל בודקי בטיחות (מקור) | `5322A` (גם `5320A`) | `Fluke5322aBL` |
| `Meatest-M142/` | Meatest M-142 | מכייל + מודד | `M-142` | `MeatestM142BL` |

### 🌡️ [`temperature/`](temperature/) — טמפרטורה ולחות

| תיקייה | מכשיר | טוקן זיהוי (SN) | מחלקת BL |
|---|---|---|---|
| `Fluke-Hydra-2625A/` | Fluke Hydra 2625A | `2625` | `Hydra2DeviceBL` |
| `Fluke-Hydra-2638A/` | Fluke Hydra 2638A | `2638` | `Hydra3DeviceBL` |
| `Agilent-34401A/` | Agilent/Keysight 34401A | `HEWLETT` | `Agilent34401aBL` |
| `Additel/` | Additel | `TAU` | `AdditelBLCore` |
| `Optidew/` | Optidew (לחות/טל) | Modbus → `Optidew` | `OptidewBLCore` |
| `TTI/` | TTI | `TTI` | `TTIBLCore` |
| `Instek/` | Instek | `Instek` | `InstekBLCore` |

`_template/` — תבנית לתיעוד מכשיר חדש.

> **ה-34401A יושב תחת טמפרטורה בכוונה.** הוא מודד ספרתי, אבל כאן הוא מוגדר לקרוא PT100
> ארבעה-חוטים וה-BL ממיר את ההתנגדות למעלות. ראה [`temperature/README.md`](temperature/README.md).

## מה לשים בכל תיקיית מכשיר

ראו `_template/README.md`. בקצרה, כל תיקיית מכשיר צריכה להכיל:

- `datasheet.pdf` — דף נתונים / מפרט יצרן
- `protocol.md` — פקודות התקשורת הרלוונטיות (SCPI / Modbus / דיאלקט ייעודי) והתשובות
- `calibration-procedure.md` — נוהל הכיול והחיבור הפיזי (COM/baud, כתובת IP, ערוצים)
- `masters.md` — מזהי המאסטרים (ערכי ייחוס) המשמשים למכשיר זה וקישור לערכי התיקון ב-DB

מכשירי המקור (מכיילים ומחוללים) מוסיפים לכך סעיף בטיחות: איזו פקודה מחשמלת מוצא, ולמה היא
לא נמצאת באתחול ולא בלולאת הקריאה.
