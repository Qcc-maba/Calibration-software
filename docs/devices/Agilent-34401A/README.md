# Agilent / Keysight 34401A

## זיהוי
- **דגם מלא:** Agilent (HP) / Keysight 34401A Digital Multimeter (6½ digit DMM)
- **טוקן זיהוי ב-SN (`*IDN?`):** `HEWLETT`
- **BLCore:** `Systems/Hydra-Group/ComServer/ComServerBL/BLCore/Agilent34401aBLCore.cs`

## חיבור פיזי (מאומת 2026-07-16)
- **תעבורה:** RS-232 דרך USB-to-Serial (Prolific PL2303) → **COM3**.
- **הגדרות:** **9600** 8-N-1, DTR/DSR (DtrEnable+RtsEnable), terminator `\r\n`.
- **מס' ערוצים:** ערוץ יחיד (DMM). firmware `10-5-2`.

## פרוטוקול תקשורת
- **דיאלקט:** SCPI. `*IDN?` → `HEWLETT-PACKARD,34401A,0,10-5-2`.
- **הפרוטוקול המלא והמאומת:** ראה [protocol.md](protocol.md) — כולל רצף `*RST/*CLS/SYST:REM/CONF/READ?`.

## מאסטרים / ערכי ייחוס
- דרך `CalibrationRepository.InitMasters` (ראה `docs/PLAN-masters-and-reorg.md`).

## מסמכים (להוסיף לתיקייה זו)
- `datasheet.pdf`, `protocol.md`, `calibration-procedure.md`
