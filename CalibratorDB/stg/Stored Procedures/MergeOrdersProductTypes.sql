

CREATE     PROCEDURE [stg].[MergeOrdersProductTypes]
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 20/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
AS
BEGIN
SET NOCOUNT ON;

	MERGE INTO [dbo].[OrdersProductTypes] AS dest
	USING (
		SELECT DISTINCT
			  o.DeviceType as [OrdersProductTypeName]
			  ,o.DeviceTypeENG as [OrdersProductTypeNameENG]
			 ,0 as [UpdateUserID]
		FROM stg.stg_Orders as o
		WHERE LEN(o.DeviceType) > 0 AND o.DeviceType IS NOT NULL
		) AS source
		ON dest.[OrdersProductTypeName] = source.[OrdersProductTypeName]
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [OrdersProductTypeName]
                ,[OrdersProductTypeNameENG]
				,[UpdateUserID]
				)
			VALUES (
				 source.[OrdersProductTypeName]
				,source.[OrdersProductTypeNameENG]
				,source.[UpdateUserID]
				);

END