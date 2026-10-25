# Fluke Hydra 2625A

## זיהוי
- **דגם מלא:** Fluke Hydra Series II 2625A (data acquisition unit / logger)
- **טוקן זיהוי ב-SN (`*IDN?`):** `2625` / `FLUKE`
- **מחלקת BL:** `Systems/Hydra-Group/ComServer/ComServerBL/Device/Hydra2DeviceBL.cs`
- **BLCore:** `Systems/Hydra-Group/ComServer/ComServerBL/BLCore/Hydra2BLCore.cs`

## חיבור פיזי
- **תעבורה:** Serial (RS-232) — טיפוסית COM3 @ 9600 baud, או TCP.
- **מס' ערוצים:** רב-ערוצי (logger).

## פרוטוקול תקשורת
- **דיאלקט:** דמוי-SCPI. כל תשובת פקודה שולחת prompt `=>` **לפני** `\r\n`.
- **רצף מצבים:** `*RST → DATE → TIME → RATE → INTVL → FUNC → LOG_CLR → SCAN 1 → LOG_COUNT` (polling).
- **נתוני סריקה:** `E,SN,CH,VALUE\r\n`.
- **תשובה לשאילתה:** שורת הנתונים קודם, ואחריה ה-prompt `=>`.
- **`LOGGED? <n>`:** מחזיר סריקה שמורה: `hh,mm,ss,MM,dd,yy` (זמן הסריקה לפי שעון הלוגר), ואחריו הערכים.
  `n` בין 1 ל-2047. המדריך לא מציין איזה קצה הוא 1, ולכן סדר השליחה נקבע לפי זמן הסריקה.
- **שעון (MBA-967):** `TIME <hh>,<mm>` מאפס את השניות ל-00, ואי אפשר לקבוע שניות (מדריך 2620A/2625A,
  טבלה 4-8). `TIME_DATE?` כן מחזיר שניות, ולכן ההפרש בין שעון הלוגר לשעון המחשב נמדד ולא נקבע.
- **רזולוציה 0.1 °C:** אמבט יציב נותן סריקות זהות לגמרי. ערך שחוזר על עצמו אינו סימן לתקיעה.

## מאסטרים / ערכי ייחוס
- מזהי מאסטר נטענים דרך `CalibrationRepository.InitMasters` (ראה `docs/PLAN-masters-and-reorg.md`).

## מסמכים (להוסיף לתיקייה זו)
- `datasheet.pdf` — מפרט יצרן
- `protocol.md` — טבלת פקודות מלאה
- `calibration-procedure.md` — נוהל כיול
