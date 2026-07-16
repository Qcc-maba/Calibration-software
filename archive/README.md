# archive/

קוד וסקריפטים ישנים שאינם בשימוש ואינם חלק מהבנייה (`UnifiedSystemV1.sln`).
נשמרים לצורך היסטוריה/עיון בלבד — **אין לבנות מכאן ואין להפנות לכאן מקוד פעיל.**

## תוכן

| פריט | מה זה |
|------|-------|
| `scripts/` | סקריפטי הרצה/דיבוג זרוקים עם נתיבים אבסולוטיים קשיחים: `start-server.ps1` / `start-server2.ps1` / `start-server3.ps1` (וריאציות הרצת ConsoleHost), `restart-server.ps1`, `launch-server.vbs`. הוחלפו ב-`Start-Calibration-Stack.ps1` / `run-project.ps1` שבשורש. |
| `Convertor/`      | כלי המרה ישן. לא היה ב-`.sln`. |
| `VpnConsoleApp/`  | קונסולת VPN ישנה. לא היה ב-`.sln`. |
| `Try/`            | ניסויים (`ClassLibraryTry`, `ConsoleApplication1/2`). לא היה ב-`.sln`. |
| `DeviationCalculation/` | WinForms ישן. **הוסר מה-`.sln`.** |
| `Convert/` (Convert_map2png) | WinForms ישן. **הוסר מה-`.sln`.** |
| `XML Convert/`    | כלי המרת XML ישן. **הוסר מה-`.sln`.** |
| `MasterCalibration/` | WinForms ישן. **הוסר מה-`.sln`.** |
| `Modbus/`         | ניסוי Modbus ישן. **הוסר מה-`.sln`.** |
| `CSV writer/`     | כלי CSV ישן. **הוסר מה-`.sln`.** |
| `SaveDeviationValuesForMaster/` | WinForms ישן. **הוסר מה-`.sln`.** |

7 הפרויקטים שהוסרו מה-`.sln` היו כולם מקוננים תחת solution-folder בשם "Try". אף פרויקט פעיל
לא הפנה אליהם, ובניית השרת (`ComServer.Hosts.ConsoleHost`) אומתה לאחר ההסרה. לשחזור פרויקט —
`git mv` בחזרה + הוספת בלוק `Project(...)` ל-`.sln` (ראה היסטוריית git של הקומיט).
