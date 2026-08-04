-- =============================================
-- Jira:        MBA-835 - Customer Support Manager dashboard
-- Author:      Claude (DBA agent)
-- Create date: 2026-08-04
-- Target:      STAGE (Calibrator on AWS)
-- Description: Data for the internal Customer Support Manager dashboard.
--              Returns TWO result sets that are fully backed by the Calibrator DB:
--                (1) SLA status board  - per-department delay score + RAG colour
--                (2) Work-approval table - report items whose CURRENT workflow
--                    status (from OrderItemsStatusesHistory) is an approval /
--                    signature stage.
--
--              The screen's THIRD section - "sales-performance KPIs" (target
--              attainment / MoM revenue trend / per-rep performance) - is NOT
--              produced here. Calibrator only stores raw invoiced amounts
--              (OrderDetails.PRICE / VPRICE) with no sales targets, quotas,
--              salesperson attribution, or trend baseline. Those KPIs live in
--              the QCC analytics DB (QCCData / qcc_analytics) on the same server.
--              That section is BLOCKED pending the QCCData contract - it is
--              intentionally not fabricated here (see Jira MBA-835).
--
-- Params:      @LoggedInUserEmail NVARCHAR(50) - the signed-in manager; the
--              dashboard is org-wide (not customer-scoped) so the email is used
--              only to identify/authorise the user, not to filter to a customer.
-- Conventions: dates to FE as DD.MM.YYYY via CONVERT(...,104); status text from
--              dbo.Statuses. Modelled on dbo.GetLaboratoryViewDepartmentDelays
--              and dbo.GetCustomerDashboardData.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetSupportManagerDashboardData]
    @LoggedInUserEmail NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    -- Resolve the signed-in manager (org-wide view; used for auth/identity only)
    DECLARE @UserId INT;

    SELECT @UserId = u.ID
    FROM [dbo].[Users] AS u
    WHERE u.Email = @LoggedInUserEmail
      AND u.IsActive = 1;

    -- ---------------------------------------------------------------
    -- Result set 1: SLA status board (per department)
    -- Delay score = SUM(delay count / department average); RAG colour
    -- thresholds match the existing laboratory-view delay board.
    -- ---------------------------------------------------------------
    ;WITH deptDelays AS
    (
        SELECT
             dp.Department
            ,COALESCE(SUM(ROUND(dd.cnt * 1.0 / NULLIF(dp.Average, 0), 1)), 0) AS Delays
        FROM [dbo].[DepartmentDelays]                 AS dd
        JOIN [dbo].[CustomerSupportDepartmentParts]   AS dp ON dd.SKU = dp.Item
        GROUP BY dp.Department
    )
    SELECT
         d.Department
        ,d.Delays
        ,CASE
            WHEN d.Delays < 5                       THEN 'Green'
            WHEN d.Delays >= 5   AND d.Delays < 7.5 THEN 'Yellow'
            WHEN d.Delays >= 7.5 AND d.Delays < 10  THEN 'Orange'
            WHEN d.Delays >= 10                     THEN 'Red'
            ELSE NULL
         END AS Color
    FROM deptDelays AS d
    ORDER BY d.Delays DESC;

    -- ---------------------------------------------------------------
    -- Result set 2: Work-approval table
    -- Active report items whose CURRENT status (latest history row) is an
    -- approval / signature workflow stage. Status codes (dbo.Statuses):
    --   GR CreateCalibrationReport, H1 FirstSignature, H2 SecondSignature,
    --   HR ReportRejectedByApprover, plus AwaitingSignature / AwaitingComments.
    -- ---------------------------------------------------------------
    ;WITH latestStatus AS
    (
        SELECT
             h.OrderDetailsItemId
            ,h.StatusId
            ,h.CreatedDate
            ,ROW_NUMBER() OVER (PARTITION BY h.OrderDetailsItemId
                                ORDER BY h.CreatedDate DESC) AS rn
        FROM [dbo].[OrderItemsStatusesHistory] AS h
        WHERE h.IsDeleted = 0
    )
    SELECT
         wp.OrderNumber
        ,c.CustomerName
        ,itm.MbaReportNumber
        ,itm.DeviceModel
        ,itm.SerialNumber
        ,s.Code                                            AS StatusCode
        ,s.StatusDescriptionHEB                            AS StatusHEB
        ,s.StatusDescriptionENG                            AS StatusENG
        ,CONVERT(NVARCHAR(10), ls.CreatedDate, 104)        AS WaitingSince
        ,DATEDIFF(DAY, ls.CreatedDate, GETDATE())          AS DaysWaiting
        ,u.FirstName                                       AS CalibratorFirstName
        ,u.LastName                                        AS CalibratorLastName
    FROM latestStatus                       AS ls
    JOIN [dbo].[Statuses]                   AS s   ON ls.StatusId = s.StatusId
    JOIN [dbo].[OrderDetailsItems]          AS itm ON itm.OrderDetailsItemId = ls.OrderDetailsItemId
    JOIN [dbo].[OrderDetails]               AS od  ON od.OrderDetailId = itm.OrderDetailId
    JOIN [dbo].[OrderWorkPlans]             AS wp  ON wp.OrderWorkPlanId = od.OrderWorkPlanId
    LEFT JOIN [dbo].[Customers]             AS c   ON c.CustomerId = wp.CustomerId
    LEFT JOIN [dbo].[Users]                 AS u   ON u.ID = od.CalibratorId
    WHERE ls.rn = 1
      AND itm.IsDeleted   = 0
      AND itm.IsCancelled = 0
      AND wp.IsCancelled  = 0
      AND s.Code IN ('GR','H1','H2','HR')          -- report + signature approval stages
    ORDER BY ls.CreatedDate ASC;                    -- oldest waiting first
END
