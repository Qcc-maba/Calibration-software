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
		,0 as [UpdateUserID]
	FROM [stg].[stg_Manufacturers] as m
	) AS source
	ON 	dest.[OrdersDeviceManufacturerName] = source.[OrdersDeviceManufacturerName]
WHEN MATCHED
	THEN
		UPDATE
		SET  dest.[OrdersDeviceManufacturerDescription] = source.[OrdersDeviceManufacturerDescription]
			,dest.[UpdatedDate] = GETDATE()
			,dest.[UpdateUserID] = source.[UpdateUserID]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
             [OrdersDeviceManufacturerName]
			,[OrdersDeviceManufacturerDescription]
			,[UpdateUserID]

			)
		VALUES (
			 source.[OrdersDeviceManufacturerName]
			,source.[OrdersDeviceManufacturerDescription]
			,source.[UpdateUserID]
			);
END