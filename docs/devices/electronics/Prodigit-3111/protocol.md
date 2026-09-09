# PRODIGIT 3111 — פרוטוקול

עומס אלקטרוני DC, **80V / 70A / 350W**, מסדרת 3110.

> **סטטוס: אומת מקצה לקצה מול החומרה — 2026-09-02.**
> זיהוי → מצב עומס → מדידה → שידור WebSocket (`Units:"Volt"`).
>
> ⚠️ **לא נמצא מדריך תכנות לדגם הזה.** כל מה שכתוב כאן מופה אמפירית מול המכשיר —
> זה מה שהוא **באמת ענה**, לא מה שספר טוען.

## זיהוי

- **תשובת `*IDN?` בפועל:**
  ```
  PRODIGIT_3111
  ```
  **טוקן דגם חשוף בלבד** — בלי יצרן, בלי מספר סידורי, בלי גרסת קושחה. שונה מכל מכשיר אחר כאן.
- **`VER?`** → `MF r0.2`
- **מחלקת BL:** `Systems/Hydra-Group/ComServer/ComServerBL/Device/Prodigit3111BL.cs`
- **BLCore:** `Systems/Hydra-Group/ComServer/ComServerBL/BLCore/Prodigit3111BLCore.cs`
- **עזרי פענוח:** `Device/Prodigit3111Readings.cs`

## חיבור פיזי — RS-232

| | |
|---|---|
| **פורט** | COM10 (מתאם USB-Serial) |
| **הגדרות** | **115200** 8-N-1, ללא handshake, DTR+RTS פעילים |
| **סיומת** | `\r` או `\r\n` — שתיהן עובדות; התשובות מסתיימות ב-CRLF |
| **Tunnel** | `Prodigit-3111-Serial`, `"SerialPortName": "COM10"`, `"SerialBaudRate": 115200` |

**קצב השידור הוא 115200 ולא 9600.** ב-9600/19200/38400/57600 המכשיר שותק לחלוטין — זו הסיבה שסבב
הבדיקה הראשון נראה כאילו אין שם כלום.

### מלכודת הכבל

מתאם עם שבב **PL2303 לא-מקורי** נכשל בצורה מטעה: Windows מדווח `CM_PROB_NONE` ("working properly"),
מקצה מספר COM, והוא מופיע ב-`GetPortNames()` — אבל כל פתיחה נכשלת ב-
`"A device which does not exist was specified"`. הסימן המזהה הוא שם ההתקן עצמו:
`PL2303TA DO NOT SUPPORT WINDOWS 11 OR LATER`. החלפת הכבל לשבב מקורי פתרה את זה מיד
(השם הופך ל-`Prolific USB-to-Serial Comm Port`).

### התנגשות עם ה-tunnel האוטומטי

`DetectUsbToSerialPort` מחפש בין השאר "Prolific", ולכן ה-tunnel `SerialDevice_AUTO` (שמוגדר ל-9600
עבור מכשיר אחר) היה חוטף את COM10 ופותח אותו בקצב שגוי. `ServerCore` תוקן כך ש-**AUTO מדלג על כל
פורט ש-tunnel אחר תובע בשמו**:

```
[AutoDetect] Skipping COM10 = Prolific USB-to-Serial Comm Port (COM10) (claimed by a named tunnel)
```

## ערכת הפקודות — תת-קבוצה חלקית של SCPI

**עונה:**

| פקודה | תשובה |
|---|---|
| `*IDN?` | `PRODIGIT_3111` |
| `VER?` | `MF r0.2` |
| `MEAS:VOLT?` / `MEASURE:VOLTAGE?` | `+0.0000` |
| `MEAS:CURR?` / `MEASURE:CURRENT?` | `+0.0000` |
| `MEAS:POW?` / `MEASURE:POWER?` | `+0.0000` |
| `LOAD?` / `LOAD:STATE?` | `0` (עומס כבוי) |
| `MODE?` / `LOAD:MODE?` | `0` |
| `LOAD:CURR?` / `LOAD:VOLT?` | `0` |
| `LEVEL?` / `LEV?` | `1` |
| `PROT?` | `0` |
| `OCP?` / `OPP?` | `+0.0000` |
| `DYN?` | `0` |
| `SHORT?` / `SHOR?` | `0` |
| `ERR?` / `ERROR?` | `21` |

**שותק (לא נתמך):** `*OPC?`, `*ESR?`, `*STB?`, `SYST:ERR?`, `SYST:VERS?`, `INP?`, `INPUT?`,
`OUTP?`, `FUNC?`, `CURR?`, `VOLT?`, `RES?`, `POW?`, `CHAN?`, `CONF?`, `OVP?`,
`MEASURE:RESISTANCE?`

### ⚠️ אין ערוץ שגיאות שמיש

`SYST:ERR?` שותק, ו-`ERR?` מחזיר **21 קבוע** — הוא לא השתנה אחרי פקודה תקינה, לא אחרי פקודה שגויה
בכוונה, ולא התנקה בקריאה. זה מילת סטטוס, לא תור שגיאות.

**המשמעות: אי אפשר לשאול את המכשיר אם פקודה התקבלה.** שתיקה היא סימן הכישלון היחיד, ולכן ה-BL סופר
תשובות חסרות ועוצר אחרי 10 ברצף במקום לנסות לנצח.

## ⚠️ בטיחות — ה-BL הוא קריאה בלבד

המכשיר **מושך זרם** ממה שמחובר לכניסתו. לכן:

- **אף פקודה שמסוגלת לחמש את העומס לא נבנתה בכלל.** אזור ה-PRODIGIT ב-`HydraProtocolHelper` מכיל
  שאילתות בלבד. יש טסט שמאמת שכל פקודה שנבנית מסתיימת ב-`?`.
- **אין `*RST` באתחול.** לדגם אין reset מתועד, ועל מכשיר שמושך זרם לא שולחים reset בניחוש.
- ה-BL **מדווח** את מצב העומס (`LOAD?`) בלוג — ולעולם לא משנה אותו.

### רצף האתחול

| # | פקודה | למה |
|---|-------|-----|
| 0 | `VER?` | אימות שהערוץ חי; קריאה בלבד |

### לולאת המדידה

`LOAD?` (דיווח מצב) → `MEAS:VOLT?` / `MEAS:CURR?` / `MEAS:POW?` לפי ההגדרה.

הפענוח נעשה מ-`LogsResponse.RawText` ולא מ-`Measurements`: `LOAD?` מחזיר `0` חשוף, ואף אחד ממסלולי
הפרסור המספריים המשותפים לא מזהה את זה כמדידה. `LogsResponse.IsRawTextCommand` מסמן את
`LOAD?`/`MODE?`/`VER?`/`ERR?` (יחד עם `:BSWV`/`:OUTP` של Siglent) כתשובות שה-BL מפענח בעצמו.

קריאה שנכשלת בפענוח **נזרקת ולא הופכת ל-0** — כי 0 הוא גם מדידה אמיתית לגמרי על עומס, וברגע שהיא
שודרה אי אפשר להבדיל. כמו כן קריאה מעבר לדירוג (80V/70A/350W) נזרקת.

## הגדרות

`Settings/HydraBL_Settings.json`, מפתח `Prodigit3111`:

```json
"Prodigit3111": {
  "Channels": [ 1 ],
  "MaxNumOfChannels": 1,
  "Masters": [],
  "Sensor": { "MeasureType": 8, "SensType": -1 }
}
```

`MeasureType`: `8`=VoltageDC→`Volt`, `9`=Current→`Ampere`, `10`=Power→`Watt`.
הערכים 9 ו-10 נוספו ל-`SensorType.MeasureTypes` עבור המכשיר הזה.

## פתוח

- **הלולאה רצה מול כניסה ריקה בלבד** (0V/0A). לאמת מול DUT אמיתי, ולראות שהמעבר לעומס מחומש
  משתקף נכון בלוג.
- **הפקודות לחימוש העומס ולקביעת setpoint לא נבנו** — במכוון. כשיוחלט לחווט אותן, זה צריך להיות
  דרך פקודה מפורשת מהאפליקציה עם אישור, בדפוס של `Datron9100Commands.BuildOutputOn`.
- לא נמצא מדריך תכנות. אם יימצא — לאמת מולו את המיפוי, ובעיקר את משמעות `MODE?`, `LEVEL?` ו-`ERR?`.
