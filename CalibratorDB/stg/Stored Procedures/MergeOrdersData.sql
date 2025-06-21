
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
		,GETDATE() AS [CreatedDate]
		,0 as [UpdateUserID]
		,0 as [CreatedByUserId]
		,0 as [IsCancelled]
		,NULL as [Notes]
		,o.SourceOrderId as [OrderSourceId]
		,ss.[SourceId]
		,o.PART
		,o.PartName
		,o.OrderLineCnt
		,o.SourceOrderId
		,o.KLINE
		FROM [stg].[stg_Orders] as o
	JOIN [dbo].[Source] as ss ON o.[SourceSystem] = ss.SourceName
	) AS source
	ON dest.[OrderSourceId] = source.[OrderSourceId]
	   AND dest.[OrderSourceId] = source.[OrderSourceId]
	   AND COALESCE(dest.KLINE,0) = COALESCE(source.KLINE,0) 
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
			,[KLINE]
			,[PART]
			,[OrderLineCnt]
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
			,source.[KLINE]
			,source.[PART]
			,source.[OrderLineCnt]
			)
/*WHEN MATCHED AND 
			(COALESCE(dest.[KLINE],0) <> COALESCE(source.[KLINE],0)
			OR COALESCE(dest.[PART],0) <> COALESCE(source.[PART],0))
	THEN UPDATE SET
		    dest.[KLINE]  = source.[KLINE]
			,dest.[PART]  = source.[PART]*/;

	;WITH
	ds
	AS
	(
	SELECT CASE COUNT(*) OVER (
				PARTITION BY wp.OrderSourceId ORDER BY wp.KLINE ROWS BETWEEN UNBOUNDED PRECEDING
						AND UNBOUNDED FOLLOWING
				)
			WHEN 1
				THEN wp.[OrderNumber]
			ELSE CONCAT (
					wp.[OrderNumber]
					,'-'
					,ROW_NUMBER() OVER (
						PARTITION BY wp.OrderSourceId
						,wp.SourceId ORDER BY wp.KLINE
						)
					)
			END as OrderNumber
		,wp.OrderWorkPlanId
	FROM [dbo].[OrderWorkPlans] AS wp
	WHERE wp.CreatedDate >= GETDATE() - 30
	)
	UPDATE wp
	SET wp.OrderNumber = d.OrderNumber
	FROM ds as d
	JOIN [dbo].[OrderWorkPlans] AS wp ON wp.OrderWorkPlanId = d.OrderWorkPlanId
	WHERE wp.OrderNumber NOT LIKE '%-%'


MERGE INTO [dbo].[OrderDetails] AS dest
USING (
	SELECT 
	    wp.[OrderWorkPlanId]
		,o.[SerialNumber]
		,o.[ManufacturerNumber]
		,o.[Devicemodel] as [DeviceModel]
		,o.[SpecialCareTypeId]
		,o.[InHouse] as [IsInHouse]
		,o.[PartName]
		,o.[MbaReportNumber]
		,mc.[OrdersMainCategoryId]
		,sc.[OrdersSecondaryCategoryId]
		,mf.[OrdersDeviceManufacturerId]
		,c.[CustomerId]
		,o.[KLINE]
		,o.[SERN]
		,pt.OrdersProductTypeId
	    ,o.[ProductLocation]
		,NULL AS [StatusId]
		,GETDATE() as [CreatedDate]
		,GETDATE() as [UpdatedDate]
		,0 as [CreatedByUserId]
		,0 as [UpdateUserID]
	FROM [stg].[stg_Orders] as o
	JOIN [dbo].[Source] as s ON o.SourceSystem = s.SourceName
	JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderSourceId = o.SourceOrderId AND wp.SourceId = s.SourceId AND wp.KLINE = o.KLINE
	LEFT JOIN [dbo].[OrdersMainCategories] as mc ON o.MainCategorySourceId = mc.OrdersMainCategoryName
	LEFT JOIN [dbo].[OrdersSecondaryCategories] as sc ON o.SecondCategorySourceId = sc.OrdersSecondaryCategoryName
	LEFT JOIN [dbo].[OrdersProductTypes] as pt ON pt.OrdersProductTypeName = o.DeviceType
	LEFT JOIN [dbo].[OrdersDeviceManufacturers] as mf ON mf.OrdersDeviceManufacturerName = o.ManufacturerNumber
	LEFT JOIN [dbo].[Customers] as c ON c.CustomerIdFromSource = o.CustomerSourceId AND c.SourceId = s.SourceId
	WHERE o.[SERN] IS NOT NULL
	) AS source
	ON dest.[OrderWorkPlanId] = source.[OrderWorkPlanId] AND source.[KLINE] = dest.[KLINE] AND source.[SERN] = dest.[SERN]
/*WHEN MATCHED
	THEN
		UPDATE
		SET  dest.[SerialNumber] = source.[SerialNumber]
			,dest.[ManufacturerNumber] = source.[ManufacturerNumber]
			,dest.[DeviceModel] = source.[DeviceModel]
			,dest.[SpecialCareTypeId] = source.[SpecialCareTypeId]
			,dest.[IsInHouse] = source.[IsInHouse]
			,dest.[PartName] = source.[PartName]
			,dest.[MbaReportNumber] = source.[MbaReportNumber]
			,dest.[OrdersMainCategoryId] = source.[OrdersMainCategoryId]
			,dest.[OrdersSecondaryCategoryId] = source.[OrdersSecondaryCategoryId]
			,dest.[OrdersDeviceManufacturerId] = source.[OrdersDeviceManufacturerId]
			,dest.[SecondCategory] = source.[SecondCategory]
			,dest.[CustomerId] = source.[CustomerId]
			,dest.[StatusId] = source.[StatusId]
			,dest.[OrdersProductTypeId] = source.[OrdersProductTypeId]
			,dest.[CreatedDate] = source.[CreatedDate]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[UpdateUserID] = source.[UpdateUserID]*/
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[OrderWorkPlanId]
			,[SerialNumber]
			,[ManufacturerNumber]
			,[DeviceModel]
			,[SpecialCareTypeId]
			,[IsInHouse]
			,[PartName]
			,[MbaReportNumber]
			,[OrdersMainCategoryId]
			,[OrdersSecondaryCategoryId]
			,[OrdersDeviceManufacturerId]
			,[CustomerId]
			,[StatusId]
			,[KLINE]
			,[SERN]
			,[OrdersProductTypeId]
			,[CreatedDate]
			,[UpdatedDate]
			,[CreatedByUserId]
			,[UpdateUserID]
			)
		VALUES (
			 source.[OrderWorkPlanId]
			,source.[SerialNumber]
			,source.[ManufacturerNumber]
			,source.[DeviceModel]
			,source.[SpecialCareTypeId]
			,source.[IsInHouse]
			,source.[PartName]
			,source.[MbaReportNumber]
			,source.[OrdersMainCategoryId]
			,source.[OrdersSecondaryCategoryId]
			,source.[OrdersDeviceManufacturerId]
			,source.[CustomerId]
			,source.[StatusId]
			,source.[KLINE]
			,source.[SERN]
			,source.[OrdersProductTypeId]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[CreatedByUserId]
			,source.[UpdateUserID]
			);

END