# Category audit — `dbo.GetStatusByCategory`

The app calls `api.devices.getStatusByCategory` (tRPC) which runs
`EXEC [dbo].[GetStatusByCategory] @StatusDescriptionENG = <categoryName>`.
The proc `THROW`s `51000, 'Incorrect category provided.'` whenever the requested
`categoryName` is absent from `dbo.StatusesCategories`. Any absent category
therefore breaks its screen at runtime (reported for `CalibrationCycleName` in the
calibration-wizard).

## Sources

- App call sites: `c:/tmp/maba-app/src/**` (grep `getStatusByCategory`).
- Constant map: `c:/tmp/maba-app/src/server/api/routers/devices/constants/status-categories.ts`
- `dbo.StatusesCategories` rows read read-only from PROD `CalibratorProd` (@51.17.121.203).

## `statusCategories` constant → literal string

| constant key | literal `categoryName` |
|---|---|
| `calibrationStatus` | `CalibrationStatuses` |
| `reportStatus` | `ReportStatus` |
| `clientConfirmationStatus` | `ClientConfirmationStatus` |
| `calibratorNotificationType` | `CalibratorNotificationType` |
| `stickerType` | `StickerType` |
| `calibrationProcessDescription` | `CalibrationProcessDescription` |
| `calibrationCycleName` | `CalibrationCycleName` |

`reportStatus` is defined in the constant map but is **not** passed to any
`getStatusByCategory` call site, so it is not a "requested" category below (it is
present in the table regardless — id 1).

## Requested categories (distinct `categoryName` values passed to `getStatusByCategory`)

| category | present? | where used (app) |
|---|---|---|
| `CalibrationStatuses` | ✅ present (id 2) | packing/PackingTable.tsx (literal `'CalibrationStatuses'`), packing/devices/PackingCard.tsx, calibration-wizard/summary-screen/SummaryScreen.tsx |
| `CalibratorNotificationType` | ✅ present (id 14) | validator-orders-screen/CommentDialog.tsx, header/NotificationsDialog.tsx, header/CustomerNotificationsDialog.tsx, pdf-preview-dialog/PdfPreviewDialog.tsx |
| `OrderStatus` | ✅ present (id 9) | packing/PackingTable.tsx (literal `'OrderStatus'`) |
| `ClientConfirmationStatus` | ✅ present (id 13) | driver/DriverSignatureDialog.tsx |
| `StickerType` | ✅ present (id 15) | calibration-wizard/report-screen/stickers/StickerSelector.tsx, calibration-wizard/report-screen/ReportScreen.tsx |
| `CalibrationCycleName` | ❌ **MISSING** | calibration-wizard/calibration-graph/AddCycleDialog.tsx, calibration-wizard/report-screen/ReportScreen.tsx |
| `CalibrationProcessDescription` | ❌ **MISSING** | calibration-wizard/device-identification/CalibrationProcessComment.tsx, calibration-wizard/report-screen/ReportScreen.tsx |

## Result

- **MISSING:** `CalibrationCycleName`, `CalibrationProcessDescription`
- **PRESENT (requested):** `CalibrationStatuses`, `CalibratorNotificationType`, `OrderStatus`, `ClientConfirmationStatus`, `StickerType`
- **PRESENT (defined but not requested):** `ReportStatus`

Both missing categories are in the calibration-wizard, matching the reported
`CalibrationCycleName` failure. Each throws `'Incorrect category provided.'` until
its row exists in `dbo.StatusesCategories`.

## Full `dbo.StatusesCategories` contents (read-only snapshot)

| StatusCategoryId | StatusDescriptionENG | StatusDescriptionHEB |
|---|---|---|
| 1 | ReportStatus | (empty) |
| 2 | CalibrationStatuses | (empty) |
| 3 | CalibratedUnitsStatus | (empty) |
| 4 | SpecialCare | (empty) |
| 5 | CarStatus | (empty) |
| 6 | CalibrationEquipmentStatus | (empty) |
| 7 | UserAvailabilityStatus | (empty) |
| 8 | MeasurementDeviceStatus | (empty) |
| 9 | OrderStatus | (empty) |
| 10 | EventTypes | (empty) |
| 11 | UserStatus | (empty) |
| 12 | Position | (empty) |
| 13 | ClientConfirmationStatus | (empty) |
| 14 | CalibratorNotificationType | (empty) |
| 15 | StickerType | (empty) |

## Suggested INSERTs for the MISSING categories (REVIEW ONLY — do NOT run against PROD from here)

`StatusCategoryId` is an IDENTITY column, so it is omitted and left for SQL Server
to assign (next values would be 16, 17). `StatusDescriptionHEB` is left empty to
match every existing row. Guarded with `NOT EXISTS` so the script is idempotent.

```sql
-- CalibrationCycleName
IF NOT EXISTS (SELECT 1 FROM dbo.StatusesCategories
               WHERE StatusDescriptionENG = N'CalibrationCycleName')
BEGIN
    INSERT INTO dbo.StatusesCategories (StatusDescriptionENG, StatusDescriptionHEB)
    VALUES (N'CalibrationCycleName', N'');
END

-- CalibrationProcessDescription
IF NOT EXISTS (SELECT 1 FROM dbo.StatusesCategories
               WHERE StatusDescriptionENG = N'CalibrationProcessDescription')
BEGIN
    INSERT INTO dbo.StatusesCategories (StatusDescriptionENG, StatusDescriptionHEB)
    VALUES (N'CalibrationProcessDescription', N'');
END
```

> Note: inserting the category rows makes `GetStatusByCategory` stop throwing, but
> the JOIN to `dbo.Statuses` will return **0 rows** until matching `Statuses`
> (with the new `StatusCategoryId`) are also seeded. Seeding the actual status
> values for each category is out of scope for this audit and should be handled in
> a follow-up (the app currently expects at least a list to render dropdowns).
