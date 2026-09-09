# Pendulum CNT-90 — פרוטוקול

מונה תדר / טיימר / אנלייזר.
המקור: **CNT-90 Series Programmer's Handbook** (Pendulum Instruments).

> **סטטוס: אומת מקצה לקצה עם אות אמיתי — 2026-09-08.**
> ה-**Siglent SDG6052X** הזין סינוס 1kHz / 4Vpp לכניסה A, והמונה ספר:
> `1000.025166`, `1000.000743`, `999.994309` Hz — סטייה של פחות מ-1 מיליהרץ.
> זו מדידה אמיתית ולא הדהוד של setpoint.

## זיהוי

- **תשובת `*IDN?` בפועל:**
  ```
  PENDULUM, CNT-90, 938636, V1.14 28 Jun 2006
  ```
  הפורמט: `<Manufacturer>, <Model>, <Serial Number>, <Firmware Level>`.
- ⚠️ **המכשיר מסיים תשובות ב-`
` בלבד, לא `
`** (אומת 2026-09-08 על רמת הבתים —
  התשובה מסתיימת ב-`0A` בלי `0D` לפניו). קוד שמצפה ל-CRLF יראה בית חסר וידווח
  על שיבוש שלא קיים.
- **טוקן זיהוי:** `CNT-90` — לפי **הדגם ולא היצרן**, כי אותו יצרן משווק גם CNT-91 עם BL אחר.
- **מחלקת BL:** `Systems/Hydra-Group/ComServer/ComServerBL/Device/Cnt90BL.cs`
- **BLCore:** `Systems/Hydra-Group/ComServer/ComServerBL/BLCore/Cnt90BLCore.cs`
- **עזרי פענוח:** `Device/Cnt90Readings.cs`

## חיבור פיזי — GPIB

| | |
|---|---|
| **כתובת GPIB** | **7** — לא 10 של ברירת המחדל, ולא 18 של ה-Datron |
| **מתאם** | NI GPIB-USB-HS+ (`VID_3923&PID_7618`) |
| **שכבה** | `GpibCom` מעל `gpib-32.dll` (NI-488.2), `__cdecl`, 32-ביט בלבד |
| **Tunnel** | `Pendulum-CNT90-GPIB`, `"GpibPrimaryAddress": 7` |

לשינוי הכתובת במכשיר: `USER OPT → Interface → GPIB address`.

**ה-USB לא עבד.** למונה יש יציאת USB והמדריך מתעד USBTMC (`VID_14EB`, `PID_0090`), אבל במכונה הזו
הוא לא התחבר לאפיק בכלל — אין התקן, ואין אפילו אירוע PnP. GPIB הוא המסלול העובד.

## פרוטוקול תקשורת

- **דיאלקט:** SCPI. **פורמט:** `:FORMat ASCii`, ערכים ב-NR3.
- **`:SYSTem:LANGuage`** בוחר את ערכת הפקודות:
  - `NATive` — מה שהמדריך והקוד הזה מדברים. **זה מה שה-BL כופה באתחול.**
  - `COMPatible` — אמולציה של Agilent 53131/53132, ערכת פקודות אחרת לגמרי.

### ⚠️ המלכודת המרכזית: מדידת תדר בלי אות **נתקעת**

זה מה שמעצב את כל ה-BL. בניגוד לסקופ, שמחזיר סמן `+9.9E+37` מיד, המונה פשוט **ממתין לקצוות שלא
מגיעים** ולא עונה כלל:

```
:MEASure:FREQuency? (@1)   ->  <timeout>     (10+ שניות, אין תשובה)
:READ?                     ->  <timeout>
:MEASure:VOLTage:MAXimum? (@1)  ->  -4E-03   (382ms — תמיד עונה)
```

ניסינו את כל מנגנוני ה-timeout שבמדריך — **כולם התקבלו ונקראו בחזרה נכון, ואף אחד לא שחרר את
השאילתה**:

```
:SYSTem:TOUT ON          → :SYSTem:TOUT? מחזיר 1
:SYSTem:TOUT:TIME 1      → מחזיר +1.0000000000000E+00
:SYSTem:TOUT:AUTO ON     → מחזיר 1
```

הסמן `9.91E37` שהמדריך מבטיח קיים **רק במצב COMPatible**, שאליו לא נלך.

**הפתרון ב-BL:** לפני כל שאילתת תדר, ה-BL שואל `:MEASure:VOLTage:MAXimum?` — שאלה שהמונה תמיד עונה
עליה מהר. רק אם התשובה מעידה על אות (`Cnt90Readings.IndicatesSignalPresent`, סף 50mV מול ‎2-4mV‎ של
רעש בכניסה פתוחה) הוא מתחייב לשאילתת התדר. אחרת הוא מדלג לערוץ הבא ורושם בלוג.

### שתי מלכודות נוספות

1. **`?` אינו בסוף הפקודה** — `:MEASure:FREQuency? (@1)` היא שאילתה עם פרמטר. `GpibCom` זיהה
   שאילתות לפי `EndsWith("?")` ולכן לא היה קורא את התשובה בכלל. תוקן ל-`GpibCom.IsQuery` (חיפוש `?`
   בכל מקום), בדיוק כמו התיקון ב-`VisaCom`. ה-Datron 9100 לא הושפע — כל שאילתותיו מסתיימות ב-`?`.

2. **`-410 "Query INTERRUPTED"`** — אחרי שאילתה שנחסמה, הפקודה הבאה מקבלת את השגיאה הזו. המכשיר
   **מתאושש מעצמו** וממשיך לענות, ולכן לא נדרש device clear; רק לדעת שהתור מתמלא.

### רצף האתחול (`StateWork__InitSystem`)

| # | פקודה | למה |
|---|-------|-----|
| 0 | `*RST` | מצב ידוע — **משאיר את ה-timeout כבוי** |
| 1 | `*CLS` | ניקוי סטטוס |
| 2 | `:SYSTem:LANGuage NATive` | למקרה שהמכשיר נשאר באמולציית 53131 |
| 3 | `:FORMat ASCii` | תשובות טקסט ולא בלוק בינארי |
| 4 | `:SYSTem:TOUT ON` | חימוש ה-timeout ש-`*RST` כיבה |
| 5 | `:SYSTem:TOUT:TIME 1` | שנייה אחת |
| 6 | `:SYSTem:TOUT:AUTO ON` | timeout קצר אם אין אות בכלל |
| 7 | `:CONFigure:FREQuency (@n)` | הכנת המדידה |

### לולאת המדידה

לכל ערוץ בתורו: `:MEASure:VOLTage:MAXimum?` (שומר) → ואם יש אות → `:MEASure:FREQuency? (@n)`.

## הגדרות

`Settings/HydraBL_Settings.json`, מפתח `Cnt90`:

```json
"Cnt90": {
  "Channels": [ 1 ],
  "MaxNumOfChannels": 2,
  "Masters": [],
  "Sensor": { "MeasureType": 7, "SensType": -1 }
}
```

`MeasureType: 7` = `Frequency` → היחידה המשודרת היא `Hertz`.
ערוצים תקפים: 1 ו-2 בלבד (`(@3)` הוא ה-prescaler ו-`(@4)` כניסת ה-arming האחורית).

## פתוח

- ✅ **הלולאה אומתה עם אות אמיתי** (2026-09-08): השומר זיהה את המעבר מ-`0.0002 V`
  לאות, עבר לשאילת תדר, והמונה שידר `1000.000743 Hz` מול SDG6052X שמוגדר ל-1kHz.
- לשקול `:INITiate:CONTinuous` + `:FETCh?` במקום `:READ?` אם קצב הדגימה לא יספיק.
- `datasheet.pdf` לא הורד לתיקייה. המדריך:
  https://pendulum-instruments.com/wp-content/uploads/2022/05/CNT-90ph.pdf
