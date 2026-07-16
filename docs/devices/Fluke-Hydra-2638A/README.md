# Fluke Hydra 2638A

## זיהוי
- **דגם מלא:** Fluke Hydra Series III 2638A (data acquisition system)
- **טוקן זיהוי ב-SN (`*IDN?`):** `2638`
- **מחלקת BL:** `Systems/Hydra-Group/ComServer/ComServerBL/Device/Hydra3DeviceBL.cs`
- **BLCore:** `Systems/Hydra-Group/ComServer/ComServerBL/BLCore/Hydra3BLCore.cs`

## חיבור פיזי
- **תעבורה:** Serial / TCP.
- **מס' ערוצים:** רב-ערוצי (logger).

## פרוטוקול תקשורת
- **דיאלקט:** דמוי-SCPI (משפחת Hydra). ראה `Fluke-Hydra-2625A` להתנהגות ה-`=>` prompt.

## מאסטרים / ערכי ייחוס
- דרך `CalibrationRepository.InitMasters` (ראה `docs/PLAN-masters-and-reorg.md`).

## מסמכים (להוסיף לתיקייה זו)
- `datasheet.pdf`, `protocol.md`, `calibration-procedure.md`
