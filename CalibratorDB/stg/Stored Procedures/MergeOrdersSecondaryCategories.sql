CREATE    PROCEDURE [stg].[MergeOrdersSecondaryCategories]
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 06/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
AS
BEGIN
SET NOCOUNT ON;

MERGE INTO [dbo].[OrdersSecondaryCategories] AS dest
USING (
	SELECT oc.DeviceDescription as [OrdersSecondaryCategoryName]
		,0 as [UpdateUserID]
	FROM stg.stg_OrdersSecondaryCategories as oc
	) AS source
	ON dest.[OrdersSecondaryCategoryName] = source.[OrdersSecondaryCategoryName]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (		
			 [OrdersSecondaryCategoryName]
			,[UpdateUserID]

			)
		VALUES (
			 source.[OrdersSecondaryCategoryName]
			,source.[UpdateUserID]
			);


END