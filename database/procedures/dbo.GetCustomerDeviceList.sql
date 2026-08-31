SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Proc:        dbo.GetCustomerDeviceList
-- Jira:        MBA-860 (parent MBA-859 "Wire Customer Device List to live data")
--              MBA-943 - union across every customer the caller belongs to.
-- Description: Returns ONE row per device for the logged-in caller (customer portal
--              Device List grid).
--
--              Filtering / sorting / search are done CLIENT-SIDE (per MBA-860), so this SP
--              returns the full, clean device set with no pagination.
--
-- 2026-08-31 - MBA-943: the caller is a SET of customers, not one.
--
--              An e-mail address is a contact of one customer far less often than we assumed:
--              3,684 addresses serve several. davide@iscar.co.il is a contact of 22 ישקר
--              entities. The old rule took the lowest CustomerContactId, which for him is
--              ישקר בע"מ - a row holding ZERO devices - while his 24 devices sit under
--              ישקר-מתק"ש-תפן. He saw an empty portal. 181 addresses were in that state.
--
--              Scoping now comes from dbo.GetPortalCustomerIds, which returns every customer
--              the address belongs to that actually holds devices. See that function for why
--              the device filter is there and not cosmetic.
--
--              @SelectedCustomerId is GONE. It was added in MBA-936 for a branch picker that
--              we decided not to build; a union needs no choice and therefore no parameter to
--              verify. Callers passing it will now fail loudly rather than be silently ignored.
--
-- NEW COLUMN:  customerName - which company each device belongs to. Without it a manager sees
--              devices from three Iscar divisions in one list with nothing to tell them apart.
--              The front end has to render it (MBA-942).
--
-- Output (13 columns):
--   id, deviceStatus, lastCalibration, nextCalibration, serialNumber, calibrationLocation,
--   deviceDescription, deviceManufacturer, deviceModel, sku, shippingMethod, lastReport,
--   customerName
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerDeviceList]
    @LoggedInUserEmail NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

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
            ,mine.CustomerName                                                        AS CustomerName
            /* MBA-943: partition by CUSTOMER + serial, not serial alone.
               10 of 3,819 serial numbers appear under more than one customer. Partitioning on
               the serial alone would keep the newest order and silently drop the other
               company's device from a list that now spans several companies. */
            ,ROW_NUMBER() OVER (PARTITION BY wp.CustomerId, itm.SerialNumber
                                ORDER BY wp.OrderWorkPlanId DESC)                     AS IsLatestOrder
        FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail) AS mine
        JOIN [dbo].[OrderWorkPlans]      AS wp  ON wp.CustomerId        = mine.CustomerId
        JOIN [dbo].[OrderDetails]        AS od  ON od.OrderWorkPlanId   = wp.OrderWorkPlanId
        JOIN [dbo].[OrderDetailsItems]   AS itm ON itm.OrderDetailId    = od.OrderDetailId
        LEFT JOIN [dbo].[Statuses]           AS st ON st.StatusId            = itm.CalibrationStatusId
        LEFT JOIN [dbo].[OrdersProductTypes] AS pt ON pt.OrdersProductTypeId = od.OrdersProductTypeId
        WHERE wp.IsCancelled      = 0
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
        ,d.CustomerName                                                  AS customerName
    FROM devices AS d
    WHERE d.IsLatestOrder = 1
    ORDER BY d.ActualCalibrationDate DESC
    OPTION (RECOMPILE);
END
GO
