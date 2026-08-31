-- =============================================
-- Proc:        dbo.GetOrderAttachmentCounts
-- Jira:        MBA-930 ("Work file: show the order's Priority attachments, converted to PDF")
-- Description: How many Priority documents each order carries. This is what drives the file
--              button on the work assignment screen (שיבוץ עבודה) — red when the order has
--              files, grey when it has none, matching the icon pattern from MBA-803.
--
--              Built for the GRID, not the detail view: the screen renders a page of orders at
--              once and must not issue one call per row. Pass the page's ids as a CSV; pass
--              NULL to get every order that has at least one file.
--
--              An order with no attachments is NOT returned. The caller treats "absent" as
--              zero and greys the button — that keeps the payload to the orders that actually
--              have something, which on PROD is 13,237 of them.
--
--              TruncatedFiles is surfaced here so the grid can distinguish "has files" from
--              "has files, some of which cannot be opened" without a second round-trip.
--              Priority's EXTFILENAME is varchar(80) and it cuts longer names; 35 rows are
--              unreachable for that reason.
--
-- Param:       @OrderWorkPlanIds NVARCHAR(MAX) = NULL   -- CSV of OrderWorkPlanId, NULL = all
-- Returns:     OrderWorkPlanId, OrderNumber, FileCount, ServableFiles, TruncatedFiles
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetOrderAttachmentCounts]
    @OrderWorkPlanIds NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    /* dbo.ParseCSVToTable is the house CSV splitter — dbo.AssignCarToOrder uses it for
       @QuartersOfDay. Reused rather than introducing STRING_SPLIT beside it. */
    DECLARE @Wanted TABLE (OrderWorkPlanId INT PRIMARY KEY);

    IF @OrderWorkPlanIds IS NOT NULL AND LTRIM(RTRIM(@OrderWorkPlanIds)) <> N''
        INSERT INTO @Wanted (OrderWorkPlanId)
        SELECT DISTINCT Value FROM dbo.ParseCSVToTable(@OrderWorkPlanIds) WHERE Value IS NOT NULL;

    DECLARE @Filtered BIT = CASE WHEN EXISTS (SELECT 1 FROM @Wanted) THEN 1 ELSE 0 END;

    SELECT
         wp.OrderWorkPlanId
        ,wp.OrderNumber
        ,FileCount      = COUNT(*)
        ,ServableFiles  = SUM(CASE WHEN a.IsPathTruncated = 0 THEN 1 ELSE 0 END)
        ,TruncatedFiles = SUM(CAST(a.IsPathTruncated AS INT))
    FROM dbo.OrderWorkPlans      AS wp
    JOIN dbo.CrmOrderAttachments AS a ON a.ORD = wp.OrderSourceId
    WHERE ISNULL(wp.IsCancelled, 0) = 0
      AND (@Filtered = 0 OR wp.OrderWorkPlanId IN (SELECT OrderWorkPlanId FROM @Wanted))
    GROUP BY wp.OrderWorkPlanId, wp.OrderNumber
    ORDER BY wp.OrderWorkPlanId DESC;
END
GO
