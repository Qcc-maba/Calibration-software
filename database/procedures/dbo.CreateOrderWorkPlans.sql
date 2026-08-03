-- =============================================
-- Proc:        dbo.CreateOrderWorkPlans
-- Jira:        MBA-96 (parent MBA-88 "Send order")
-- Author:      Eduard Kudlaiev (original 27/02/2026) — captured & MBA-96-annotated by Eliran Hadad
-- Description: Upsert ("save order data") for a single order header row in dbo.OrderWorkPlans.
--              Backs the parent story MBA-88 "Send order": when the coordinator/external
--              calibrator clicks Send on an expanded order row, the order is persisted in the
--              DB (and, by setting @OrderOverallStatusId / @ClientConfirmationStatusId, moves
--              to the state that drops it off the pending list).
--
--              Pattern (matches sibling dbo.CreateOrderDetails):
--                IF EXISTS (same OrderNumber) -> UPDATE   ELSE   INSERT.
--              Every updatable column uses COALESCE(@param, existing) so a NULL argument
--              leaves the stored value untouched (partial-update friendly).
--
--              The acting user + source system are resolved from the caller's email via the
--              inline TVF dbo.GetSourceFilterByEmail(@LoggedInUserEmail) -> (UserId, SourceId);
--              UserId feeds CreatedByUserId (insert) / UpdateUserID (update).
--
-- Inputs:
--   @OrderNumber                NVARCHAR(20)   -- natural key used for the exists-check / match
--   @WorkPlanOpenDate           DATETIME2(0)   -- order open date
--   @Notes                      NVARCHAR(255)  = NULL
--   @CustomerId                 INT            = NULL
--   @OrderOverallStatusId       INT            = NULL  -- set on Send so the order leaves the list
--   @ClientConfirmationStatusId INT            = NULL
--   @ShipTypeDesc               NVARCHAR(100)  = NULL
--   @CustomerComment            NVARCHAR(200)  = NULL
--   @BK_DOC_N / @BK_KLINE / @BK_PART  INT      = NULL  -- back-reference keys to source ERP order
--   @LoggedInUserEmail          NVARCHAR(100)         -- resolves acting UserId + SourceId
--
-- Output:
--   Single-column, single-row result set: OrderWorkPlanId (the upserted order's PK), so the
--   caller can chain child saves (dbo.CreateOrderDetails / dbo.AssignProductIdentificationData).
--
-- NOTE for review:
--   * This file captures the proc already deployed in prod (was dbo.CreateOrderWorkPlans,
--     CREATE PROCEDURE, no JiraLink). Only the header comment + CREATE OR ALTER were changed;
--     the parameter list and body are preserved verbatim so behaviour is identical.
--   * The UPDATE branch matches on OrderNumber ALONE. If two source systems can reuse the same
--     OrderNumber, consider keying the exists-check on (OrderNumber, SourceId) or on OrderSourceId
--     (as stg.MergeOrdersData does) — confirm with Eduard before changing.
-- =============================================
CREATE OR ALTER PROCEDURE dbo.CreateOrderWorkPlans (
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
GO
