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
| GET | `/api/instructions/summary?calibRecordId=` | זיהוי אוטומטי מרשומת הכיול |
| GET | `/api/instructions/summary?customer=&serial=&deviceType=` | זיהוי לפי פרמטרים |
| GET | `/api/instructions/search?q=` | חיפוש ידני של מכשירים/לקוחות |
| GET | `/api/instructions/sources?...` | רשימת מסמכי מקור בלבד (בלי סיכום) — לניפוי |
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

## מה עדיין פתוח
1. **אינטגרציית זיהוי אוטומטי**: מאיפה מגיע מזהה הכיול בזמן העבודה. סוכם שהמזהה הוא
   **מספר מבא (`MBANUM`)** — `MBA_DOCLOAD` מחזיק `MBANUM → CUST, SERNUM, MNFDES, MODEL`,
   כלומר בדיוק מה שדרוש. נשאר לחבר את הפרמטר ל-endpoint ולמשוך את השדות.
2. **חילוץ PDF** — טרם ממומש (חבילת PdfPig אינה זמינה בפיד ה-NuGet הנוכחי בגרסה יציבה
   שתואמת net10). כרגע לא חוסם: ה-PDF בתיקייה הם ייצוא של אותם `.docx` שכן נקראים.
   `.doc` בינארי ישן ו-OCR לסרוקים גם הם עדיין לא נתמכים.
3. **לקוחות נוספים** — כרגע מוגדר שורש רשת אחד. כשיתווספו לקוחות, להוסיף שורשים
   ל-`FileShare:Roots` (ההתאמה כבר תומכת בכמה שורשים).

## סטטוס
- [x] תכנית + פרויקט net10 עצמאי
- [x] ClaudeSummarizer (Anthropic Messages API) — כולל טיפול בקטיעת `max_tokens`
- [x] ExcelInstructionProvider — האקסל המרכזי, התאמה לפי יצרן+דגם, קריאה עמידה לקובץ נעול
- [x] FileShareInstructionProvider + חילוץ `.docx` (ללא תלות ב-OpenXML SDK)
- [x] PriorityInstructionSource — `ORDERSTEXT` מול `amaba`, כולל היפוך הטקסט ואיחוד תנאים קבועים
- [ ] חילוץ PDF/`.doc` + OCR לסרוקים
- [ ] אינטגרציית `MBANUM` לזיהוי אוטומטי (במקום העברת customer/serial ידנית)
