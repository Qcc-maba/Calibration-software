# Priority — אינטגרציית API (OData)

קוד אינטגרציה מול **Priority ERP** דרך **OData v4 REST**, שהועתק מ-`maba2000-web/backend/Maba.Api`
(2026-07-30) לצורך שילוב/עיון בפרויקט זה.

> ⚠️ **הפרש framework:** המקור הוא **.NET 10 / ASP.NET Core** (primary constructors, file-scoped
> namespaces, `System.Text.Json`, `ILogger<T>`, `IHostedService`, Controllers). הפרויקט הזה הוא
> **.NET 4.8**. הקבצים **לא יתקמפלו כמות שהם** כאן — יידרשו התאמות (או פרויקט `net8`+ נפרד).

## מבנה שהועתק

| תיקייה | קבצים | תפקיד |
|--------|-------|-------|
| `Services/Priority/` | `PriorityODataClient.cs` | לקוח OData v4 דק: Basic-Auth (Token=PAT או user/pass), pagination (`@odata.nextLink`), כתיבה (POST), ומונה טרנזקציות |
| | `PriorityODataOptions.cs`, `PriorityODataOptionsProvider.cs` | קונפיגורציה (נטענת מ-`PrioritySync:OData`), שמות ישויות |
| `Services/Priority/Scenarios/` | `ShipmentScenarioService.cs` + `ShipmentDtos.cs` + `*Options.cs` + `ShipmentTriggerBackgroundService.cs` | תרחיש **משלוח** |
| | `ReturnGoodsScenarioService.cs` + `ReturnGoodsDtos.cs` + `*Options.cs` | תרחיש **החזרת סחורה** |
| | `PriorityScenarioCache.cs` | cache |
| `Services/` | `PriorityODataSyncService.cs` | סנכרון ברקע דרך ה-API |
| | `PrioritySyncService.cs` | סנכרון ישיר מול SQL Server (מנגנון שני, ישן) |
| | `PrioritySyncBase.cs`, `PrioritySyncBackgroundService.cs`, `PrioritySyncDispatcher.cs` | תשתית סנכרון |
| `Controllers/` | `PriorityScenariosController.cs`, `SyncController.cs` | נקודות קצה HTTP |
| `tools/PriorityODataProbe/` | `Program.cs`, `.csproj` | כלי CLI לבדיקת חיבור |

## ישויות (Priority screens)
`Users=MBA_USERSLOAD` · `Customers=MBA_CUSTLOAD` · `Documents=MBA_DOCLOAD` · `CalibStatus=MBA_CALIBLOAD`

## אימות (auth)
- **Token (PAT)** מועדף: Basic-Auth נשלח כ-`{Token}:PAT`.
- **fallback on-prem:** user/pass (שדה "API username" בכרטיס העובד).
- `BaseUrl`: `https://server/odata/Priority/tabula.ini/{environment}`.

## הבא בתור
טרם שולב בבנייה. יש להחליט: לשלב בשרת ה-VCT (דורש התאמה ל-.NET 4.8, או פרויקט `net8`+ נפרד ב-sln),
או להשאיר כעיון. ראה שיחה.
