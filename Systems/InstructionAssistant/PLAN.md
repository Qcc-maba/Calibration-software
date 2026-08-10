# Instruction Assistant — עוזר הוראות לקוח לכייל

**מטרה:** להציג לכייל, בזמן שהוא מכייל מכשיר, **סיכום ממוקד של הוראות הלקוח הרלוונטיות
לאותו מכשיר**, מתוך המקורות הידועים לנו — **Priority ERP** וקבצים שמורים ברשת.

> החלטות שאושרו (2026-08-02):
> - **זיהוי מכשיר:** *שניהם* — אוטומטי מרשומת הכיול הפעילה (לקוח + סוג מכשיר + מס' סידורי),
>   ובנוסף חיפוש ידני כ-fallback.
> - **מנוע סיכום:** *Claude API בענן* (Anthropic Messages API).
> - **פלטפורמה:** *שירות .NET בשרת VCT* — פרויקט net10 עצמאי ב-`UnifiedSystemV1.sln`,
>   שרץ כתהליך/שירות שהשרת (או ה-UI) קורא לו ב-HTTP — בדיוק כמו `Maba.VCT.Priority`
>   (שרת ה-VCT הוא .NET 4.8 ולא יכול לטעון net10 in-process).

## ⚠️ פרטיות — נתונים יוצאים לענן
מנוע הסיכום שולח את **טקסט ההוראות** (שעשוי לכלול שם לקוח והערות) ל-Anthropic.
- מפתח ה-API נטען מ-`ANTHROPIC_API_KEY` (env) או מקונפיג — **לא נשמר ב-git**.
- לפני שליחה: אופציית `RedactCustomerNames` להסתרת שמות לקוח (מוחלף במזהה).
- ניתן לכבות סיכום-ענן ולעבור ל"חילוץ קטעים בלבד" דרך `Summarizer:Mode=Extractive`.

## זרימת נתונים
```
כייל בוחר/פותח מכשיר
        │  (CalibRecordId  או  Customer+Serial+DeviceType)
        ▼
InstructionAssistantService  ──► IInstructionSourceProvider[]
        │                           ├─ FileShareInstructionProvider  (תיקיות רשת: PDF/Word/סרוקים/טקסט)
        │                           └─ PriorityInstructionSource     (OData: שדות הערות/הוראות ללקוח/מכשיר)
        ▼
IDocumentTextExtractor  (txt ✓, PDF/DOCX — TODO לפי הפורמט האמיתי, OCR לסרוקים בהמשך)
        ▼
IInstructionSummarizer  →  ClaudeSummarizer (Anthropic Messages API)
        ▼
InstructionSummary  { סיכום Markdown בעברית, נקודות מפתח, אזהרות, רשימת מקורות }
        ▼
JSON ל-UI / לשרת ה-VCT
```

## נקודות קצה (HTTP)
| Method | URL | תיאור |
|--------|-----|-------|
| GET | `/api/instructions/summary?mabaNum=2601047/7` | **זיהוי אוטומטי ממספר מבא** — שולף לקוח/יצרן/דגם/מס' סידורי מ-Priority |
| GET | `/api/instructions/summary?customer=&serial=&deviceType=` | זיהוי לפי פרמטרים (כל פרמטר מפורש גובר על מה שנשלף אוטומטית) |
| GET | `/api/instructions/search?q=DT4282` | חיפוש ידני — מחזיר מספרי מבא מועמדים לפי דגם/יצרן/מס' סידורי/לקוח |
| GET | `/health` | בדיקת חיים + זמינות Claude/Priority/תיקיות |

## רכיבים
- `Models/` — `InstrumentContext`, `InstructionDocument`, `InstructionSummary`.
- `Options/InstructionAssistantOptions.cs` — נתיבי רשת, קונפיג Claude, דגלי פרטיות.
- `Sources/IInstructionSourceProvider.cs` + `FileShareInstructionProvider` + `PriorityInstructionSource`.
- `Extraction/IDocumentTextExtractor.cs` + `PlainTextExtractor` + `CompositeTextExtractor`.
- `Summarize/IInstructionSummarizer.cs` + `ClaudeSummarizer` + `ExtractiveSummarizer`.
- `InstructionAssistantService.cs` — התזמור.
- `Program.cs` — Minimal API + DI.

## מקורות שאומתו חי (2026-08-04)

**1. תיקיית הרשת** — `\\maba-dc\Public\הספריה הציבורית\ECS לומניס בוסטון`
(לקוח ראשון: לומניס, קוד לקוח `9732`, `CUSTOMERS.CUST=9330`).
מוסכמת השיוך: שם הקובץ מכיל את **המס' הסידורי בסוגריים** —
`ECS - HIOKI DT4282 (97048883).docx`. זו ההתאמה החזקה ביותר ולכן היא מדורגת ראשונה.
הפורמטים בפועל: `.docx` (המקור), `.pdf` (ייצוא של אותם מסמכים), `.xls`, `.msg`.
באותה תיקייה יושב גם האקסל המרכזי.

**2. Priority — "הנחיות לביצוע"** ב-`amaba.dbo.ORDERSTEXT`:
```
CUSTOMERS.CUSTNAME (קוד לקוח) ─► CUSTOMERS.CUST ─► ORDERS.ORD ─► ORDERSTEXT.ORD
                                     TEXT מפוצל על פני TEXTORD/TEXTLINE
```
שתי מלכודות שאומתו והטופלו בקוד:
- **הטקסט שמור הפוך תו-תו** (אחסון "עברית ויזואלית" ישן): `<style>` חוזר כ-`>elyts<`.
  כל שורה מתהפכת בחזרה לפני השרשור.
- התוכן הוא **HTML שהודבק מ-Word** ורוב ההזמנות נושאות בדיוק את אותם תנאים —
  לכן הטקסט מנוקה מתגיות, וטקסטים זהים בין הזמנות מתאחדים למסמך אחד.

**3. מפתח Claude** — `ANTHROPIC_API_KEY` מוגדר ברמת User env.

**4. זיהוי אוטומטי לפי מספר מבא** — `MBA_DOCLOAD` (טבלה, לא view) מחזיק
`MBANUM → CUST, SERNDES, SERNUM, MNFDES, MODEL, MANUFC_SERIAL`. `PriorityRecordResolver`
שולף משם את כל ההקשר, ולכן `?mabaNum=` לבדו מספיק.

⚠️ **כיווניות שדות ב-Priority** — לא אחידה, ואומתה ב-SQL (בדיקה שאינה תלויה ברינדור מסך;
אסור להסתמך על איך שזה נראה בקונסולה!). `MNFDES`, `SERNDES`, `CUSTOMERS.CUSTDES` שמורים
ב"עברית ויזואלית" ישנה, ואילו `MODEL`, `SERNUM`, `MANUFC_SERIAL` שמורים כרגיל:

| ראיה | ממצא |
|------|------|
| `MNFDES='IKOIH'` 2,676 שורות מול `'HIOKI'` 0 | לטינית הפוכה |
| `SERNDES LIKE '%MMD%'` 100,563 מול `'%DMM%'` 0 | לטינית הפוכה |
| `SERNDES LIKE '%מולטימטר%'` 84,999 שורות | **העברית דווקא תקינה** |
| `'מוט אורך מסטר 521'` (= מוט 125 מ"מ) | גם ספרות הפוכות |
| `MODEL='DT4282'` 34 שורות | תקין, לא להפוך |
| `CUSTDES LIKE '%DTL%'` 183 מול `'%LTD%'` 0 | לומניס שמור `CSB DTL SINEMUL` |

לכן `FixVisualHebrew` הופך **כל רצף לטיני/ספרתי בנפרד** ומשאיר את העברית במקומה, ורק ערך
נטול-עברית מתהפך במלואו כולל סדר המילים (`CSB DTL SINEMUL` → `LUMENIS LTD BSC`).

**שים לב:** יש **שני** לקוחות לומניס — `CUSTNAME=1863` (`CUST=946`, LUMENIS LTD BSC — זה של
תיקיית "ECS לומניס בוסטון") ו-`CUSTNAME=9732` (`CUST=9330`, לומניס בי בע"מ). ההוראות עצמן
מזהירות לוודא זיהוי נכון בין השניים.

## חילוץ PDF ו-OCR
`PdfTextExtractor` (PdfPig, Apache-2.0) פעיל. **OCR לא נדרש** — נבדקו כל 42 קבצי ה-PDF
בתיקייה: לכולם יש שכבת טקסט (`withText=42, noTextLayer=0`), כלומר אין שם סרוקים.
אם בעתיד יתווסף מסמך סרוק הוא יקבל `ExtractionNote` מפורש ולא ייכשל.

> ⚠️ **אזהרת חבילות:** החבילה הרשמית היא **`PdfPig`** (מזהה `PdfPig`, מאת UglyToad,
> Apache-2.0, 312 גרסאות). קיימת ב-NuGet חבילה בשם `UglyToad.PdfPig` עם 2 גרסאות בלבד
> ו-`<description>Package Description</description>` — **אינה החבילה האמיתית, לא להתקין.**

`.doc` בינארי ישן (קובץ אחד בתיקייה) עדיין לא נתמך ומקבל הערת חילוץ ברורה.

## לקוחות נוספים
נסרקה כל `\\maba-dc\Public\הספריה הציבורית` — **קיימת רק תיקיית הוראות אחת**
("ECS לומניס בוסטון"), אין היום תיקיות ECS ללקוחות אחרים. הקונפיג כבר תומך בכמה שורשים,
ולכן הוספת לקוח = הוספת נתיב ל-`FileShare:Roots` בלבד.

בתוך התיקייה יש גם `ECS\` וגם `מעודכן 2025 כל השאר לפי דוח קודם  ECS\` עם **שמות קבצים
כפולים** — ולכן שובר-שוויון בדירוג הוא **תאריך שינוי, החדש קודם** (ולא סדר אלפביתי),
כדי שלא יוגש לכייל מסמך ישן.

## מה עדיין פתוח
- **קריאה מה-UI** — ראה `app/src/server/api/routers/instructions/` (מימוש tRPC) ; שרת ה-VCT
  עצמו (.NET 4.8) לא מחזיק `MBANUM` בשום מקום, ולכן נקודת החיבור הנכונה היא ה-UI.

## סטטוס
- [x] תכנית + פרויקט net10 עצמאי
- [x] ClaudeSummarizer (Anthropic Messages API) — כולל טיפול בקטיעת `max_tokens`
- [x] ExcelInstructionProvider — האקסל המרכזי, התאמה לפי יצרן+דגם, קריאה עמידה לקובץ נעול
- [x] FileShareInstructionProvider + חילוץ `.docx` (ללא תלות ב-OpenXML SDK)
- [x] PriorityInstructionSource — `ORDERSTEXT` מול `amaba`, כולל היפוך הטקסט ואיחוד תנאים קבועים
- [x] `PriorityRecordResolver` — `?mabaNum=` לזיהוי אוטומטי + `/search` למציאת מספר מבא
- [ ] חילוץ PDF/`.doc` + OCR לסרוקים
- [ ] קריאה מהשרת/UI של VCT
