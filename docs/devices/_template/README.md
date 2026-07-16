# <שם המכשיר> — תבנית תיעוד

העתק תיקייה זו, שנה שם למכשיר, ומלא את הסעיפים. מחק שורות שאינן רלוונטיות.

## זיהוי
- **דגם מלא:** <יצרן ודגם>
- **טוקן זיהוי ב-SN (`*IDN?`):** <למשל `2625` / `HEWLETT` / `TTI`>
- **מחלקת BL בקוד:** `Systems/Hydra-Group/ComServer/ComServerBL/Device/<Xxx>DeviceBL.cs`
- **BLCore:** `Systems/Hydra-Group/ComServer/ComServerBL/BLCore/<Xxx>BLCore.cs`

## חיבור פיזי
- **תעבורה:** Serial / TCP / Modbus
- **COM / Baud:** <COM3, 9600> — או —
- **IP / Port:** <10.3.3.x : xxxxx>
- **מס' ערוצים:** <n>

## פרוטוקול תקשורת
- **דיאלקט:** SCPI / Modbus / ייעודי
- **פקודת זיהוי:** <`*IDN?`>
- **פקודות עיקריות ותשובות:** <טבלה: פקודה → תשובה צפויה>

## מאסטרים / ערכי ייחוס
- **מזהי מאסטר:** <למשל `21-449`, `21-675`>
- **מקור ערכי התיקון:** stored-proc ב-SQL (ראה `CalibrationRepository.InitMasters`)

## קבצים בתיקייה זו
- `datasheet.pdf`
- `protocol.md`
- `calibration-procedure.md`
- `masters.md`
