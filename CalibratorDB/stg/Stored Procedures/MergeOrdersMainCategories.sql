CREATE    PROCEDURE stg.MergeOrdersMainCategories
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 04/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
AS
BEGIN
SET NOCOUNT ON;

	MERGE INTO [dbo].[OrdersMainCategories] AS dest
	USING (
		SELECT 
			 omc.[OrdersMainCategoryName]
			,omc.OrdersMainCategoryIdFromSource
			,ss.SourceId as [SourceId]
			,0 [UpdateUserID]
		FROM stg.stg_OrdersMainCategories as omc
		JOIN dbo.Source as ss ON omc.SourceSystem = ss.SourceName
		) AS source
		ON dest.OrdersMainCategoryIdFromSource = source.OrdersMainCategoryIdFromSource
		   AND dest.[SourceId] = source.[SourceId]
	WHEN MATCHED
		AND dest.[OrdersMainCategoryName]<> source.[OrdersMainCategoryName]
		THEN
			UPDATE
			SET dest.[OrdersMainCategoryName] = source.[OrdersMainCategoryName]
				,dest.[UpdatedDate] = GETDATE()
				,dest.[UpdateUserID] = 0
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [OrdersMainCategoryName]
				,OrdersMainCategoryIdFromSource
				,SourceId
				,[UpdateUserID]
				)
			VALUES (
				 source.[OrdersMainCategoryName]
				,source.OrdersMainCategoryIdFromSource
				,source.SourceId
				,source.[UpdateUserID]
				);

END