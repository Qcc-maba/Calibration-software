# Siglent SDG6052X — פרוטוקול

מחולל גלים שרירותי, 2 ערוצים.
המקור: **SDG Series Arbitrary Waveform Generator Programming Guide** (Siglent).

> **סטטוס: אומת מקצה לקצה מול החומרה — 2026-09-01.**
> `*IDN?` → `C1:BSWV?` → פענוח → `BroadcastAllMeasurements` → WebSocket (`Units:"Hertz"`, `Value:"1000"`).

## זיהוי

- **תשובת `*IDN?` בפועל:**
  ```
  Siglent Technologies,SDG6052X,SDG6XEBD4R0879,6.01.01.35R5B1
  ```
  שים לב: **בלי רווח אחרי הפסיק**, בניגוד לדוגמה שבמדריך עצמו
  (`Siglent Technologies,SDG6052X, SDG6XBAX1R0034`). הזיהוי נעשה לפי הדגם.
- **מחלקת BL:** `Systems/Hydra-Group/ComServer/ComServerBL/Device/Sdg6052xBL.cs`
- **BLCore:** `Systems/Hydra-Group/ComServer/ComServerBL/BLCore/Sdg6052xBLCore.cs`
- **פענוח תשובות:** `Device/Sdg6052xReplies.cs` ← **הלב של המימוש הזה**

## חיבור פיזי — USBTMC

| | |
|---|---|
| **מחרוזת משאב** | `USB0::0xF4EC::0x1101::SDG6XEBD4R0879::INSTR` |
| **מזהי USB** | `VID_F4EC` (Siglent) / `PID_1101` |
| **שכבה** | `VisaCom` — **ללא פיתוח תעבורה חדש** |
| **Tunnel** | `Siglent-SDG6052X-USB`, `"VisaResource": "USB?*::0xF4EC::?*INSTR"` |

ה-tunnel מצמיד את המכשיר **לפי מזהה היצרן ולא לפי מספר סידורי**, כך שיחידה אחרת מאותו דגם נכנסת
בלי שינוי הגדרות. זו גם הסיבה שה-tunnel של הסקופ הועבר מ-`"AUTO"` ל-`USB?*::0x2A8D::?*INSTR` —
עם שני מכשירי USB על השולחן, `AUTO` היה מתפס על הראשון שנמצא.

## ⚠️ שני כללי בטיחות שה-BL אוכף

### 1. האתחול לא מאפס את המכשיר

**`*RST` על ה-SDG פירושו "Restore default settings"** — הוא היה מוחק את מה שהמפעיל כיוון בפאנל
הקדמי. רצף האתחול הוא קריאה בלבד:

| # | פקודה | למה |
|---|-------|-----|
| 0 | `*IDN?` | זיהוי |
| 1 | `SYST:ERR?` | ניקוז תור השגיאות |

### 2. האתחול לא מדליק מוצא

מוצא של מחולל מחשמל כבל פיזי. הוא נדלק **רק** דרך `Sdg6052xCommands.BuildOutputOn` עבור יעד מפורש
שנדרש — לא באתחול ולא בלולאת הקריאה. יש טסט שמאמת את שתי התכונות האלה על רצף האתחול.

## פרוטוקול תקשורת — לא SCPI

התחביר הוא קיצורים של Siglent, לא תת-מערכות SCPI, **והתשובות מחזירות את כותרת הפקודה עם יחידות
מודבקות למספרים**:

```
C1:BSWV?  ->  C1:BSWV WVTP,SINE,FRQ,1000HZ,PERI,0.001S,AMP,4V,AMPVRMS,1.414Vrms,
              MAX_OUTPUT_AMP,20V,OFST,0V,HLEV,2V,LLEV,-2V,PHSE,0
C1:OUTP?  ->  C1:OUTP OFF,LOAD,HZ,PLRT,NOR
```

**`double.Parse("1000HZ")` זורק חריגה.** אף אחד ממסלולי הפרסור המספריים של המכשירים ה-SCPI לא יכול
לקרוא את זה, ולכן:

- `LogsResponse.RawText` (חדש) נושא את התשובה הגולמית, ויש ענף ייעודי שמזהה `:BSWV` / `:OUTP` ולא
  מנסה לחלץ מספרים — בלעדיו התשובה הייתה נופלת לפרסר התאריכים של ה-Hydra ומייצרת אזהרה בכל קריאה.
- `Sdg6052xReplies` עושה את העבודה: `StripHeader` מסיר את `C1:BSWV `, `ParseParameters` מפצל לזוגות
  key/value, ו-`TryParseNumber` קולף את הסיומת (`1000HZ`→1000, `1.414Vrms`→1.414, `0.001S`→0.001,
  `-2V`→-2). כל אלה מחזירים `false` במקום ערך ברירת מחדל, כדי שתשובה משובשת לא תגיע לאפליקציה
  כקריאה של 0.

הפענוח סובל גם יחידה שבה `COMM_HEADER` כבוי (תשובה בלי הקידומת).

### הפקודות שנבנו

| קטגוריה | פקודות |
|---|---|
| קריאה | `*IDN?`, `*OPC?`, `SYST:ERR?`, `C<n>:BSWV?`, `C<n>:OUTP?` |
| הגדרה | `C<n>:BSWV WVTP,<type>` / `FRQ,<hz>` / `AMP,<vpp>` / `OFST,<v>` / `PHSE,<deg>`, `C<n>:OUTP LOAD,<50\|HZ>` |
| ⚠️ מחשמל | `C<n>:OUTP ON` / `C<n>:OUTP OFF` |

## מה ה-BL משדר

הוא **מקור, לא לוגר** — התקדים הוא `Datron9100BL`, לא הלוגרים. לולאת הקריאה מדווחת את ה**setpoint**
שהמחולל מוגדר לייצר, שזה מה שכיול משווה אליו את קריאת המונה. איזה פרמטר בדיוק נקבע לפי
ה-`MeasureType` של המשפחה: `Frequency` → `FRQ`, וולט → `AMP`.

```
[WS TX] CMD:"LoggerData", DeviceID:"SDG6052X", ... Units:"Hertz", Channel:"1", Value:"1000"
```

## הגדרות

`Settings/HydraBL_Settings.json`, מפתח `Sdg6052x`:

```json
"Sdg6052x": {
  "Channels": [ 1 ],
  "MaxNumOfChannels": 2,
  "Masters": [],
  "Sensor": { "MeasureType": 7, "SensType": -1 }
}
```

> אם המפתח חסר בקובץ הוא נטען כאובייקט ריק עם `Sensor = null`, והשידור נופל ליחידת ברירת המחדל
> `Celsius`. זה בדיוק מה שקרה בהרצה הראשונה — צריך שהמפתח יהיה בקובץ הרץ, לא רק ב-`CreateDefaultSettings`.

## פתוח

- **החיבור לשולחן:** ה-SDG הוא מקור האות שה-CNT-90 צריך. ראה
  `docs/devices/electronics/Pendulum-CNT-90/protocol.md` — שאילתת התדר של המונה נחסמת בלי אות.
- הפעלת מוצא מרחוק עדיין לא מחווטת לפקודה מהאפליקציה; הבונים קיימים ומסומנים.
- `datasheet.pdf` לא הורד לתיקייה. המדריך:
  https://assets.testequity.com/te1/Documents/pdf/siglent/Siglent_SDG-Programming-Guide_0125.pdf
