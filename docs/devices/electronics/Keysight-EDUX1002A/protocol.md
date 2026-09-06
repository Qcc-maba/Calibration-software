# Keysight InfiniiVision EDUX1002A — פרוטוקול

סקופ (אוסילוסקופ) דיגיטלי, 50MHz, 2 ערוצים אנלוגיים, 1GSa/s.
המקור: **InfiniiVision 1000 X-Series Programmer's Guide** (Keysight 9018-07554).

> **סטטוס: אומת מקצה לקצה מול החומרה — 2026-09-01.**
> `*IDN?` → מכונת מצבים → `:MEASure?` → `BroadcastAllMeasurements` → WebSocket.

## זיהוי

- **דגם מלא:** Keysight Technologies InfiniiVision EDU-X 1002A
- **תשובת `*IDN?` בפועל:**
  ```
  KEYSIGHT TECHNOLOGIES,EDU-X 1002A,CN59280205,01.10.2018012838
  ```
  ⚠️ **המכשיר מאיית את הדגם `EDU-X 1002A` — עם מקף ורווח — ולא `EDUX1002A` כמו מספר הדגם בדף
  הנתונים.** לכן `HardwareDeviceHost.IsKeysight1000XSeries` מנרמל רווחים ומקפים לפני ההשוואה,
  ותופס את שני האיותים. אין להשוות למחרוזת גולמית.
- **SN קנוני שנקבע בקוד:** `EDUX1002A` (זה מה ש-`KeysightEdux1002aBLCore.DeviceIdToken` תופס)
- **מחלקת BL:** `Systems/Hydra-Group/ComServer/ComServerBL/Device/KeysightEdux1002aBL.cs`
- **BLCore:** `Systems/Hydra-Group/ComServer/ComServerBL/BLCore/KeysightEdux1002aBLCore.cs`
- **עזרי פענוח:** `Device/KeysightEdux1002aReadings.cs`
- **בוני פקודות:** אזור `Keysight EDUX1002A` ב-`VCT.Common/Protocol Parser/HydraProtocolHelper.cs`

## חיבור פיזי — USB בלבד (USBTMC)

ל-EDUX1002A יש **רק יציאת USB Device אחורית**. אין בו LAN, אין GPIB ואין RS-232.
לכן נוספה שכבת תעבורה חדשה: **`VisaCom`** (`VCT.ComLayer/Com Layer/VisaCom.cs`), מעל `visa32.dll`,
באותו דפוס DllImport שבו `GpibCom` עוטף את `gpib-32.dll`.

| | |
|---|---|
| **מחרוזת משאב** | `USB0::0x2A8D::0x178B::CN59280205::INSTR` |
| **מזהי USB** | `VID_2A8D` (Keysight) / `PID_178B` |
| **מחלקת התקן ב-Windows** | `USBTestAndMeasurementDevice` |
| **דרייבר** | NI-VISA 26.5 עם **USB Passport** (מותקן במכונה) |
| **DLL בפועל** | `C:\Windows\SysWOW64\visa32.dll` — התהליך רץ 32-ביט (כמו בשביל `gpib-32.dll`) |
| **מוסכמת קריאה** | `__stdcall` — **שונה** מ-`gpib-32.dll` שהיא `__cdecl` |

### הגדרת ה-Tunnel (`Settings/VCT.json`)

```json
{
  "Name": "Keysight-EDUX1002A-USB",
  "VisaResource": "AUTO",
  "VisaTimeoutMs": 5000,
  "SerialPortName": null,
  "GpibPrimaryAddress": -1
}
```

`"AUTO"` לוקח את מכשיר ה-USB הראשון ש-VISA רואה (`viFindRsrc("USB?*INSTR")`), במקביל ל-`"AUTO"`
של הפורט הסריאלי. כשיהיה יותר ממכשיר USB אחד על השולחן — יש לרשום את המחרוזת המלאה.

## פרוטוקול תקשורת

- **דיאלקט:** SCPI. **פורמט הערכים:** NR3.
- **סיומת:** התשובה מסתיימת ב-`\n` בלבד; `VisaCom` מנרמל ל-`\r\n` כי הפרסר המשותף חותך חבילה רק על
  `=>` או `\r\n` (בדיוק מאותה סיבה כמו ב-`GpibCom`).

### שתי מלכודות שהתגלו רק מול החומרה

1. **המנטיסה חוזרת לפעמים בלי נקודה עשרונית:** `+800E-03` (= 0.8), `+1.0E+00`, `+125E-03`.
   הפרסור ב-`LogsResponse` הוא `NumberStyles.Float` עם `InvariantCulture` — מטפל בשתי הצורות.

2. **סמן "לא ניתן למדוד" חוזר ככתיב `+99E+36`**, לא `+9.9E+37`:
   ```
   :MEASure:FREQuency? CHANnel1  ->  +99E+36
   ```
   השוואת מחרוזת ל-`"9.9E+37"` הייתה מפספסת. `KeysightEdux1002aReadings.IsMeasurementError`
   משווה **מספרית** מול סף `9.0e37`, ולכן תופסת כל כתיב. הערך נזרק ולא משודר.

### רצף האתחול (`StateWork__InitSystem`) — אומת, כל הפקודות התקבלו

| # | פקודה | למה |
|---|-------|-----|
| 0 | `*RST` | מצב התחלתי ידוע |
| 1 | `*CLS` | ניקוי סטטוס (גם מנקה `-410 Query INTERRUPTED` ש-`*RST` עלול לייצר) |
| 2 | `:TIMebase:MODE MAIN` | המדידות נלקחות על ה-sweep הראשי |
| 3..n | `:CHANnel<n>:DISPlay 1` | ערוץ שאינו מוצג אינו ניתן למדידה |
| n+1 | `:AUToscale` | בלעדיה נשאר מבט ברירת-המחדל של `*RST` וכל מדידה מחזירה את הסמן |
| n+2 | `:RUN` | דגימה רציפה |

`:AUToscale` הסתיימה בתוך טיק אחד (2000ms) — לא נדרש `*OPC?`.

### לולאת המדידה (`StateWork__Logs`)

סבב round-robin על הערוצים; כל שאילתה נושאת מקור מפורש.

| `MeasureType` | שאילתה | תשובה שנמדדה בפועל |
|--------------|--------|-------------------|
| `VoltagePP` (5, ברירת מחדל) | `:MEASure:VPP? CHANnel<n>` | `+1.0E+00` / `+800E-03` |
| `VoltageRMS` (6) | `:MEASure:VRMS? DISPlay,AC,CHANnel<n>` | `+125E-03` |
| `VoltageDC` (8) | `:MEASure:VAVerage? DISPlay,CHANnel<n>` | `-108E-03` |
| `Frequency` (7) | `:MEASure:FREQuency? CHANnel<n>` | `+99E+36` (אין אות) |

> הסקופ משתמש ב-`VoltageDC` (8) ולא ב-`VDC` (1). **`VDC` בקוד הזה אינו "וולט"** —
> `HydraCalculations.ProcessResults` מעביר אותו דרך `CalcResistanceToTemperatureITS90` ומפיק
> `Sample.Units.Celsius`. זו האיות הישן ל-"התנגדות שנקראת כטמפרטורה", וכך מוגדר ה-34401A.

> **`?` אינו בסוף הפקודה.** `:MEASure:VPP? CHANnel1` הוא שאילתה עם פרמטר. זיהוי שאילתה לפי
> `EndsWith("?")` (המוסכמה ב-`GpibCom`, תקינה שם כי ה-9100 שולח רק שאילתות בלי פרמטרים) לא קרא את
> התשובה, ה-session נשאר ממתין והאיסוף נעצר אחרי מדידה אחת. ב-`VisaCom` הבדיקה היא `IsQuery` —
> חיפוש `?` בכל מקום בפקודה. **אם יתווסף למכשיר GPIB עתידי שאילתה עם פרמטר, אותו תיקון יידרש
> ב-`GpibCom`.**

## הגדרות

`Settings/HydraBL_Settings.json`, מפתח `Edux1002a`:

```json
"Edux1002a": {
  "Channels": [ 1, 2 ],
  "MaxNumOfChannels": 2,
  "Masters": [],
  "Sensor": { "MeasureType": 5, "SensType": -1 }
}
```

`MeasureType` נשמר כמספר: `5`=VoltagePP, `6`=VoltageRMS, `1`=VDC, `7`=Frequency.
הערכים 5–7 נוספו ל-`SensorType.MeasureTypes` עם מספור מפורש, כדי שקבצי הגדרות קיימים לא ישנו משמעות.
אם המפתח חסר בקובץ, ה-BL נופל לערוץ 1 בלבד.

רישום המודול ב-`Settings/ComServerSettings.json`:

```json
{ "AssemblyName": "Maba.VCT.CommServer.BL.HydraDevices",
  "TypeName": "Maba.VCT.CommServer.BL.HydraDevices.BLCore.KeysightEdux1002aBLCore" }
```

## מאסטרים

**אין.** הסקופ קורא ישירות את האות הנמדד ולא מחיל עקומת תיקון, ולכן ה-BL לא משתמש
ב-`HydraCalculations`. `Masters` נשאר ריק בכוונה.

הצד היחיד שמושפע: `ApplyWebSocketConfig` מנתב `LoggerConfiguration` לפי מזהה מאסטר. כדי לאפשר
קונפיגורציה מרחוק יש למלא את ה-MabaID מ-`dbo.AssignMeasurmentDevicesToCalibrator`.

## הודעת ה-WebSocket שיוצאת לאפליקציה

```
CMD:"LoggerData", DeviceID:"EDUX1002A", LoggerID:"EDUX1002A", BatchID:"LIVE",
Time:"09/01/2026 13:52:29", Units:"Volt", Resolution:"2", Channel:"1", Value:"1"
```

**היחידות נגזרות ממה שהמכשיר מודד.** שיוך מהאפליקציה (`SensorsAssociation` עם שדה `Units`)
תמיד גובר; כשאין שיוך, `ServerCore` קורא ל-`HardwareBL_Settings.DefaultUnitsForDeviceSN(SN)` — שממפה
SN → משפחה → `Sensor` → יחידה:

הכלל המנחה: **היחידה היא תכונה של הערך שיוצא, לא של הגודל שהמכשיר מודד על החוט.**
המיפוי חייב להסכים עם `HydraCalculations.ProcessResults`, שהוא מה שבאמת הופך קריאה לערך משודר:

| מדידה | יחידה | למה |
|-------|--------|-----|
| `VoltagePP` / `VoltageRMS` / `VoltageDC` | `Volt` | וולט אמיתי |
| `Frequency` | `Hertz` | |
| `Resistance` | `Ohm` | |
| `TEMP` / `Dew` | `Celsius` | נקודת טל היא טמפרטורה |
| **`VDC`** | **`Celsius`** | **השם מטעה** — `ProcessResults` ממיר אותו ITS-90 מהתנגדות למעלות |
| `Humidity` | `Celsius` | הערך הראשי הוא טמפרטורה; הלחות היא הערך השני |
| חיישן RTD / FRTD / תרמוקופל | `Celsius` | **גובר על ה-MeasureType** — ה-BL ממיר לפני השידור |

לכן נוסף `VoltageDC = 8` — ערך נפרד לוולט אמיתי, כדי שהסקופ לא ישאל את האיות הישן `VDC`.

**אף מכשיר קיים לא שינה התנהגות.** כולם ממשיכים לשדר `Celsius`; ה-TTI22 (גשר מדידה שקורא
התנגדות של PRT ומשמש גם לטמפרטורה) מסומן עכשיו `SensType = FRTD` כדי שיצא `Celsius`
דרך הכלל הכללי ולא דרך חריג נקודתי. `ProcessResults` מסתכל רק על `MeasureType`, אז שום חישוב לא זז.

## פתוח

- הרצה ממושכת: לוודא שסבב שני הערוצים (≈2s לכל מדידה) לא מרעיב מכשירים אחרים על אותו שרת.
- `datasheet.pdf` עדיין לא הורד לתיקייה. המדריך:
  https://www.keysight.com/us/en/assets/9018-07554/programming-guides/9018-07554.pdf
