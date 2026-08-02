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

## מה עדיין נדרש ממך (חוסם חלקים)
1. **נתיב/י תיקיות הרשת** של הוראות הלקוח + הפורמטים (PDF? Word? סרוקים? Excel?),
   ו**מוסכמת השיוך**: איך יודעים איזה קובץ שייך לאיזה לקוח/מכשיר?
   (תיקייה לפי שם/מספר לקוח? שם קובץ מכיל מס' סידורי? מטא-דאטה?)
2. **2–3 קבצי דוגמה** אמיתיים כדי לכייל את החילוץ וההתאמה.
3. **שדות ה-Priority** שמכילים הוראות/הערות רלוונטיות (ברמת לקוח? ברמת מכשיר/פריט?
   שם הישות והשדה, למשל `MBA_CUSTLOAD.<field>`).
4. **מפתח Claude API** (`ANTHROPIC_API_KEY`) — לא נכנס ל-git.
5. לזיהוי האוטומטי: מאיפה מגיע `CalibRecordId` בזמן הכיול (אינטגרציה עם רשומות MABA/VCT).

## סטטוס
- [x] תכנית + סקיצת פרויקט net10 עצמאי
- [x] ClaudeSummarizer (Anthropic Messages API) — מלא
- [x] FileShareInstructionProvider — מלא (txt), חילוץ PDF/DOCX מאחורי interface
- [ ] PriorityInstructionSource — ממתין לשמות שדות ההוראות ב-Priority
- [ ] חילוץ PDF/Word + OCR לסרוקים — ממתין לפורמטים האמיתיים
- [ ] אינטגרציית CalibRecordId עם רשומות הכיול
