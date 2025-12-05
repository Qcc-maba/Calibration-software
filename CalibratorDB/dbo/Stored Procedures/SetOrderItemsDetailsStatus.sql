-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 05/12/2025
-- Description:	This SP should set status to details. It should take an array of order IDs and return the status of the operation.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-453
-- =============================================
CREATE   PROCEDURE [dbo].[SetOrderItemsDetailsStatus]
@OrderDetailsItemIds NVARCHAR(2000),
@CalibrationStatusId INT = NULL,
@CalibrationReportStatusId INT = NULL,
@LoggedInUserEmail NVARCHAR(100)

AS
BEGIN

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

DECLARE @SpecifiedCount INT
SET @SpecifiedCount =
          (CASE WHEN @CalibrationStatusId IS NOT NULL THEN 1 ELSE 0 END)
        + (CASE WHEN @CalibrationReportStatusId IS NOT NULL THEN 1 ELSE 0 END);

IF @SpecifiedCount > 1 OR @SpecifiedCount = 0
THROW 51000, 'Only one parameter should be specified: @CalibrationStatusId or @CalibrationReportStatusId.', 1;


DROP TABLE IF EXISTS #OrderDetailsItems 
CREATE TABLE #OrderDetailsItems
(
OrderDetailsItemId INT
)

INSERT #OrderDetailsItems(OrderDetailsItemId)
SELECT Value FROM dbo.ParseCSVToTable(@OrderDetailsItemIds)

IF @CalibrationStatusId IS NOT NULL

    UPDATE itm
    SET   [CalibrationStatusId] = @CalibrationStatusId,
          [UpdateUserID] = @LoggedInUserId,
          [UpdatedDate] = GETDATE()
    FROM [dbo].[OrderDetailsItems] as itm 
    JOIN #OrderDetailsItems as ds ON itm.[OrderDetailsItemId] = ds.OrderDetailsItemId

IF @CalibrationReportStatusId IS NOT NULL

    UPDATE itm
    SET   [CalibrationReportStatusId] = @CalibrationReportStatusId,
          [UpdateUserID] = @LoggedInUserId,
          [UpdatedDate] = GETDATE()
    FROM [dbo].[OrderDetailsItems] as itm 
    JOIN #OrderDetailsItems as ds ON itm.[OrderDetailsItemId] = ds.OrderDetailsItemId



END