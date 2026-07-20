# ארכיטקטורה — שרת ה-VCT

מסמך זה מסביר איך מדידה עוברת ממכשיר פיזי אל ה-web app. זהו מסמך הקליטה המרכזי:
אם אתה מוסיף מכשיר, מדבג מכשיר ש"שותק", או משנה את זרימת הנתונים — התחל כאן.

> קוד השרת כולו תחת `Systems/`. הממשק (`app/`) הוא repo נפרד.

---

## 1. הצינור מקצה לקצה

```
מכשיר פיזי
    │  RS-232 / TCP / Modbus
    ▼
IComLayer            SerialCom · SocketCom · ModbusCom · WebSocketCom
    │                (Systems/VCT/VCT/VCT.ComLayer/Com Layer/)
    │  DataReceived (בתים גולמיים)
    ▼
HardwareDeviceHost   מארח אחד לכל מכשיר פיזי
    │                (VCT.Core/Device/HardwareDeviceHost.cs)
    │  ├─ HydraProtocolParser  → חותך בתים לחבילות (HardwarePacket)
    │  ├─ זיהוי SN             → handlePacket, לפי תשובת *IDN?
    │  └─ Sessions[]           → מנתב חבילה ל-session שממתין לה
    ▼
BaseSession          תור בקשות + "בקשה אחת בכל רגע"
    │                (VCT.Core/Device/Sessions/)
    │  CallBackResponse
    ▼
IDeviceBL / BaseBLDevice   מכונת מצבים לוגית לכל מכשיר
    │                      (VCT.ComServer.BL.Common + Hydra-Group/.../Device/)
    │  BroadcastAllMeasurements(channels, values)
    ▼
"E,SN,ch,val,..."  →  IncomingEvents  →  EventsBus
    │
    ▼
ServerCore.BroadcastToWebSockets  →  הודעת LoggerData  →  לקוחות WebSocket (app)
```

---

## 2. השחקנים

### `ServerCore` — התזמורת
`Systems/VCT/VCT/VCT.Core/ServerCore.cs`

אחראי על:
- **פתיחת ה-tunnels** מתוך `VCTSettings.Tunnels` — כל tunnel הוא TCP (כתובת+פורטים) או סריאלי
  (`SerialPortName`; הערך `"AUTO"` מפעיל זיהוי אוטומטי של מתאם USB-serial).
- **מכשירים ממתינים (pending)** — טיימר של 2 שניות שולח חבילת זיהוי (`*IDN?` / TTI / Modbus)
  לכל חיבור חדש, עד שמתקבל SN.
- **קידום ל-identified** — כשיש SN, המכשיר עובר לרשימת המכשירים, `InitSessions()` רץ,
  ואירוע חיבור נשלח כדי שאחד ה-`IBLCore` "יתבע" אותו.
- **מאזין ה-WebSocket** — `HttpListener` על `WebSocketListenPrefix` (ברירת מחדל `http://localhost:5001/ws/`).

### `HardwareDeviceHost` — מכשיר אחד
`VCT.Core/Device/HardwareDeviceHost.cs`

עוטף `IComLayer` אחד ומחזיק: `SN`, פרסר, מערך `Sessions`, ו-`BL`.
בתים נכנסים → פרסר → `handlePacket` → מנותב ל-sessions.

**זיהוי ה-SN** ב-`handlePacket` הוא שרשרת התאמות מחרוזת על תשובת ה-`*IDN?`
(`FLUKE`, `HEWLETT`, `TAU`, `TTI`, `Instek`, ו-Modbus→`Optidew`). זו הנקודה הראשונה
שצריך לגעת בה כשמוסיפים דגם חדש.

### `BaseSession` — טרנזקציה מול המכשיר
`VCT.Core/Device/Sessions/` — `InitSystemSession`, `GetSetTimeSession`, `RateSession`,
`InitChannelsSession`, `LogsSession`.

החוזה פשוט אך קריטי:
- לכל session יש `ConcurrentQueue<BaseRequest>`.
- בכל טיק, אם `Avilable4Transport` (כלומר `LastRequest == null`) — מוציא בקשה אחת ושולח אותה.
- כשמגיעה התשובה, ה-session קורא ל-callback ו**מנקה את `LastRequest`** — וזה מה שמאפשר
  לבקשה הבאה לצאת.
- אם התשובה לא מגיעה, **`SessionRequestTimeout_TimeSpan`** משחרר את ה-session
  (`LastRequestTimedOut()` מחזיר תשובה עם `Result=false`).

> ⚠️ זהו המקום שבו מכשיר "נתקע": אם `LastRequest` לא מתנקה, התור לא מתנקז והמכשיר מפסיק
> למדוד בשקט. ה-timeout הוא רשת הביטחון.

### `BaseBLDevice` + `SingleState` — הלוגיקה
`Systems/VCT/ComServer/BL/VCT.ComServer.BL.Common/`

הלוגיקה של כל מכשיר היא **מכונת מצבים**: מערך `SingleState` מסודר, שכל אחד מהם מריץ
`Action_DoWork` שמחזיר `StepWorkResponses` (`Skip2NextStep` / `StateFinished`).
`DeviceSteps` (`Start` / `Routine` / `Close`) הוא מחזור החיים הגס.

דוגמה (34401A): `InitSystem` שולח `*RST → *CLS → SYST:REM → CONF → AUTO RANGE`,
ואז מצב `Logs` מנפיק `READ?` בלולאה מונעת-callback.

### `IBLCore` — משפחת מכשירים
`Hydra-Group/ComServer/ComServerBL/BLCore/` — אחד לכל משפחה (Hydra2/3, Agilent, Additel, TTI, Instek, Optidew).

`OnDeviceConnetion` בודק אם ה-SN שייך למשפחה שלו; אם כן הוא יוצר BL ומצמיד אותו למכשיר.
**כל core מחזיק `ConcurrentDictionary<SN, BL>`** — כלומר כמה מכשירים מאותה משפחה יכולים
לרוץ במקביל, ו-`OnEvent` מנתב לפי `e.Device.SN`.

---

## 3. הגדרות (3 קבצים)

| קובץ | מחלקה | מה בפנים |
|------|-------|----------|
| `VCT.json` | `VCTSettings` | `Tunnels[]` (TCP/סריאלי), `DeviceSettings[]` (סוג זיהוי, timeouts), `WebSocketListenPrefix` |
| `ComServerSettings.json` | `ComServerSettings` | `Modules[]` — אילו `IBLCore` להעלות (reflection), ו-`IP2Scan` (IP→מזהה מאסטר) |
| `HydraBL_Settings.json` | `HardwareBL_Settings` | הגדרות פר-סוג-מכשיר: ערוצים, קצב, חיישן, ו-`Masters[]` |

**מאסטרים:** מזהי תקן ייחוס שנטענים מ-SQL דרך `CalibrationRepository.InitMasters` ומחילים
עקומת תיקון על הקריאה. ראה `docs/PLAN-masters-and-reorg.md`.

---

## 4. הוספת מכשיר חדש — המתכון

1. **זיהוי SN** — הוסף ענף ב-`HardwareDeviceHost.handlePacket` שמזהה את תשובת ה-`*IDN?`.
2. **`IBLCore`** חדש תחת `BLCore/` — התאמת SN + יצירת ה-BL (העתק את התבנית מ-`Agilent34401aBLCore`).
3. **`BaseBLDevice`** חדש תחת `Device/` — הגדר את מכונת המצבים ב-`OnCreateStates`.
4. **Sessions** — רק אם הפרוטוקול לא מתאים לקיימים.
5. **הגדרות** — הוסף סוג מכשיר ל-`HardwareBL_Settings` (כולל `Masters`), ורשום את ה-BLCore
   ב-`ComServerSettings.Modules`.
6. **תיעוד** — צור `docs/devices/<שם>/` עם ה-PDF והפרוטוקול (ראה `docs/devices/_template/`).

דוגמה מלאה ומאומתת מקצה לקצה: `docs/devices/Agilent-34401A/protocol.md`.

---

## 5. דיבוג — מאיפה להתחיל

| תסמין | לבדוק |
|-------|-------|
| המכשיר לא מזוהה | הגיעה תשובת `*IDN?`? האם השרשרת ב-`handlePacket` מכסה אותה? `IdentificationType` נכון? |
| זוהה אך אין מדידות | האם `IBLCore` תבע אותו (התאמת SN)? האם המודול רשום ב-`ComServerSettings.Modules`? |
| מדד ואז נעצר | ה-session תקוע — `LastRequest` לא התנקה. בדוק את ה-timeout ואת לוג ה-session. |
| סריאלי לא מגיב | baud/handshake. מכשירי SCPI (34401A) דורשים DTR/DSR, **לא** XON/XOFF. |
| אין נתונים ב-app | `BroadcastToWebSockets` רץ? ה-`NEXT_PUBLIC_WEBSOCKET_URL` תואם ל-`WebSocketListenPrefix`? |

הרצה מקומית: `.\scripts\Start-Calibration-Stack.ps1 -BuildServer`, או ה-GUI
(`ComServer.Hosts.GUIMonitor`) שמאפשר גם מצב סריאלי בלי לפתוח פורטי TCP.
