
CREATE    PROCEDURE [stg].[MergeClientAccessoryOrderDetails]
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 06/10/2025
-- Description:	
-- JiraLink: 
-- =============================================
AS
BEGIN
SET NOCOUNT ON;

MERGE INTO [dbo].[ClientAccessoryOrderDetails] AS dest
USING (
	SELECT    od.[OrderDetailId]
			,stg.[AccessorySourceId]
			,stg.[SerialNumber]
			,stg.[ItemsCount]
			,stg.[AccessoryDescription]
	FROM [dbo].[OrderDetails] as od
	JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
	JOIN [dbo].[Source] as s ON wp.SourceId = s.SourceId
	JOIN [stg].[stg_ClientAccessoryOrderDetails] as stg ON stg.SourceSystem = s.SourceName AND wp.OrderSourceId = stg.SourceOrderId
	AND stg.KLINE = od.KLINE
	) AS source
	ON dest.[OrderDetailId] = source.[OrderDetailId]
		AND dest.[AccessorySourceId] = source.[AccessorySourceId]
WHEN MATCHED
	THEN
		UPDATE
		SET  dest.[SerialNumber] = source.[SerialNumber]
			,dest.[ItemsCount] = source.[ItemsCount]
			,dest.[AccessoryDescription] = source.[AccessoryDescription]
			,dest.[UpdatedDate] = GETDATE()
			,dest.[UpdateUserID] = 0
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[OrderDetailId]
			,[AccessorySourceId]
			,[SerialNumber]
			,[ItemsCount]
			,[AccessoryDescription]
			,[CreateDate]
			,[UpdateUserID]

			)
		VALUES (
			source.[OrderDetailId]
			,source.[AccessorySourceId]
			,source.[SerialNumber]
			,source.[ItemsCount]
			,source.[AccessoryDescription]
			,GETDATE()
			,0

			);

END