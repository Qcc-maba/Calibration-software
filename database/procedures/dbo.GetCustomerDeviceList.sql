-- =============================================
-- Proc:        dbo.GetCustomerDeviceList
-- Jira:        MBA-860 (parent MBA-859 "Wire Customer Device List to live data")
-- Description: Returns ONE row per device for the logged-in customer (customer portal
--              Device List grid). Identity input matches dbo.GetCustomerDashboardData
--              (@LoggedInUserEmail -> CustomerId via dbo.CustomerContacts). Scoped to the
--              calling customer only, consistent with the other GetCustomer* SPs.
--
--              Filtering / sorting / search are done CLIENT-SIDE (per MBA-860), so this SP
--              returns the full, clean device set for the customer with no pagination.
--
-- Output (exactly the 12 columns MBA-860 requires, in order):
--   id, deviceStatus, lastCalibration, nextCalibration, serialNumber, calibrationLocation,
--   deviceDescription, deviceManufacturer, deviceModel, sku, shippingMethod, lastReport
--
--   * deviceStatus     -> FE `deviceCalibrationStatuses` code (camelCase). The 11 codes the
--                         filter chips depend on are mapped explicitly by StatusId; any other
--                         status falls back to a lower-camel of StatusDescriptionENG.
--   * lastCalibration  -> DD.MM.YYYY string (CONVERT style 104) from ActualCalibrationDate.
--   * nextCalibration  -> DD.MM.YYYY string (CONVERT style 104) from NextCalibrationDate.
--
-- NOTE for review (Ariel): three source mappings are best-guess — please confirm:
--   * sku                 -> itm.ManufacturerNumber   (מק"ט יצרן; alt: AdditionalDeviceNumber)
--   * calibrationLocation -> IIF(od.IsInHouse=1, מעבדה, לקוח)  (same as GetCustomerDashboardData;
--                            alt: itm.ProductLocation / itm.SiteAddress)
--   * lastReport          -> itm.MbaReportNumber       (alt: CalibratorsToWorkPlan.OrderDetailsMbaReportNumber)
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerDeviceList]
    @LoggedInUserEmail NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

    SELECT TOP (1) @CustomerId = cc.CustomerId
    FROM [dbo].[CustomerContacts] AS cc
    WHERE cc.CustomerContactEmail = @LoggedInUserEmail;

    ;WITH devices AS
    (
        SELECT
             itm.OrderDetailsItemId                                                   AS id
            ,itm.CalibrationStatusId                                                  AS CalibrationStatusId
            ,st.StatusDescriptionENG                                                  AS StatusEng
            ,itm.ActualCalibrationDate                                                AS ActualCalibrationDate
            ,itm.NextCalibrationDate                                                  AS NextCalibrationDate
            ,itm.SerialNumber                                                         AS SerialNumber
            ,IIF(od.IsInHouse = 1, N'מעבדה', N'לקוח')                                  AS CalibrationLocation
            ,pt.OrdersProductTypeName                                                 AS DeviceDescription
            ,itm.OrdersDeviceManufacturer                                             AS DeviceManufacturer
            ,itm.DeviceModel                                                          AS DeviceModel
            ,itm.ManufacturerNumber                                                   AS Sku
            ,wp.ShipTypeDesc                                                          AS ShippingMethod
            ,itm.MbaReportNumber                                                      AS LastReport
            ,ROW_NUMBER() OVER (PARTITION BY itm.SerialNumber
                                ORDER BY wp.OrderWorkPlanId DESC)                     AS IsLatestOrder
        FROM [dbo].[OrderWorkPlans]      AS wp
        JOIN [dbo].[OrderDetails]        AS od  ON od.OrderWorkPlanId = wp.OrderWorkPlanId
        JOIN [dbo].[OrderDetailsItems]   AS itm ON itm.OrderDetailId  = od.OrderDetailId
        LEFT JOIN [dbo].[Statuses]           AS st ON st.StatusId            = itm.CalibrationStatusId
        LEFT JOIN [dbo].[OrdersProductTypes] AS pt ON pt.OrdersProductTypeId = od.OrdersProductTypeId
        WHERE wp.CustomerId       = @CustomerId
          AND wp.IsCancelled      = 0
          AND ISNULL(od.IsDeleted, 0)  = 0
          AND ISNULL(od.IsCancelled,0) = 0
          AND ISNULL(itm.IsDeleted, 0) = 0
          AND ISNULL(itm.IsCancelled,0)= 0
    )
    SELECT
         d.id
        ,CASE d.CalibrationStatusId
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
                    WHEN d.StatusEng IS NULL OR LEN(d.StatusEng) = 0 THEN NULL
                    ELSE LOWER(LEFT(REPLACE(d.StatusEng, '''', ''), 1))
                       + SUBSTRING(REPLACE(d.StatusEng, '''', ''), 2, 200)
                 END
         END                                                             AS deviceStatus
        ,CONVERT(VARCHAR(10), d.ActualCalibrationDate, 104)              AS lastCalibration
        ,CONVERT(VARCHAR(10), d.NextCalibrationDate,   104)              AS nextCalibration
        ,d.SerialNumber                                                  AS serialNumber
        ,d.CalibrationLocation                                           AS calibrationLocation
        ,d.DeviceDescription                                            AS deviceDescription
        ,d.DeviceManufacturer                                           AS deviceManufacturer
        ,d.DeviceModel                                                   AS deviceModel
        ,d.Sku                                                           AS sku
        ,d.ShippingMethod                                               AS shippingMethod
        ,d.LastReport                                                    AS lastReport
    FROM devices AS d
    WHERE d.IsLatestOrder = 1
    ORDER BY d.ActualCalibrationDate DESC
    OPTION (RECOMPILE);
END
GO
