SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Proc:        dbo.GetCustomerDeviceDetail
-- Jira:        MBA-798  "Customer Selected-device detail view"
--              MBA-943  the caller owns a set of customers, not one
--              MBA-996  the device is a dbo.CustomerDevices row, not an order line
-- Description: Returns the FULL detail of ONE device for the logged-in caller
--              (customer portal "selected device" detail view). This is a distinct
--              contract from:
--                * dbo.GetCustomerDeviceList     -> one row PER device, list columns.
--                * dbo.GetOrderDetailsDevices    -> STAFF detail, keyed by OrderWorkPlanId,
--                                                   requires a MABA Users/UserRoles row via
--                                                   GetSourceFilterByEmail and performs NO
--                                                   customer-ownership check -> unusable and
--                                                   unsafe for a customer contact.
--
-- 2026-11-15 - MBA-996 phase 2: keyed by @CustomerDeviceId, which replaces @OrderDetailsItemId.
--
--              The id is the one dbo.GetCustomerDeviceList returns, the same across visits. The
--              device must be one dbo.vwCustomerDevices shows - so a device the customer hid or
--              Priority cancelled returns no row, as one of another customer always did.
--
--              Device fields come from the device and fall back to its latest visit; the visit
--              fields (status, calibrator, order, report, the calibration tab) describe the latest
--              visit and are NULL for a device never calibrated. A device typed in by the customer
--              shows what was typed for its categories, unit, specification, location and language.
--              The visits themselves are dbo.GetCustomerCalibrationReports, column customerDeviceId.
--
--              What the customer edits (dbo.AssignCustomerDevicesData) wins over the visit: categories,
--              unit, location, site and report language show the device's own value first, else the latest
--              visit's (review of PR #60, r4588791454). The calibration tab's specification, method and
--              reference document stay visit-first: they describe the calibration that was done.
--
-- 2026-08-31 - MBA-943: the ownership guard spans every company the caller belongs to. The device
--              is re-scoped on every call through dbo.GetPortalCustomerIds, which is derived from the
--              caller's own CustomerContacts rows and takes no input from the request. A guessed id of
--              anyone else's device returns 0 rows.
--
-- Params:
--   @LoggedInUserEmail  NVARCHAR(100) -- customer contact e-mail (the app's signed-in session)
--   @CustomerDeviceId   INT           -- the selected device (dbo.CustomerDevices.CustomerDeviceID)
--
-- Output (single row):
--   id, deviceStatus (FE camelCase code), deviceStatusHeb,
--   lastCalibration (DD.MM.YYYY), nextCalibration (DD.MM.YYYY),
--   serialNumber, sku, additionalDeviceNumber,
--   calibrationLocation (מעבדה/לקוח), deviceDescription, deviceManufacturer, deviceModel,
--   mainCategory, secondaryCategory, accuracy, measurementUnit,
--   productLocation, siteAddress, shippingMethod,
--   orderNumber, lastReport,
--   calibratorFullName, calibratorPhone,
--   customerName,
--   calibrationDate, calibrationSpecification, calibrationMethod, referenceDocument, tolerance,
--   resolution, requiredProbability, visualCheck, reportLanguage, calibrationComment,
--   measurementUnitLong,
--   latestOrderDetailsItemId, isRegistered, visitCount        -- MBA-996
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerDeviceDetail]
    @LoggedInUserEmail NVARCHAR(100),
    @CustomerDeviceId  INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
         v.CustomerDeviceID                                                       AS id
        ,/*  MBA-948: the key is derived from the status text, because dbo.Statuses is not
                numbered the same on STAGE and PROD (31/32/33 are shifted by one). */
            CASE
                    WHEN st.StatusDescriptionENG IS NULL OR LEN(st.StatusDescriptionENG) = 0 THEN NULL
                    ELSE LOWER(LEFT(REPLACE(st.StatusDescriptionENG, '''', ''), 1))
                       + SUBSTRING(REPLACE(st.StatusDescriptionENG, '''', ''), 2, 200)
                 END
         AS deviceStatus
        ,st.StatusDescriptionHEB                                                  AS deviceStatusHeb
        ,CONVERT(VARCHAR(10), v.LastCalibrationDate, 104)                         AS lastCalibration
        ,CONVERT(VARCHAR(10), v.NextCalibrationDate, 104)                         AS nextCalibration
        ,v.SerialNumber                                                           AS serialNumber
        ,COALESCE(NULLIF(v.ManufacturerNumber, N''), li.ManufacturerNumber)       AS sku
        ,COALESCE(NULLIF(v.AdditionalDeviceNumber, N''), li.AdditionalDeviceNumber) AS additionalDeviceNumber
        ,CASE WHEN li.OrderDetailsItemId IS NULL THEN NULL
              WHEN od.IsInHouse = 1 THEN N'מעבדה' ELSE N'לקוח' END                AS calibrationLocation
        ,COALESCE(pt.OrdersProductTypeName, dpt.OrdersProductTypeName,
                  v.DeviceTypeName)                                               AS deviceDescription
        ,COALESCE(NULLIF(NULLIF(NULLIF(LTRIM(RTRIM(v.OrdersDeviceManufacturer)), N''), N'-/-'), N'0'),
                  li.OrdersDeviceManufacturer)                                    AS deviceManufacturer
        ,COALESCE(NULLIF(NULLIF(NULLIF(LTRIM(RTRIM(v.Model)), N''), N'-/-'), N'0'),
                  li.DeviceModel)                                                 AS deviceModel
        ,COALESCE(dmc.MainCategoryName, mc.MainCategoryName)                      AS mainCategory
        ,COALESCE(dsc.SecondaryCategoryName, sc.SecondaryCategoryName)            AS secondaryCategory
        ,COALESCE(li.Accuracy, v.Accuracy)                                        AS accuracy
        ,COALESCE(dmu.ShortNameHe, mu.ShortNameHe)                                AS measurementUnit
        ,COALESCE(NULLIF(v.DeviceLocation, N''), li.ProductLocation)              AS productLocation
        ,COALESCE(dcs.CustomerSiteAddress, li.SiteAddress, cs.CustomerSiteAddress) AS siteAddress
        ,wp.ShipTypeDesc                                                          AS shippingMethod
        ,wp.OrderNumber                                                           AS orderNumber
        ,li.MbaReportNumber                                                       AS lastReport
        ,CASE WHEN u.ID IS NULL THEN NULL ELSE CONCAT(u.FirstName, ' ', u.LastName) END AS calibratorFullName
        ,u.Phone                                                                  AS calibratorPhone
        ,mine.CustomerName                                                        AS customerName
        /*  THE CALIBRATION TAB (2026-09-08): the fields the latest calibration carries. */
        ,CONVERT(VARCHAR(10), li.ActualCalibrationDate, 104)                      AS calibrationDate
        ,COALESCE(ms.Name, dms.Name)                                              AS calibrationSpecification
        ,COALESCE(ms.MeasurementsSpecificationDescription,
                  dms.MeasurementsSpecificationDescription)                       AS calibrationMethod
        ,COALESCE(sr.Name, dsr.Name)                                              AS referenceDocument
        ,li.Tolerance                                                             AS tolerance
        ,li.Resolution                                                            AS resolution
        ,li.RequiredProbability                                                   AS requiredProbability
        ,li.VisualCheck                                                           AS visualCheck
        ,COALESCE(NULLIF(v.ReportLanguage, N''), li.ReportLanguage)               AS reportLanguage
        ,li.CalibrationStoppedComment                                             AS calibrationComment
        ,COALESCE(dmu.LongNameHe, mu.LongNameHe)                                  AS measurementUnitLong
        ,v.LatestOrderDetailsItemId                                               AS latestOrderDetailsItemId
        ,v.IsRegistered                                                           AS isRegistered
        ,v.VisitCount                                                             AS visitCount
    /* Ownership guard: the device must belong to one of the caller's own customers. */
    FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail) AS mine
    JOIN dbo.vwCustomerDevices                   AS v   ON v.CustomerId = mine.CustomerId
    /* the latest visit */
    LEFT JOIN [dbo].[OrderDetailsItems]          AS li  ON li.OrderDetailsItemId = v.LatestOrderDetailsItemId
    LEFT JOIN [dbo].[OrderDetails]               AS od  ON od.OrderDetailId      = li.OrderDetailId
    LEFT JOIN [dbo].[OrderWorkPlans]             AS wp  ON wp.OrderWorkPlanId    = od.OrderWorkPlanId
    LEFT JOIN [dbo].[Statuses]                   AS st  ON st.StatusId                = li.CalibrationStatusId
    LEFT JOIN [dbo].[OrdersProductTypes]         AS pt  ON pt.OrdersProductTypeId     = od.OrdersProductTypeId
    LEFT JOIN [dbo].[MainCategories]             AS mc  ON mc.ID                      = od.MainCategoryId
    LEFT JOIN [dbo].[SecondaryCategories]        AS sc  ON sc.ID                      = od.SecondaryCategoryId
    LEFT JOIN [dbo].[MeasurementDeviceUnits]     AS mu  ON mu.MeasurementDeviceUnitId = li.MeasurementUnitId
    LEFT JOIN [dbo].[MeasurementsSpecifications] AS ms  ON ms.ID                      = li.CalibrationSpecificationId
    LEFT JOIN [dbo].[SpecificationReference]     AS sr  ON sr.ID                      = li.SpecificationReferenceId
    LEFT JOIN [dbo].[CustomerSites]              AS cs  ON cs.CustomerSiteId          = od.CustomerSiteId
    LEFT JOIN [dbo].[Users]                      AS u   ON u.ID                       = od.CalibratorId
    /* the device's own values, for a device never calibrated */
    LEFT JOIN [dbo].[OrdersProductTypes]         AS dpt ON dpt.OrdersProductTypeId     = v.OrdersProductTypeId
    LEFT JOIN [dbo].[MainCategories]             AS dmc ON dmc.ID                      = v.MainCategoryId
    LEFT JOIN [dbo].[SecondaryCategories]        AS dsc ON dsc.ID                      = v.SecondaryCategoryId
    LEFT JOIN [dbo].[MeasurementDeviceUnits]     AS dmu ON dmu.MeasurementDeviceUnitId = v.PrimaryMeasurmentUnitId
    LEFT JOIN [dbo].[MeasurementsSpecifications] AS dms ON dms.ID                      = v.MeasurementsSpecificationId
    LEFT JOIN [dbo].[SpecificationReference]     AS dsr ON dsr.ID                      = v.SpecificationReferenceId
    LEFT JOIN [dbo].[CustomerSites]              AS dcs ON dcs.CustomerSiteId          = v.CustomerSiteId
                                                       AND dcs.CustomerId              = v.CustomerId
    WHERE v.CustomerDeviceID = @CustomerDeviceId
    OPTION (RECOMPILE);
END
GO
