# Additel

## זיהוי
- **דגם מלא:** Additel (מד/בקר לחץ — pressure)
- **טוקן זיהוי ב-SN (`*IDN?`):** `TAU`
- **BLCore:** `Systems/Hydra-Group/ComServer/ComServerBL/BLCore/AdditelBLCore.cs`

## חיבור פיזי
- **תעבורה:** Serial / TCP.

## פרוטוקול תקשורת
- **דיאלקט:** SCPI-like. פקודת זיהוי `*IDN?` (מחזירה טוקן `TAU`).

## מאסטרים / ערכי ייחוס
- דרך `CalibrationRepository.InitMasters` (ראה `docs/PLAN-masters-and-reorg.md`).

## מסמכים (להוסיף לתיקייה זו)
- `datasheet.pdf`, `protocol.md`, `calibration-procedure.md`
