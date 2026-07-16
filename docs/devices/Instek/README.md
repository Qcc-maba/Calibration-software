# Instek (GW Instek)

## זיהוי
- **דגם מלא:** GW Instek — מכשיר מדידה / ספק כוח
- **טוקן זיהוי ב-SN (`*IDN?`):** `Instek`
- **BLCore:** `Systems/Hydra-Group/ComServer/ComServerBL/BLCore/InstekBLCore.cs`
- **DeviceBL:** `Systems/Hydra-Group/ComServer/ComServerBL/Device/InstekDeviceBL.cs`

## חיבור פיזי
- **תעבורה:** Serial / TCP.

## פרוטוקול תקשורת
- **דיאלקט:** SCPI. פקודת זיהוי `*IDN?`.

## מאסטרים / ערכי ייחוס
- דרך `CalibrationRepository.InitMasters` (ראה `docs/PLAN-masters-and-reorg.md`).

## מסמכים (להוסיף לתיקייה זו)
- `datasheet.pdf`, `protocol.md`, `calibration-procedure.md`
