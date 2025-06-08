-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/04/2025
-- Description:	Merge orders data from amaba
-- JiraLink: 
-- =============================================
CREATE PROCEDURE [stg].[MergeOrdersData]
AS
BEGIN

SET NOCOUNT ON;

DECLARE @dt DATETIME2(0) = GETDATE()

MERGE INTO [dbo].[OrderWorkPlans] AS dest
USING (
	SELECT DISTINCT
	     o.ORDNAME as [OrderNumber]
		,o.OpenDate as [WorkPlanOpenDate]
		,@dt AS [CreatedDate]
		,0 as [UpdateUserID]
		,0 as [CreatedByUserId]
		,0 as [IsCancelled]
		,NULL as [Notes]
		,o.SourceOrderId as [OrderSourceId]
		,ss.[SourceId]
	FROM [stg].[stg_Orders] as o
	JOIN [dbo].[Source] as ss ON o.[SourceSystem] = ss.SourceName
	) AS source
	ON dest.[OrderSourceId] = source.[OrderSourceId]
	   AND dest.[OrderSourceId] = source.[OrderSourceId]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
             [OrderNumber]
			,[WorkPlanOpenDate]
			,[CreatedDate]
			,[CreatedByUserId]
			,[UpdateUserID]
			,[IsCancelled]
			,[Notes]
			,[OrderSourceId]
			,[SourceId]
			)
		VALUES (
			 source.[OrderNumber]
			,source.[WorkPlanOpenDate]
			,source.[CreatedDate]
			,source.[CreatedByUserId]
			,source.[UpdateUserID]
			,source.[IsCancelled]
			,source.[Notes]
			,source.[OrderSourceId]
			,source.[SourceId]
			);

MERGE INTO [dbo].[OrderDetails] AS dest
USING (
	SELECT 
		wp.OrderWorkPlanId
	  ,o.[CalibDate]
      ,o.[SerialNumber]
      ,o.[ManufacturerNumber]
      ,o.[Devicemodel] as [DeviceModel]
      ,o.[SpecialCareTypeId]
      ,o.[InHouse] as IsInHouse
      ,o.[PartName]
      ,o.[DeviceType]
      ,o.[MbaReportNumber]
	  ,omc.OrdersMainCategoryId
	  ,osc.OrdersSecondaryCategoryId
	  ,dm.OrdersDeviceManufacturerId
	  ,o.SecondCategorySourceId AS SecondCategory
	  ,c.CustomerId
	  ,o.KLINE
	  ,o.SERN
	  ,NULL AS [StatusId]
	  ,0 as [CreatedByUserId]
	  ,0 as [UpdateUserID]
	  ,@dt AS [CreatedDate]
	FROM [stg].[stg_Orders] as o
	JOIN [dbo].[Source] as ss ON o.[SourceSystem] = ss.SourceName
	JOIN [dbo].[OrderWorkPlans] as wp ON wp.[SourceId] = ss.[SourceId] AND o.[SourceOrderId] = wp.OrderSourceId
	LEFT JOIN [dbo].[OrdersMainCategories] as omc ON o.[MainCategorySourceId] = omc.OrdersMainCategoryIdFromSource AND omc.[SourceId] = ss.[SourceId]
    LEFT JOIN [dbo].[OrdersSecondaryCategories] as osc ON o.[SecondCategorySourceId] = osc.[OrdersSecondaryCategoryName] AND osc.[SourceId] = ss.[SourceId]
    LEFT JOIN [dbo].[OrdersDeviceManufacturers] as dm ON o.[DeviceManufacturerSourceId] = dm.OrdersDeviceManufacturersIdFromSource AND dm.[SourceId] = ss.[SourceId]
    LEFT JOIN [dbo].[Customers] as c ON o.[CustomerSourceId] = c.CustomerIdFromSource AND c.[SourceId] = ss.[SourceId]

	) AS source
	ON dest.OrderWorkPlanId = source.OrderWorkPlanId
	   AND dest.KLINE = source.KLINE
	   AND COALESCE(dest.SERN,-1) = CASE WHEN dest.SERN IS NULL THEN -1 ELSE source.SERN END
WHEN MATCHED AND
	(
	       COALESCE(dest.[CalibDate],'') <> COALESCE(source.[CalibDate],'')
		OR COALESCE(dest.[SerialNumber],'') <> COALESCE(source.[SerialNumber],'')
		OR COALESCE(dest.[ManufacturerNumber],'') <> COALESCE(source.[ManufacturerNumber],'')
		OR COALESCE(dest.[DeviceModel],'') <> COALESCE(source.[DeviceModel],'')
		OR COALESCE(dest.[SpecialCareTypeId],'') <> COALESCE(source.[SpecialCareTypeId],'')
		OR COALESCE(dest.[IsInHouse],'') <> COALESCE(source.[IsInHouse],'')
		OR COALESCE(dest.[PartName],'') <> COALESCE(source.[PartName],'')
		OR COALESCE(dest.[DeviceType],'') <> COALESCE(source.[DeviceType],'')
		OR COALESCE(dest.[MbaReportNumber],'') <> COALESCE(source.[MbaReportNumber],'')
		OR COALESCE(dest.[OrdersMainCategoryId],'') <> COALESCE(source.[OrdersMainCategoryId],'')
		OR COALESCE(dest.[OrdersSecondaryCategoryId],'') <> COALESCE(source.[OrdersSecondaryCategoryId],'')
		OR COALESCE(dest.[OrdersDeviceManufacturerId],'') <> COALESCE(source.[OrdersDeviceManufacturerId],'')
		OR COALESCE(dest.[SecondCategory],'') <> COALESCE(source.[SecondCategory],'')
		OR COALESCE(dest.[CustomerId],'') <> COALESCE(source.[CustomerId],'')
		OR COALESCE(dest.[StatusId],'') <> COALESCE(source.[StatusId],'')
		OR COALESCE(dest.[SERN],'') <> COALESCE(source.[SERN],'')
	)
	THEN
		UPDATE
		SET  dest.[CalibDate] = source.[CalibDate]
			,dest.[SerialNumber] = source.[SerialNumber]
			,dest.[ManufacturerNumber] = source.[ManufacturerNumber]
			,dest.[DeviceModel] = source.[DeviceModel]
			,dest.[SpecialCareTypeId] = source.[SpecialCareTypeId]
			,dest.[IsInHouse] = source.[IsInHouse]
			,dest.[PartName] = source.[PartName]
			,dest.[DeviceType] = source.[DeviceType]
			,dest.[MbaReportNumber] = source.[MbaReportNumber]
			,dest.[OrdersMainCategoryId] = source.[OrdersMainCategoryId]
			,dest.[OrdersSecondaryCategoryId] = source.[OrdersSecondaryCategoryId]
			,dest.[OrdersDeviceManufacturerId] = source.[OrdersDeviceManufacturerId]
			,dest.[SecondCategory] = source.[SecondCategory]
			,dest.[CustomerId] = source.[CustomerId]
			,dest.[StatusId] = source.[StatusId]
			,dest.[SERN] = source.[SERN]
			,dest.[UpdatedDate] = @dt
			,dest.[UpdateUserID] = source.[UpdateUserID]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[OrderWorkPlanId]
			,[CalibDate]
			,[SerialNumber]
			,[ManufacturerNumber]
			,[DeviceModel]
			,[SpecialCareTypeId]
			,[IsInHouse]
			,[PartName]
			,[DeviceType]
			,[MbaReportNumber]
			,[OrdersMainCategoryId]
			,[OrdersSecondaryCategoryId]
			,[OrdersDeviceManufacturerId]
			,[SecondCategory]
			,[CustomerId]
			,[StatusId]
			,[KLINE]
			,[SERN]
			,[CreatedDate]
			,[CreatedByUserId]
			)
		VALUES (
			source.[OrderWorkPlanId]
			,source.[CalibDate]
			,source.[SerialNumber]
			,source.[ManufacturerNumber]
			,source.[DeviceModel]
			,source.[SpecialCareTypeId]
			,source.[IsInHouse]
			,source.[PartName]
			,source.[DeviceType]
			,source.[MbaReportNumber]
			,source.[OrdersMainCategoryId]
			,source.[OrdersSecondaryCategoryId]
			,source.[OrdersDeviceManufacturerId]
			,source.[SecondCategory]
			,source.[CustomerId]
			,source.[StatusId]
			,source.[KLINE]
			,source.[SERN]
			,source.[CreatedDate]
			,source.[CreatedByUserId]
			);


END