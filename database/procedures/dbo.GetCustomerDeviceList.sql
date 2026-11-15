SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Proc:        dbo.GetCustomerDeviceList
-- Jira:        MBA-860 (parent MBA-859 "Wire Customer Device List to live data")
--              MBA-943 - union across every customer the caller belongs to.
--              MBA-996 - one row per DEVICE (dbo.CustomerDevices), not per serial text.
-- Description: Returns ONE row per device for the logged-in caller (customer portal
--              Device List grid).
--
--              Filtering / sorting / search are done CLIENT-SIDE (per MBA-860), so this SP
--              returns the full, clean device set with no pagination.
--
-- 2026-11-15 - MBA-996 phase 2: the list reads dbo.vwCustomerDevices.
--
--              id IS NOW dbo.CustomerDevices.CustomerDeviceID, the same across visits. Until now it
--              was the newest OrderDetailsItemId of the device, so it changed with every order and a
--              saved link stopped working. Report and calibration links are about a visit and use
--              latestOrderDetailsItemId. Design: DBA/schema-updates.md section 2, points 5 and 6.
--
--              What the list shows is decided by the view, not here: registered devices with at
--              least one live visit, devices typed in by the customer, never a device the customer
--              hid or Priority cancelled. That replaces the linked-server lookup of cancelled serials
--              this procedure made on every call (2026-09-08): the hourly refresh carries Priority's
--              cancellation into IsInactiveInSource.
--
--              Device fields come from the device - Priority's register, which owns them for a
--              registered device - and fall back to its latest visit. Priority's placeholders '-/-'
--              and '0' count as empty. Of 5,837 STAGE devices with a visit (2026-11-15) the device
--              fills the manufacturer where the line had none on 356, the line fills it on 22, and on
--              110 both have one and they differ (Priority's wins; models: 90). Visit fields -
--              status, dates, location, shipping, last report - come from the latest visit and are
--              NULL for a device never calibrated.
--
--              Not shown any more: order lines with no Priority device (SERN IS NULL), 7 of 9,855
--              devices on PROD (2026-11-15), all manually added lines.
--
--              The caller's customers come from dbo.GetPortalCustomerIds and nothing else
--              (section 2, point 7.2). The e-mail is the app's signed-in session.
--
-- 2026-08-31 - MBA-943: the caller is a SET of customers, not one. davide@iscar.co.il is a contact
--              of 22 ישקר entities; the old single-customer rule showed him an empty portal.
--              customerName says which company each device belongs to (front end: MBA-942).
--
-- Output (16 columns):
--   id, deviceStatus, lastCalibration, nextCalibration, serialNumber, calibrationLocation,
--   deviceDescription, deviceManufacturer, deviceModel, sku, shippingMethod, lastReport,
--   customerName,
--   latestOrderDetailsItemId (NULL: never calibrated), isRegistered (1: exists in Priority),
--   visitCount
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerDeviceList]
    @LoggedInUserEmail NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
         v.CustomerDeviceID                                                       AS id
        ,/*  MBA-948: the key is derived from the status text, because dbo.Statuses is not
                numbered the same on STAGE and PROD (31/32/33 are shifted by one). */
            CASE
                    WHEN st.StatusDescriptionENG IS NULL OR LEN(st.StatusDescriptionENG) = 0 THEN NULL
                    ELSE LOWER(LEFT(REPLACE(st.StatusDescriptionENG, '''', ''), 1))
                       + SUBSTRING(REPLACE(st.StatusDescriptionENG, '''', ''), 2, 200)
                 END
         AS deviceStatus
        ,CONVERT(VARCHAR(10), v.LastCalibrationDate, 104)                         AS lastCalibration
        ,CONVERT(VARCHAR(10), v.NextCalibrationDate, 104)                         AS nextCalibration
        ,v.SerialNumber                                                           AS serialNumber
        ,CASE WHEN li.OrderDetailsItemId IS NULL THEN NULL
              WHEN od.IsInHouse = 1 THEN N'מעבדה' ELSE N'לקוח' END                AS calibrationLocation
        ,COALESCE(pt.OrdersProductTypeName, dpt.OrdersProductTypeName,
                  v.DeviceTypeName)                                               AS deviceDescription
        ,COALESCE(NULLIF(NULLIF(NULLIF(LTRIM(RTRIM(v.OrdersDeviceManufacturer)), N''), N'-/-'), N'0'),
                  li.OrdersDeviceManufacturer)                                    AS deviceManufacturer
        ,COALESCE(NULLIF(NULLIF(NULLIF(LTRIM(RTRIM(v.Model)), N''), N'-/-'), N'0'),
                  li.DeviceModel)                                                 AS deviceModel
        ,COALESCE(NULLIF(v.ManufacturerNumber, N''), li.ManufacturerNumber)       AS sku
        ,wp.ShipTypeDesc                                                          AS shippingMethod
        ,li.MbaReportNumber                                                       AS lastReport
        ,mine.CustomerName                                                        AS customerName
        ,v.LatestOrderDetailsItemId                                               AS latestOrderDetailsItemId
        ,v.IsRegistered                                                           AS isRegistered
        ,v.VisitCount                                                             AS visitCount
    FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail) AS mine
    JOIN dbo.vwCustomerDevices           AS v   ON v.CustomerId = mine.CustomerId
    LEFT JOIN [dbo].[OrderDetailsItems]  AS li  ON li.OrderDetailsItemId = v.LatestOrderDetailsItemId
    LEFT JOIN [dbo].[OrderDetails]       AS od  ON od.OrderDetailId      = li.OrderDetailId
    LEFT JOIN [dbo].[OrderWorkPlans]     AS wp  ON wp.OrderWorkPlanId    = od.OrderWorkPlanId
    LEFT JOIN [dbo].[Statuses]           AS st  ON st.StatusId           = li.CalibrationStatusId
    LEFT JOIN [dbo].[OrdersProductTypes] AS pt  ON pt.OrdersProductTypeId  = od.OrdersProductTypeId
    LEFT JOIN [dbo].[OrdersProductTypes] AS dpt ON dpt.OrdersProductTypeId = v.OrdersProductTypeId
    ORDER BY v.LastCalibrationDate DESC, v.CustomerDeviceID DESC
    OPTION (RECOMPILE);
END
GO
