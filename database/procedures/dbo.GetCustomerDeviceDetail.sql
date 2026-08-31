SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Proc:        dbo.GetCustomerDeviceDetail
-- Jira:        MBA-798  "Customer Selected-device detail view"
--              MBA-943  the caller owns a set of customers, not one
-- Description: Returns the FULL detail of ONE device for the logged-in caller
--              (customer portal "selected device" detail view). This is a distinct
--              contract from:
--                * dbo.GetCustomerDeviceList     -> one row PER device, list columns,
--                                                   no single-device key.
--                * dbo.GetOrderDetailsDevices    -> STAFF detail, keyed by OrderWorkPlanId,
--                                                   requires a MABA Users/UserRoles row via
--                                                   GetSourceFilterByEmail and performs NO
--                                                   customer-ownership check -> unusable and
--                                                   unsafe for a customer contact.
--
-- 2026-08-31 - MBA-943: the ownership guard now spans every company the caller belongs to.
--
--              THE GUARD IS NOT WEAKENED, IT IS WIDENED TO THE RIGHT SET. The device is still
--              re-scoped on every call: it must sit under a customer returned by
--              dbo.GetPortalCustomerIds for this e-mail, which is derived from the caller's own
--              CustomerContacts rows and takes no input from the request. A guessed
--              @OrderDetailsItemId belonging to anyone else still returns 0 rows. What changes is
--              that a manager can now open a device in his own second division - before, clicking
--              a row that the list itself had returned could come back empty, because the list and
--              the detail resolved to different single customers.
--
--              @SelectedCustomerId is gone; MBA-936 added it for a branch picker we decided not
--              to build.
--
-- Params:
--   @LoggedInUserEmail  NVARCHAR(100) -- customer contact e-mail (resolves the customer set)
--   @OrderDetailsItemId INT           -- the selected device (OrderDetailsItems.OrderDetailsItemId)
--
-- Output (single row): superset of the Device-List contract plus detail-only fields.
--   id, deviceStatus (FE camelCase code), deviceStatusHeb,
--   lastCalibration (DD.MM.YYYY), nextCalibration (DD.MM.YYYY),
--   serialNumber, sku, additionalDeviceNumber,
--   calibrationLocation (מעבדה/לקוח), deviceDescription, deviceManufacturer, deviceModel,
--   mainCategory, secondaryCategory, accuracy, measurementUnit,
--   productLocation, siteAddress, shippingMethod,
--   orderNumber, lastReport,
--   calibratorFullName, calibratorPhone,
--   customerName  -- NEW (MBA-943): which company owns this device. Front end: MBA-942.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerDeviceDetail]
    @LoggedInUserEmail  NVARCHAR(100),
    @OrderDetailsItemId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
         itm.OrderDetailsItemId                                                   AS id
        ,CASE itm.CalibrationStatusId
            WHEN 31 THEN 'testedMetTheStandard'
            WHEN 32 THEN 'testedDidntMeetTheStandards'
            WHEN 23 THEN 'calibrationSuccess'
            WHEN 21 THEN 'calibrationFailed'
            WHEN 26 THEN 'adjusted'
            WHEN 24 THEN 'delivered'
            WHEN 22 THEN 'packaged'
            WHEN 29 THEN 'readyForPacking'
            WHEN 27 THEN 'readyForDelivery'
            WHEN 19 THEN 'waitingForCalibration'
            WHEN 33 THEN 'cannotBeDetermined'
            ELSE CASE
                    WHEN st.StatusDescriptionENG IS NULL OR LEN(st.StatusDescriptionENG) = 0 THEN NULL
                    ELSE LOWER(LEFT(REPLACE(st.StatusDescriptionENG, '''', ''), 1))
                       + SUBSTRING(REPLACE(st.StatusDescriptionENG, '''', ''), 2, 200)
                 END
         END                                                                      AS deviceStatus
        ,st.StatusDescriptionHEB                                                  AS deviceStatusHeb
        ,CONVERT(VARCHAR(10), itm.ActualCalibrationDate, 104)                     AS lastCalibration
        ,CONVERT(VARCHAR(10), itm.NextCalibrationDate,   104)                     AS nextCalibration
        ,itm.SerialNumber                                                         AS serialNumber
        ,itm.ManufacturerNumber                                                   AS sku
        ,itm.AdditionalDeviceNumber                                               AS additionalDeviceNumber
        ,IIF(od.IsInHouse = 1, N'מעבדה', N'לקוח')                                  AS calibrationLocation
        ,pt.OrdersProductTypeName                                                 AS deviceDescription
        ,itm.OrdersDeviceManufacturer                                             AS deviceManufacturer
        ,itm.DeviceModel                                                          AS deviceModel
        ,mc.MainCategoryName                                                      AS mainCategory
        ,sc.SecondaryCategoryName                                                 AS secondaryCategory
        ,itm.Accuracy                                                             AS accuracy
        ,mu.ShortNameHe                                                           AS measurementUnit
        ,itm.ProductLocation                                                      AS productLocation
        ,COALESCE(itm.SiteAddress, cs.CustomerSiteAddress)                        AS siteAddress
        ,wp.ShipTypeDesc                                                          AS shippingMethod
        ,wp.OrderNumber                                                           AS orderNumber
        ,itm.MbaReportNumber                                                      AS lastReport
        ,CONCAT(u.FirstName, ' ', u.LastName)                                     AS calibratorFullName
        ,u.Phone                                                                  AS calibratorPhone
        ,mine.CustomerName                                                        AS customerName
    /* Ownership guard: the device must belong to one of the caller's own customers. */
    FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail) AS mine
    JOIN [dbo].[OrderWorkPlans]        AS wp  ON wp.CustomerId      = mine.CustomerId
    JOIN [dbo].[OrderDetails]          AS od  ON od.OrderWorkPlanId = wp.OrderWorkPlanId
    JOIN [dbo].[OrderDetailsItems]     AS itm ON itm.OrderDetailId  = od.OrderDetailId
    LEFT JOIN [dbo].[Statuses]             AS st ON st.StatusId              = itm.CalibrationStatusId
    LEFT JOIN [dbo].[OrdersProductTypes]   AS pt ON pt.OrdersProductTypeId   = od.OrdersProductTypeId
    LEFT JOIN [dbo].[MainCategories]       AS mc ON mc.ID                    = od.MainCategoryId
    LEFT JOIN [dbo].[SecondaryCategories]  AS sc ON sc.ID                    = od.SecondaryCategoryId
    LEFT JOIN [dbo].[MeasurementDeviceUnits] AS mu ON mu.MeasurementDeviceUnitId = itm.MeasurementUnitId
    LEFT JOIN [dbo].[CustomerSites]        AS cs ON cs.CustomerSiteId        = od.CustomerSiteId
    LEFT JOIN [dbo].[Users]                AS u  ON u.ID                     = od.CalibratorId
    WHERE itm.OrderDetailsItemId    = @OrderDetailsItemId
      AND wp.IsCancelled           = 0
      AND ISNULL(od.IsDeleted, 0)  = 0
      AND ISNULL(od.IsCancelled, 0) = 0
      AND ISNULL(itm.IsDeleted, 0) = 0
      AND ISNULL(itm.IsCancelled, 0) = 0
    OPTION (RECOMPILE);
END
GO
