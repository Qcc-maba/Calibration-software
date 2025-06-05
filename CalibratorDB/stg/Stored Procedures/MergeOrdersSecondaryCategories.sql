CREATE    PROCEDURE stg.MergeOrdersSecondaryCategories
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
		,ss.SourceId
		,0 as [UpdateUserID]
	FROM stg.stg_OrdersSecondaryCategories as oc
	JOIN dbo.Source as ss ON oc.SourceSystem = ss.SourceName
	) AS source
	ON dest.[OrdersSecondaryCategoryName] = source.[OrdersSecondaryCategoryName]
		AND dest.[SourceId] = source.[SourceId]

WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (		
			 [OrdersSecondaryCategoryName]
			,[SourceId]

			)
		VALUES (
			 source.[OrdersSecondaryCategoryName]
			,source.[SourceId]
			);


END