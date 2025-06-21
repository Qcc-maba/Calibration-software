
CREATE    PROCEDURE [stg].[MergeOrdersMainCategories]
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
			 ,0 as [UpdateUserID]
		FROM stg.stg_OrdersMainCategories as omc
		) AS source
		ON dest.[OrdersMainCategoryName] = source.[OrdersMainCategoryName]
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [OrdersMainCategoryName]
				,[UpdateUserID]
				)
			VALUES (
				 source.[OrdersMainCategoryName]
				,source.[UpdateUserID]
				);

END