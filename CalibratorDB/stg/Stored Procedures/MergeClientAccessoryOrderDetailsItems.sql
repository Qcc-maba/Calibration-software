CREATE     PROCEDURE [stg].[MergeClientAccessoryOrderDetailsItems]
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 06/10/2025
-- Description:	
-- JiraLink: 
-- =============================================
AS
BEGIN
SET NOCOUNT ON;

MERGE INTO [dbo].[ClientAccessoryOrderDetailsItems] AS dest
USING (
	SELECT   itm.[OrderDetailsItemId]
			,stg.[ItemsCount]
			,stg.[AccessoryDescription]
			,stg.[AccessoryLocation]
			,s.[SourceId]
			,GETDATE() as [CreateDate]
			,0 as [UpdateUserID]
	FROM [dbo].[OrderDetails] as od
	JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
	JOIN [dbo].[OrderDetailsItems] as itm ON od.[OrderDetailId] = itm.[OrderDetailId]
	JOIN [dbo].[Source] as s ON wp.SourceId = s.SourceId
	JOIN [stg].[stg_ClientAccessoryOrderDetailsItems] as stg ON stg.SourceSystem = s.SourceName 
	AND itm.SerialNumber = stg.SerialNumber AND stg.DOC_N = itm.DOC_N
	) AS source
	ON dest.[OrderDetailsItemId] = source.[OrderDetailsItemId]
		AND dest.[SourceId] = source.[SourceId]
		AND dest.[AccessoryDescription] = source.[AccessoryDescription]
WHEN MATCHED
	 AND
	 (
	 COALESCE(dest.[ItemsCount],0) <> COALESCE(source.[ItemsCount],0) 
	 OR COALESCE(dest.[AccessoryLocation],'') <> COALESCE(source.[AccessoryLocation],'') 
	 )
	THEN
		UPDATE
		SET  dest.[ItemsCount] = source.[ItemsCount]
			,dest.[AccessoryLocation] = source.[AccessoryLocation]
			,dest.[UpdatedDate] = GETDATE()
			,dest.[UpdateUserID] = 0
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [OrderDetailsItemId]
			,[AccessoryDescription]
			,[ItemsCount]
			,[AccessoryLocation]
			,[SourceId]
			,[CreateDate]
			,[UpdateUserID]

			)
		VALUES (
			source.[OrderDetailsItemId]
			,source.[AccessoryDescription]
			,source.[ItemsCount]
			,source.[AccessoryLocation]
			,[SourceId]
			,GETDATE()
			,0

			);

END