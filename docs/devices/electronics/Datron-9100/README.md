# Datron / Wavetek 9100 — מכשיר מאסטר (GPIB)

מכייל רב-תכליתי (multifunction calibrator) המשמש כ**מאסטר** לכיול אלקטרוניקה.

## זיהוי וחיבור (נמדד 2026-07-30)
- **תעבורה:** GPIB (IEEE-488) דרך מתאם **National Instruments GPIB-USB-HS+** (VID_3923, PID_7618).
- **⚠️ הדרייבר לא מותקן:** המתאם ב-Device-Manager error **Code 28**. חובה להתקין **NI-488.2**
  (הורדה מ-ni.com) — בלעדיו אי אפשר לתקשר עם המכשיר כלל.
- **דרישת אריזה:** ה-NI-488.2 חייב להיות מותקן ע"י **מתקין התוכנה** (לא ידנית בפרודקשן) —
  ראה `Installer/DRIVERS.md`.
- **טוקן זיהוי (SN):** `Datron9100` — נקבע ב-`HardwareDeviceHost.handlePacket` כשתשובת הזיהוי
  מכילה `DATRON` / `WAVETEK` / `9100`. **פקודת הזיהוי המדויקת טרם אומתה** (ראה למטה).

## מה מומש בקוד
| רכיב | קובץ | מצב |
|------|------|------|
| טרנספורט GPIB | `Systems/VCT/VCT/VCT.ComLayer/Com Layer/GpibCom.cs` | ✅ P/Invoke ל-NI-488.2 (`gpib-32.dll`); query→read אוטומטי; מתקמפל |
| שדות tunnel | `Tunnel.GpibPrimaryAddress` / `GpibBoardIndex` | ✅ (`GpibPrimaryAddress >= 0` מפעיל GPIB) |
| פתיחה בשרת | `ServerCore.Start` — ענף GPIB | ✅ |
| זיהוי SN | `HardwareDeviceHost.handlePacket` | ✅ (DATRON/WAVETEK/9100) |
| BL | `BLCore/Datron9100BLCore.cs` + `Device/Datron9100BL.cs` | 🟡 **שלד** — פקודות placeholder |
| רישום מודול | `FormMain.Start` (GUI) | ✅ |

## 🟡 מה שדורש את מדריך התכנות של ה-9100
ה-BL הוא **שלד** עם פקודות generic של IEEE-488.2 כ-placeholder (`*RST`/`*CLS`/`SYST:REM`/`READ?`).
ה-9100 הוא מכשיר ותיק וייתכן שאינו תומך בהן. יש להחליף ב-`Datron9100BL.cs`:
- פקודת/רצף האתחול הנכון.
- פקודת קריאת הערך/פלט הנכונה (המכשיר הוא **מקור** — ייתכן שצריך לקרוא setpoint, לא מדידה).
- פורמט התשובה (לפרסור).
- פקודת/פורמט הזיהוי (אם לא `*IDN?`).

## להרצה (אחרי התקנת NI-488.2)
1. הגדר ב-`VCT.json` tunnel עם `GpibPrimaryAddress` = כתובת ה-GPIB של המכשיר (0-30) ו-`GpibBoardIndex` = 0.
2. הרץ את השרת/GUI → המכשיר אמור להיפתח, לקבל חבילת זיהוי, ולהיתבע ע"י `Datron9100BLCore`.
3. השלם את הפקודות ב-BL לפי המדריך ובדוק מול הערכים החיים.

> שים את מדריך ה-PDF של ה-9100 בתיקייה זו.
