# Maba.VCT.InstructionAssistant

שירות net10 עצמאי שמציג לכייל **סיכום הוראות הלקוח הרלוונטיות למכשיר** שהוא מכייל,
מתוך **קבצים ברשת** ו-**Priority**, מסוכם ב-**Claude API**. רץ כתהליך שהשרת/ה-UI קורא לו
ב-HTTP (כמו `Maba.VCT.Priority`). תכנון מלא ב-[PLAN.md](PLAN.md).

## הרצה
```powershell
# מפתח Claude דרך הסביבה (לא נכנס ל-git):
$env:ANTHROPIC_API_KEY = "sk-ant-..."
dotnet run --project Systems/InstructionAssistant/Maba.VCT.InstructionAssistant.csproj
```
הגדרות מקומיות: העתק `appsettings.Development.example.json` ל-`appsettings.Development.json`
(מוחרג מ-git) ומלא את נתיבי הרשת ב-`FileShare.Roots`.

## נקודות קצה
| Method | URL | תיאור |
|--------|-----|-------|
| GET | `/health` | חיים + רשימת מקורות + מצב סיכום |
| GET | `/api/instructions/summary?customer=&serial=&deviceType=` | סיכום לפי פרמטרים |
| GET | `/api/instructions/summary?calibRecordId=` | זיהוי אוטומטי (ממתין לאינטגרציית רשומות) |
| GET | `/api/instructions/search?q=` | חיפוש ידני (stub) |

דוגמה:
```
GET /api/instructions/summary?customer=Acme&serial=SN12345&deviceType=Multimeter
```

## מצבי סיכום
- `Summarizer:Mode=Claude` — סיכום ענן (ברירת מחדל). טקסט ההוראות נשלח ל-Anthropic.
- `Summarizer:Mode=Extractive` — מקומי, ללא AI, הנתונים לא עוזבים את הרשת.
- `RedactCustomerNames=true` — הסתרת שם הלקוח לפני שליחה לענן.

## מצב מימוש
ראו סעיף הסטטוס ב-[PLAN.md](PLAN.md). מלא: FileShare (txt) + ClaudeSummarizer + ExtractiveSummarizer.
ממתין לקלט: נתיבי הרשת + פורמטים, שדות ההוראות ב-Priority, ואינטגרציית `calibRecordId`.
חילוץ PDF/Word/OCR יתווסף לאחר קבלת קבצי דוגמה.
