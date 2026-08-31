SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Proc:        dbo.GetCustomerCalibrationReports
-- Jira:        MBA-796  "Customer Calibration-reports page (customer/calibration-reports)"
--              MBA-943  union across every customer the caller belongs to
-- Description: Returns the calibration reports belonging to the logged-in caller
--              (customer portal "Calibration Reports" grid, route customer/calibration-reports).
--
--              A "calibration report" is an OrderDetailsItem that has an MbaReportNumber assigned.
--              Unlike GetCustomerDeviceList (one row per device, latest order only) this SP returns
--              ONE ROW PER REPORT (every report the caller has, including historical / update
--              cycles), newest calibration first. Filtering / sorting / search are CLIENT-SIDE.
--
-- 2026-08-31 - MBA-943: the caller is a SET of customers, not one.
--
--              Scoping now comes from dbo.GetPortalCustomerIds - every customer the address
--              belongs to that holds devices. The old lowest-CustomerContactId rule showed
--              davide@iscar.co.il the reports of ישקר בע"מ, which has none, while his three other
--              ישקר divisions held all of them.
--
--              This SP is also what getCustomerReportUrl re-runs to authorise a report download,
--              so widening it here widens the download check in exactly the same way - a report
--              is downloadable if and only if it appears in this list.
--
--              @SelectedCustomerId is gone; MBA-936 added it for a branch picker we decided not
--              to build.
--
-- Output columns (camelCase, matching the app's Raw* -> mapper convention):
--   id                 -> OrderDetailsItemId (row key AND part of the AWS report path)
--   orderNumber        -> OrderWorkPlans.OrderNumber (part of the AWS report path)
--   reportPath         -> convenience S3 key the FE otherwise builds via getOrderReportPath():
--                         'orders/{orderNumber}/reports/{id}/report.pdf'
--   mbaReportNumber    -> itm.MbaReportNumber (מספר דוח מבא)
--   serialNumber       -> itm.SerialNumber
--   deviceDescription  -> OrdersProductTypes.OrdersProductTypeName
--   deviceManufacturer -> itm.OrdersDeviceManufacturer
--   deviceModel        -> itm.DeviceModel
--   calibrationDate    -> DD.MM.YYYY (CONVERT style 104) from itm.ActualCalibrationDate
--   reportStatus       -> lower-camel of the ReportStatus StatusDescriptionENG
--   reportStatusHeb    -> Statuses.StatusDescriptionHEB
--   customerName       -> NEW (MBA-943): which company the report belongs to. Front end: MBA-942.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerCalibrationReports]
    @LoggedInUserEmail NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
         itm.OrderDetailsItemId                                              AS id
        ,wp.OrderNumber                                                      AS orderNumber
        ,CONCAT(N'orders/', wp.OrderNumber, N'/reports/',
                itm.OrderDetailsItemId, N'/report.pdf')                      AS reportPath
        ,itm.MbaReportNumber                                                 AS mbaReportNumber
        ,itm.SerialNumber                                                    AS serialNumber
        ,pt.OrdersProductTypeName                                            AS deviceDescription
        ,itm.OrdersDeviceManufacturer                                        AS deviceManufacturer
        ,itm.DeviceModel                                                     AS deviceModel
        ,CONVERT(VARCHAR(10), itm.ActualCalibrationDate, 104)               AS calibrationDate
        ,CASE
            WHEN st.StatusDescriptionENG IS NULL OR LEN(st.StatusDescriptionENG) = 0 THEN NULL
            ELSE LOWER(LEFT(REPLACE(st.StatusDescriptionENG, '''', ''), 1))
               + SUBSTRING(REPLACE(st.StatusDescriptionENG, '''', ''), 2, 200)
         END                                                                AS reportStatus
        ,st.StatusDescriptionHEB                                            AS reportStatusHeb
        ,mine.CustomerName                                                  AS customerName
    FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail) AS mine
    JOIN [dbo].[OrderWorkPlans]      AS wp  ON wp.CustomerId       = mine.CustomerId
    JOIN [dbo].[OrderDetails]        AS od  ON od.OrderWorkPlanId  = wp.OrderWorkPlanId
    JOIN [dbo].[OrderDetailsItems]   AS itm ON itm.OrderDetailId   = od.OrderDetailId
    LEFT JOIN [dbo].[Statuses]           AS st ON st.StatusId            = itm.CalibrationReportStatusId
    LEFT JOIN [dbo].[OrdersProductTypes] AS pt ON pt.OrdersProductTypeId = od.OrdersProductTypeId
    WHERE wp.IsCancelled       = 0
      AND ISNULL(od.IsDeleted, 0)   = 0
      AND ISNULL(od.IsCancelled, 0) = 0
      AND ISNULL(itm.IsDeleted, 0)  = 0
      AND ISNULL(itm.IsCancelled, 0)= 0
      AND itm.MbaReportNumber IS NOT NULL
      AND LEN(itm.MbaReportNumber) > 0
    ORDER BY itm.ActualCalibrationDate DESC
    OPTION (RECOMPILE);
END
GO
