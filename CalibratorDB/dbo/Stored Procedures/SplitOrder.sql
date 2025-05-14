-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 15/05/2025
-- Description:	Split order
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-259
-- =============================================
CREATE   PROCEDURE [dbo].[SplitOrder]
	@OrderId INT,
    @OrderDetailsIds NVARCHAR(MAX),
	@LoggedInUserEmail NVARCHAR(50) = NULL
AS
BEGIN

DECLARE @Userid INT = 0
IF @LoggedInUserEmail IS NOT NULL
SELECT @Userid = ID FROM dbo.Users WHERE Email = @LoggedInUserEmail

DECLARE @NewOrderWorkPlanId INT = 0

DROP TABLE IF EXISTS #OrderDetailsIds
CREATE TABLE #OrderDetailsIds
(
OrderDetailsId INT
)
INSERT #OrderDetailsIds(OrderDetailsId)
SELECT DISTINCT f.Value FROM dbo.ParseCSVToTable(@OrderDetailsIds) as f

IF (SELECT COUNT(*) FROM [dbo].[OrderDetails] as od
WHERE od.OrderWorkPlanId = @OrderId
	AND od.OrderDetailId NOT IN(SELECT OrderDetailsId FROM #OrderDetailsIds)) = 0
THROW 51000, 'Order have 1 item. Make no sense to split', 1;

BEGIN TRY


	UPDATE [dbo].[OrderWorkPlans]
	SET [OrderNumber] = 
			CASE 
				WHEN CHARINDEX('-', [OrderNumber]) = 0
					THEN CONCAT (TRIM([OrderNumber]),'-1')
				ELSE [OrderNumber]
			END
		,UpdatedDate = GETDATE()
		,UpdateUserID = @Userid
	FROM [dbo].[OrderWorkPlans]
	WHERE OrderWorkPlanId = @OrderId

	INSERT INTO [dbo].[OrderWorkPlans] (
		[OrderNumber]
		,[WorkPlanOpenDate]
		,[IsCancelled]
		,[CreatedDate]
		,[UpdatedDate]
		,[CreatedByUserId]
		,[UpdateUserID]
		,[Notes]
		)

	SELECT 			
	    CASE 
			WHEN CHARINDEX('-', [OrderNumber]) = 0
				THEN CONCAT (TRIM([OrderNumber]),'-1')
			ELSE CONCAT (SUBSTRING([OrderNumber], 1, CHARINDEX('-', [OrderNumber]))
					,TRY_CAST(RIGHT([OrderNumber], LEN([OrderNumber]) - CHARINDEX('-', [OrderNumber])) AS INT) + 1)
		END
		,GETDATE()
		,0
		,[CreatedDate]
		,[UpdatedDate]
		,[CreatedByUserId]
		,[UpdateUserID]
		,[Notes]
	FROM [dbo].[OrderWorkPlans]
	WHERE OrderWorkPlanId = @OrderId

	SELECT @NewOrderWorkPlanId = SCOPE_IDENTITY()

	UPDATE od
		SET OrderWorkPlanId = @NewOrderWorkPlanId
	FROM [dbo].[OrderDetails] as od
	WHERE od.OrderWorkPlanId = @OrderId
		AND od.OrderDetailId NOT IN
		(
		SELECT OrderDetailsId FROM #OrderDetailsIds
		)
END TRY

BEGIN CATCH
	ROLLBACK
END CATCH

END