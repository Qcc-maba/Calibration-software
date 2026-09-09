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

## מאסטרים / ערכי ייחוס
- מזהי מאסטר נטענים דרך `CalibrationRepository.InitMasters` (ראה `docs/PLAN-masters-and-reorg.md`).

## מסמכים (להוסיף לתיקייה זו)
- `datasheet.pdf` — מפרט יצרן
- `protocol.md` — טבלת פקודות מלאה
- `calibration-procedure.md` — נוהל כיול
