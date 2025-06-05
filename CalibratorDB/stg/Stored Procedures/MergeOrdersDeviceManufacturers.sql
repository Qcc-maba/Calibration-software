CREATE      PROCEDURE [stg].[MergeOrdersDeviceManufacturers]
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 06/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
AS
BEGIN
SET NOCOUNT ON;

MERGE INTO [dbo].[OrdersDeviceManufacturers] AS dest
USING (
	SELECT 
		 m.MNFNAME AS [OrdersDeviceManufacturerName]
		,m.MNFDES AS [OrdersDeviceManufacturerDescription]
		,m.MNF as [OrdersDeviceManufacturersIdFromSource]
		,ss.SourceId
		,0 as [UpdateUserID]
	FROM [stg].[stg_Manufacturers] as m
	JOIN dbo.Source as ss ON m.SourceSystem = ss.SourceName
	) AS source
	ON 	dest.[OrdersDeviceManufacturersIdFromSource] = source.[OrdersDeviceManufacturersIdFromSource]
		AND dest.[SourceId] = source.[SourceId]
WHEN MATCHED
	AND dest.[OrdersDeviceManufacturerName] <> source.[OrdersDeviceManufacturerName]
	AND dest.[OrdersDeviceManufacturerDescription] <> source.[OrdersDeviceManufacturerDescription]
	THEN
		UPDATE
		SET  dest.[OrdersDeviceManufacturerName] = source.[OrdersDeviceManufacturerName]
			,dest.[OrdersDeviceManufacturerDescription] = source.[OrdersDeviceManufacturerDescription]
			,dest.[UpdatedDate] = GETDATE()
			,dest.[UpdateUserID] = source.[UpdateUserID]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
             [OrdersDeviceManufacturerName]
			,[OrdersDeviceManufacturerDescription]
			,[OrdersDeviceManufacturersIdFromSource]
			,[SourceId]
			,[UpdateUserID]

			)
		VALUES (
			 source.[OrdersDeviceManufacturerName]
			,source.[OrdersDeviceManufacturerDescription]
			,source.[OrdersDeviceManufacturersIdFromSource]
			,source.[SourceId]
			,source.[UpdateUserID]
			);
END