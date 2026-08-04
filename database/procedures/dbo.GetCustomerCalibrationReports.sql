-- =============================================
-- Proc:        dbo.GetCustomerCalibrationReports
-- Jira:        MBA-796  "Customer Calibration-reports page (customer/calibration-reports)"
-- Description: Returns the calibration reports belonging to the logged-in customer
--              (customer portal "Calibration Reports" grid, route customer/calibration-reports).
--              Identity input matches dbo.GetCustomerDashboardData / dbo.GetCustomerDeviceList
--              (@LoggedInUserEmail -> CustomerId via dbo.CustomerContacts) and is scoped to the
--              calling customer only, consistent with the other GetCustomer* SPs.
--
--              A "calibration report" is an OrderDetailsItem that has an MbaReportNumber assigned.
--              Unlike GetCustomerDeviceList (one row per device, latest order only) this SP returns
--              ONE ROW PER REPORT (every report the customer has, including historical / update
--              cycles), newest calibration first. Filtering / sorting / search are CLIENT-SIDE.
--
-- Output columns (camelCase, matching the app's Raw* -> mapper convention):
--   id                 -> OrderDetailsItemId (row key AND part of the AWS report path)
--   orderNumber        -> OrderWorkPlans.OrderNumber (part of the AWS report path)
--   reportPath         -> convenience S3 key the FE otherwise builds via getOrderReportPath():
--                         'orders/{orderNumber}/reports/{id}/report.pdf'  (see
--                         src/lib/helpers/get-aws-file-paths.ts + pdf-preview-dialog)
--   mbaReportNumber    -> itm.MbaReportNumber (מספר דוח מבא)
--   serialNumber       -> itm.SerialNumber
--   deviceDescription  -> OrdersProductTypes.OrdersProductTypeName
--   deviceManufacturer -> itm.OrdersDeviceManufacturer
--   deviceModel        -> itm.DeviceModel
--   calibrationDate    -> DD.MM.YYYY (CONVERT style 104) from itm.ActualCalibrationDate
--   reportStatus       -> lower-camel of the ReportStatus StatusDescriptionENG (e.g.
--                         'createCalibrationReport'); NULL when no report status is set
--   reportStatusHeb    -> Statuses.StatusDescriptionHEB (Hebrew display text for the status)
--
-- OPEN QUESTIONS for review (screen is still a stub in the app, no wired tRPC/Figma yet):
--   * reportStatus source = itm.CalibrationReportStatusId (ReportStatus category). Confirm this
--     is the status the grid should show (vs. the calibration status used by GetCustomerDeviceList).
--   * FE enum for reportStatus is not defined yet, so the code is derived generically from the
--     English description (same fallback pattern GetCustomerDeviceList uses). Confirm the exact
--     camelCase codes once the FE filter chips exist, then map explicitly by StatusId.
--   * Download: FE builds the URL from {orderNumber, id}; reportPath is returned as a convenience.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerCalibrationReports]
    @LoggedInUserEmail NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

    SELECT TOP (1) @CustomerId = cc.CustomerId
    FROM [dbo].[CustomerContacts] AS cc
    WHERE cc.CustomerContactEmail = @LoggedInUserEmail;

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
    FROM [dbo].[OrderWorkPlans]      AS wp
    JOIN [dbo].[OrderDetails]        AS od  ON od.OrderWorkPlanId = wp.OrderWorkPlanId
    JOIN [dbo].[OrderDetailsItems]   AS itm ON itm.OrderDetailId  = od.OrderDetailId
    LEFT JOIN [dbo].[Statuses]           AS st ON st.StatusId            = itm.CalibrationReportStatusId
    LEFT JOIN [dbo].[OrdersProductTypes] AS pt ON pt.OrdersProductTypeId = od.OrdersProductTypeId
    WHERE wp.CustomerId        = @CustomerId
      AND wp.IsCancelled       = 0
      AND ISNULL(od.IsDeleted, 0)   = 0
      AND ISNULL(od.IsCancelled, 0) = 0
      AND ISNULL(itm.IsDeleted, 0)  = 0
      AND ISNULL(itm.IsCancelled, 0)= 0
      AND itm.MbaReportNumber IS NOT NULL
      AND LEN(itm.MbaReportNumber) > 0
    ORDER BY itm.ActualCalibrationDate DESC
    OPTION (RECOMPILE);
END
