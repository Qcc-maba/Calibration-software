-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 27/02/2026
-- Description:	Procedure to add new order
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE dbo.CreateOrderWorkPlans (
	@OrderNumber NVARCHAR(20)
	,@WorkPlanOpenDate DATETIME2(0)
	,@Notes NVARCHAR(255) = NULL
	,@CustomerId INT = NULL
	,@OrderOverallStatusId INT = NULL
	,@ClientConfirmationStatusId INT = NULL
	,@ShipTypeDesc NVARCHAR(100) = NULL
	,@CustomerComment NVARCHAR(200) = NULL
	,@BK_DOC_N INT = NULL
	,@BK_KLINE INT = NULL
	,@BK_PART INT = NULL
	,@LoggedInUserEmail NVARCHAR(100) 
	)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @LoggedInUserId INT 
	DECLARE @SourceId TINYINT

	SELECT 
	 @LoggedInUserId  = d.UserId 
	,@SourceId = d.SourceId
	FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

		IF EXISTS (
				SELECT 1
				FROM dbo.OrderWorkPlans 
				WHERE OrderNumber = @OrderNumber
				)
			UPDATE ow
			SET ow.WorkPlanOpenDate = COALESCE(@WorkPlanOpenDate, ow.WorkPlanOpenDate)
				,ow.UpdatedDate = GETDATE()
				,ow.UpdateUserID = COALESCE(@LoggedInUserId, ow.UpdateUserID)
				,ow.Notes = COALESCE(@Notes, ow.Notes)
				,ow.SourceId = COALESCE(@SourceId, ow.SourceId)
				,ow.CustomerId = COALESCE(@CustomerId, ow.CustomerId)
				,ow.OrderOverallStatusId = COALESCE(@OrderOverallStatusId, ow.OrderOverallStatusId)
				,ow.ClientConfirmationStatusId = COALESCE(@ClientConfirmationStatusId, ow.ClientConfirmationStatusId)
				,ow.ShipTypeDesc = COALESCE(@ShipTypeDesc, ow.ShipTypeDesc)
				,ow.CustomerComment = COALESCE(@CustomerComment, ow.CustomerComment)
				,ow.BK_DOC_N = COALESCE(@BK_DOC_N, ow.BK_DOC_N)
				,ow.BK_KLINE = COALESCE(@BK_KLINE, ow.BK_KLINE)
				,ow.BK_PART = COALESCE(@BK_PART, ow.BK_PART)
			FROM dbo.OrderWorkPlans ow
			WHERE ow.OrderNumber = @OrderNumber;

		ELSE

		INSERT INTO dbo.OrderWorkPlans (
			OrderNumber
			,WorkPlanOpenDate
			,IsCancelled
			,CreatedDate
			,UpdatedDate
			,CreatedByUserId
			,Notes
			,SourceId
			,CustomerId
			,OrderOverallStatusId
			,ClientConfirmationStatusId
			,ShipTypeDesc
			,CustomerComment
			,BK_DOC_N
			,BK_KLINE
			,BK_PART
			)
		VALUES (
			@OrderNumber
			,@WorkPlanOpenDate
			,0
			,GETDATE()
			,NULL
			,@LoggedInUserId
			,@Notes
			,@SourceId
			,@CustomerId
			,@OrderOverallStatusId
			,@ClientConfirmationStatusId
			,@ShipTypeDesc
			,@CustomerComment
			,@BK_DOC_N
			,@BK_KLINE
			,@BK_PART
			);

		SELECT OrderWorkPlanId
		FROM dbo.OrderWorkPlans
		WHERE OrderNumber = @OrderNumber

END;