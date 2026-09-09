# Calibration Software (MABA VCT)

מערכת כיול: **שרת** תקשורת חומרה (C#/.NET 4.8) + **ממשק** web (Next.js).
השרת מדבר עם מכשירי מדידה (Fluke Hydra, Agilent, Additel, TTI, Instek, Optidew) ומזרים
מדידות ל-frontend דרך WebSocket.

## מבנה הפרויקט

| תיקייה | תוכן |
|--------|------|
| `Systems/`   | **השרת.** כל קוד ה-C#. `Systems/VCT/` = תשתית (תעבורה, sessions, WebSocket, core); `Systems/Hydra-Group/` = לוגיקת המכשירים (BLCore + DeviceBL לכל דגם). |
| `app/`       | **הממשק** (Next.js). ⚠️ git repo **נפרד** משלו — לא submodule; אין למזג ל-repo הראשי. |
| `docs/`      | תיעוד. `docs/devices/` = מסמכי המכשירים (datasheet, פרוטוקול, נוהל כיול, מאסטרים). |
| `Installer/` | מתקין (Inno Setup) + `CalibrationLauncher`. |
| `Libraries/` | ספריות משותפות (connectors, DAL). |
| `scripts/`   | כל סקריפטי ההרצה/בנייה/שירות (PowerShell). |
| `Tools/`     | כלי עזר (LanguageGenerator וכו'). |
| `archive/`   | קוד/סקריפטים ישנים שאינם בשימוש. אינו נבנה. |
| `UnifiedSystemV1.sln` | ה-solution הראשי של השרת. |

## סקריפטים (`scripts/`)

כל הסקריפטים מזהים את שורש הפרויקט אוטומטית (resolver שעובד גם מ-`scripts/` בפיתוח וגם משורש
ההתקנה). 3 מהם (`Install-Service`, `Uninstall-Service`, `run-project`) **נשלחים ע"י המתקין**
(`Installer/setup.iss` → מותקנים בשורש ההתקנה).

| סקריפט | תפקיד |
|--------|-------|
| `build.ps1`                   | בניית ה-ConsoleHost (Debug) דרך MSBuild. |
| `Build-Installer.ps1`         | בניית app + ConsoleHost + קומפילציית מתקין (`-Version x.y.z`). |
| `Install-Service.ps1`         | התקנת השרת כ-Windows Service (דורש הרשאת מנהל). נשלח ע"י המתקין. |
| `Uninstall-Service.ps1`       | הסרת ה-Service. נשלח ע"י המתקין. |
| `run-project.ps1`             | לאנצ'ר **production** (מכונה מותקנת): שרת + web app + דפדפן. נשלח ע"י המתקין. |
| `Start-Calibration-Stack.ps1` | לאנצ'ר **פיתוח**: עצירת מופעים + ConsoleHost (Debug) + `pnpm dev`. |
| `Run-VCT-Core-Coverage.ps1`   | בדיקות VCT.Core + כיסוי (נכשל מתחת ל-95%). |

## הרצה מהירה (פיתוח)

```powershell
.\scripts\Start-Calibration-Stack.ps1 -BuildServer   # בונה ומריץ שרת + ממשק
# ממשק:    http://localhost:3000
# WebSocket: ws://localhost:5001/ws/   (תואם NEXT_PUBLIC_WEBSOCKET_URL ב-app\.env.local)
```

> הערה: `packages/` ו-`bin/`/`obj/` אינם ב-git ונמחקים בניקוי — לפני בנייה ראשונה הרץ `nuget restore`
> (או בנייה דרך Visual Studio שמריץ restore אוטומטית).

## תיעוד נוסף
- **`docs/architecture.md` — התחל כאן.** הצינור מקצה לקצה (ComLayer → DeviceHost → Sessions → BL →
  WebSocket), מחזור חיי ה-session, מכונת המצבים, מתכון להוספת מכשיר, וטבלת דיבוג.
- `docs/DEVELOPMENT_PLAN.md` — תכנית פיתוח.
- `docs/PLAN-masters-and-reorg.md` — תכנית מאסטרים מרובים + סידור מבנה.
- `docs/devices/README.md` — מסמכי המכשירים הנתמכים.
