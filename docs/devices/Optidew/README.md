# Optidew

## זיהוי
- **דגם מלא:** Michell Optidew (chilled-mirror hygrometer — לחות/נקודת טל)
- **זיהוי:** דרך **Modbus** → `Optidew`
- **BLCore:** `Systems/Hydra-Group/ComServer/ComServerBL/BLCore/OptidewBLCore.cs`
- **DeviceBL:** `Systems/Hydra-Group/ComServer/ComServerBL/Device/OptidewDeviceBL.cs`

## חיבור פיזי
- **תעבורה:** Modbus (Serial/TCP).

## פרוטוקול תקשורת
- **דיאלקט:** Modbus registers (לא SCPI). זיהוי דרך `IdentificationType = Modbus`.

## מאסטרים / ערכי ייחוס
- דרך `CalibrationRepository.InitMasters` (ראה `docs/PLAN-masters-and-reorg.md`).

## מסמכים (להוסיף לתיקייה זו)
- `datasheet.pdf`, `modbus-map.md`, `calibration-procedure.md`
