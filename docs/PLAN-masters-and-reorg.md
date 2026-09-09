# תכנית: מאסטרים מרובים + סידור מבנה הפרויקט

מסמך זה מכסה שלוש בקשות:
1. **מאסטרים** — תמיכה בכמה מאסטרים לוגיים פעילים בו-זמנית (היום: מאסטר יחיד).
2. **סידור קבצים** — שרת תחת `Systems/`, ממשק תחת `app/`, ארכוב קוד ישן.
3. **מסמכי מכשירים** — תיקייה ייעודית (בוצע → `docs/devices/`).

---

## חלק 1 — מאסטרים מרובים (Multiple logical masters)

### המצב היום
- "מאסטר" = מזהה תקן ייחוס (למשל `21-449`) שנטען מ-SQL ומחיל עקומת תיקון.
- ההגדרה: `HardwareBL_DeviceType.Masters : List<string>` לכל סוג מכשיר
  (`Systems/VCT/VCT/VCT.Common/Settings/HardwareBL_DeviceType.cs:19`).
- טעינה: כל BL קורא `HC.Init(settings.<Type>.Masters)` → `CalibrationRepository.InitMasters(List<string>)`
  (`Systems/Hydra-Group/ComServer/ComServerBL/ComServerBL.DAL/Calibration/CalibrationRepository.cs:132`).
  **כבר תומך ברשימה** — כל המאסטרים נטענים ל-cache.
- **צוואר הבקבוק:** בזמן חישוב לוקחים אחד בלבד:
  `masterID = settings.Hydra2type.Masters.FirstOrDefault()` (`.../Device/Hydra2DeviceBL.cs:487`)
  → `HC.CalcDeviationForTemperature(rawValue, masterID)`.
- מיפוי `IP2Scan` (`ComServer.Core/Settings/ComServerSettings.cs:58`) ממפה IP מכשיר → מזהה מאסטר יחיד.

### המטרה
לאפשר שיוך של כמה מאסטרים פעילים בו-זמנית ובחירת המאסטר הנכון פר-ערוץ / פר-מכשיר / פר-סוג-מדידה,
במקום תמיד הראשון ברשimה.

### שלבי מימוש
1. **בחירת מאסטר מפורשת במקום `FirstOrDefault()`**
   - להוסיף שיטת `ResolveMaster(channel, sensorType)` ל-`HydraCalculations` שמחזירה את מזהה
     המאסטר המתאים מתוך הרשימה שנטענה, לפי כלל שיוך (ראה 2).
   - להחליף את כל מופעי `Masters.FirstOrDefault()` בקריאה ל-`ResolveMaster(...)`.
   - קבצים מושפעים: כל `*DeviceBL.cs` תחת `Systems/Hydra-Group/.../Device/` (חפש `Masters.FirstOrDefault`).

2. **מודל שיוך מאסטר→ערוץ/טווח**
   - להרחיב את `HardwareBL_DeviceType` בשדה מיפוי, למשל
     `Dictionary<string,string> ChannelToMaster` או `List<MasterAssignment>`
     (ערוץ/טווח/סוג-חיישן → מזהה מאסטר).
   - נשמר ב-`HydraBL_Settings.json` — שינוי config בלבד, בלי קומפילציה מחדש להוספת שיוך.
   - ברירת מחדל תואמת-אחורה: אם אין מיפוי → התנהגות ישנה (מאסטר ראשון).

3. **הכללת `IP2Scan`** (אם צריך כמה מאסטרים פר-מכשיר-פיזי)
   - `Dictionary<string,string>` → `Dictionary<string,List<string>>` או רשומת שיוך,
     ב-`ComServerSettings.cs:58`.

4. **חשיפה ל-ממשק (app)**
   - להוסיף בהודעת ה-`LoggerData` היוצאת את מזהה המאסטר שהוחל
     (`ServerCore.BroadcastToWebSockets`, `Systems/VCT/VCT/VCT.Core/.../ServerCore.cs:146`).
   - שקול הודעת "device/master list" ל-frontend (היום אין discovery מפורש — ראה הערה למטה).

5. **בדיקות**
   - להרחיב את בדיקות ה-NUnit ב-`Systems/VCT/VCT/VCT.Core.Tests/` (יש כבר `Hydra2DeviceBLTests`)
     לכיסוי בחירת מאסטר לפי ערוץ ותאימות-אחורה.

### מודל המאסטר (הובהר ע"י המשתמש)
- **מאסטר = LOGGER** (מכשיר), בדיוק כמו שה-Hydra הוא logger בקוד (`SN`, `LoggerID`, ערוצים).
- ללוגר מחוברים **מספר ערוצים**, ו**כל ערוץ הוא בעצמו מאסטר** (מזהה ייחוס משלו).
- ⇒ מספר לוגרים-מאסטרים, כל אחד עם מספר ערוצים-מאסטרים. **השיוך הוא פר-ערוץ**
  (`channel → masterID`), עם הלוגר כמיכל.

### השלכה על המימוש
- מבנה השיוך: `Dictionary<int,string> ChannelToMaster` פר-לוגר (מפתח=ערוץ, ערך=מזהה מאסטר),
  או `List<MasterAssignment { LoggerSN, Channel, MasterId }>` גלובלי.
- `ResolveMaster(loggerSN, channel)` מחליף את `Masters.FirstOrDefault()`.
- כל ערוץ בלוגר-מאסטר צריך רשומת מאסטר משלו ב-`HydraBL_Settings.json` / `IP2Scan`.

---

### משימה עתידית: מכשיר אלקטרוניקה חדש בחיבור סריאלי
המשתמש יחבר פיזית מכשיר מדידת אלקטרוניקה חדש (Serial), ויממש עבורו BL חדש לפי מסמכי PDF.
זהו ה-"recipe" של הוספת מכשיר (ראה חלק המימוש למעלה): (1) זיהוי SN ב-`HardwareDeviceHost.handlePacket`,
(2) `IBLCore` חדש תחת `Systems/Hydra-Group/.../BLCore/`, (3) `BaseBLDevice` subclass תחת `.../Device/`,
(4) sessions אם הפרוטוקול שונה, (5) config ב-`HydraBL_Settings.json` כולל `Masters`.
לפני מימוש — לקבל מהמשתמש את ה-PDF (datasheet + פקודות הפרוטוקול) ולשמור תחת
`docs/devices/<שם-המכשיר>/`. כל מכשיר כזה הוא logger-מאסטר עם ערוצים-מאסטרים (ראה מודל המאסטר).

## חלק 2 — סידור מבנה הפרויקט

### עקרון מנחה
- **שרת** (כל קוד ה-C#/.NET) → תחת `Systems/`.
- **ממשק** → תחת `app/` (נשאר **git repo נפרד**; לא submodule, לא נגיעה ב-`.git` הפנימי).
- **מסמכים** → `docs/` (כולל `docs/devices/`).
- **ארכיון** → קוד/פרויקטים ישנים שאינם בשימוש → `archive/`.

### מצב נוכחי (בעיות)
- פרויקטי C# ישנים מפוזרים בשורש: `Convert/`, `CSV writer/`, `DeviationCalculation/`,
  `MasterCalibration/`, `Modbus/`, `SaveDeviationValuesForMaster/`, `XML Convert/`,
  `VpnConsoleApp/`, `Try/`, `Convert/`, `Convertor/`, `Tools/`.
- סקריפטי הרצה כפולים בשורש: `start-server.ps1`, `start-server2.ps1`, `start-server3.ps1`,
  `restart-server.ps1`, `launch-server.vbs`, `run-project.ps1`, `Start-Calibration-Stack.ps1`.
- קבצי לוג זרוקים בשורש: `consolehost_*.log`, `hydra_*.log`, `server_live.log`.

### פעולות ובוצע
1. ✅ **לוגים** → נמחקו 8 קבצי `*.log` מהשורש (היו untracked; `*.log` כבר ב-`.gitignore`).
2. ✅ **סקריפטים זרוקים** → `archive/scripts/`: `start-server.ps1/2/3`, `restart-server.ps1`,
   `launch-server.vbs` (נתיבים אבסולוטיים קשיחים, אף אחד לא מפנה אליהם).
3. ✅ **סקריפטים תפעוליים נשארים בשורש** (החלטה): `build.ps1`, `Build-Installer.ps1`,
   `Install-Service.ps1`, `Uninstall-Service.ps1`, `run-project.ps1`, `Start-Calibration-Stack.ps1`,
   `Run-VCT-Core-Coverage.ps1`. ⚠️ 4 מהם "dual-layout" (מזהים מבנה מותקן מול פיתוח לפי `$PSScriptRoot`)
   והמתקין מעתיקם לתיקיית ההתקנה בציפייה שהם בשורש — העברה ל-`scripts/` הייתה שוברת התקנה/שירות.
   תועדו ב-README הראשי.
4. ✅ **README ראשי** → נכתב מחדש עם מפת המבנה (`Systems/` שרת, `app/` ממשק, `docs/`, `archive/`)
   וטבלת הסקריפטים.
5. ✅ **ארכוב קוד C# ישן** → הועברו ל-`archive/` (עם `git mv`, שימור היסטוריה):
   - **מחוץ ל-`.sln`:** `Convertor/`, `VpnConsoleApp/`, `Try/`.
   - **הוסרו מה-`.sln`:** `DeviationCalculation/`, `Convert/`, `XML Convert/`, `MasterCalibration/`,
     `Modbus/`, `CSV writer/`, `SaveDeviationValuesForMaster/` — כולם היו מקוננים תחת solution-folder
     בשם "Try". הוסרו 247 שורות מה-`.sln` (בלוקי Project/EndProject + קונפיגורציות + NestedProjects).
   - ✅ **אימות:** `Project(`/`EndProject` מאוזנים (66=66), אפס GUID שנותרו,
     ובניית `ComServer.Hosts.ConsoleHost` עברה (**EXIT 0**).
6. ✅ **`app/`** → נשאר כמות שהוא (git repo נפרד). הקשר server↔app תועד ב-README.

### מבנה השורש בפועל (אחרי הסידור)
`app/` `archive/` `docs/` `Installer/` `Libraries/` `packages/` `Systems/` `TestResults/` `Tools/`
+ סקריפטים תפעוליים + `UnifiedSystemV1.sln` + `README.md` + `DEVELOPMENT_PLAN.md`.

### מבנה יעד
```
Calibration-software/
├─ Systems/            # השרת (C#/.NET) — VCT + Hydra-Group
├─ app/                # הממשק (Next.js) — git repo נפרד
├─ docs/               # תיעוד, כולל docs/devices/
├─ scripts/            # סקריפטי הרצה/בנייה מאוחדים
├─ Installer/          # מתקין
├─ archive/            # פרויקטי C# ישנים שאינם בשימוש
├─ UnifiedSystemV1.sln
└─ README.md
```

### סיכונים
- **ה-`.sln` והפניות פרויקט** מכילים נתיבים יחסיים — כל העברת תיקייה דורשת עדכון הנתיב ב-`.sln`
  ובכל `ProjectReference` שמצביע אליה. יש לאמת בנייה (`build.ps1`) אחרי כל צעד.
- אין לגעת ב-`app/.git` ואין למזג אותו ל-repo הראשי.

---

## חלק 3 — מסמכי מכשירים ✅ בוצע
נוצרה `docs/devices/` עם תיקייה לכל מכשיר נתמך (Hydra 2625A/2638A, Agilent 34401A, Additel,
Optidew, TTI, Instek), `_template/` להוספת מכשיר חדש, ו-`README.md` מסביר.

---

## סדר ביצוע מוצע
1. ✅ מסמכי מכשירים (`docs/devices/`).
2. סידור קבצים (חלק 2) — לוגים → סקריפטים → ארכוב, עם אימות בנייה בין צעד לצעד.
3. מאסטרים מרובים (חלק 1) — אחרי הכרעת שאלת השיוך (פר-ערוץ/טווח/חיישן).
