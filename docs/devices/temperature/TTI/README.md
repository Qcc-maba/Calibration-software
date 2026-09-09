# TTI

## זיהוי
- **דגם מלא:** TTi (Thurlby Thandar Instruments) — ספק כוח / מכשיר מדידה
- **טוקן זיהוי ב-SN:** `TTI` (`IdentificationType = TTI`)
- **BLCore:** `Systems/Hydra-Group/ComServer/ComServerBL/BLCore/TTIBLCore.cs`

## חיבור פיזי
- **תעבורה:** Serial / TCP.

## פרוטוקול תקשורת
- **דיאלקט:** ייעודי (`IdentificationType = TTI`, ראה `DeviceSettings.cs`).

## מאסטרים / ערכי ייחוס
- דרך `CalibrationRepository.InitMasters` (ראה `docs/PLAN-masters-and-reorg.md`).

## מסמכים (להוסיף לתיקייה זו)
- `datasheet.pdf`, `protocol.md`, `calibration-procedure.md`
