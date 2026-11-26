# Instek (GW Instek)

> ⚠️ **ה-BL הזה מעולם לא הושלם ואינו נטען בתחנות.** ה-GW Instek DAQ-9600 מזוהה לפני הענף הזה ומטופל
> ב-`Daq9600BL` — ראה [`../GW-Instek-DAQ-9600/protocol.md`](../GW-Instek-DAQ-9600/protocol.md) (MBA-1058).
> הרצף כאן (`TRIG:COUN INF` ואחריו `READ?`) לא היה מחזיר קריאה לעולם, ו-`Build_InstekConf` דורס את
> הפקודה ב-R, ב-RTD וב-VDC.

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
