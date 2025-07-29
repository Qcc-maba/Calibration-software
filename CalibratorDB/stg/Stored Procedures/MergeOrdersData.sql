
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

DROP TABLE IF EXISTS #OrderStatus
CREATE TABLE #OrderStatus
(
StatusId INT NOT NULL,
Code INT
)
INSERT #OrderStatus (StatusId,Code)
SELECT s.StatusId, TRY_CAST(s.Code AS INT) as Code
FROM [Calibrator].[dbo].[Statuses] as s
JOIN [Calibrator].[dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
WHERE sc.StatusDescriptionENG = 'OrderStatus' AND TRY_CAST(s.Code AS INT) <> 0

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
		,c.[CustomerId]
		,NULL as [Notes]
		,o.SourceOrderId as [OrderSourceId]
		,ss.[SourceId]
		,o.SourceOrderId
		,os.StatusId as OrderOverallStatusId
		FROM [stg].[stg_Orders] as o
	JOIN [dbo].[Source] as ss ON o.[SourceSystem] = ss.SourceName
    LEFT JOIN [dbo].[Customers] as c ON c.CustomerIdFromSource = o.CustomerSourceId AND c.SourceId = ss.SourceId and c.IsDeleted = 0
	LEFT JOIN #OrderStatus AS os ON o.ORDSTATUS = os.Code
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
			,[CustomerId]
			,[OrderOverallStatusId]
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
			,source.[CustomerId]
			,source.[OrderOverallStatusId]
			)
WHEN MATCHED AND
	(
		  COALESCE(dest.[OrderOverallStatusId],0) <> COALESCE(source.[OrderOverallStatusId],0)
	)
	THEN
		UPDATE
		SET dest.[OrderOverallStatusId] = source.[OrderOverallStatusId],
		    dest.[UpdateUserID] = source.[UpdateUserID];

	
MERGE INTO [dbo].[OrderDetails] AS dest
USING (
	SELECT DISTINCT
	    wp.[OrderWorkPlanId]
		,o.[SpecialCareTypeId]
		,o.[InHouse] as [IsInHouse]
		,o.[PartName]
		,o.[KLINE]
		,o.[PART]
		,GETDATE() as [CreatedDate]
		,GETDATE() as [UpdatedDate]
		,0 as [CreatedByUserId]
		,0 as [UpdateUserID]
		,o.OrderLineCnt
		,pt.OrdersProductTypeId
		,o.DeviceType 
	FROM [stg].[stg_Orders] as o
	JOIN [dbo].[Source] as s ON o.SourceSystem = s.SourceName
	JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderSourceId = o.SourceOrderId AND wp.SourceId = s.SourceId 
	LEFT JOIN [dbo].[OrdersProductTypes] as pt ON pt.OrdersProductTypeName = o.DeviceType and pt.IsDeleted = 0
	) AS source
	ON dest.[OrderWorkPlanId] = source.[OrderWorkPlanId] AND source.[KLINE] = dest.[KLINE] 
WHEN MATCHED AND
	(
		  COALESCE(dest.[SpecialCareTypeId],0) <> COALESCE(source.[SpecialCareTypeId],0)
		OR COALESCE(dest.[IsInHouse],0) <> COALESCE(source.[IsInHouse],0)
		OR COALESCE(dest.[OrderLineCnt],0) <> COALESCE(source.[OrderLineCnt],0)
		OR COALESCE(dest.OrdersProductTypeId,0) <> COALESCE(source.[OrdersProductTypeId],0)
		OR COALESCE(dest.[PART],0) <> COALESCE(source.[PART],0)
	)
	THEN
		UPDATE
		SET  dest.[SpecialCareTypeId] = source.[SpecialCareTypeId]
			,dest.[IsInHouse] = source.[IsInHouse]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[UpdateUserID] = source.[UpdateUserID]
			,dest.[OrderLineCnt] = source.[OrderLineCnt]
			,dest.[OrdersProductTypeId] = source.[OrdersProductTypeId]
			,dest.[PART] = source.[PART]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[OrderWorkPlanId]
			,[SpecialCareTypeId]
			,[IsInHouse]
			,[PartName]
			,[KLINE]
			,[CreatedDate]
			,[UpdatedDate]
			,[CreatedByUserId]
			,[UpdateUserID]
			,[OrderLineCnt]
			,[OrdersProductTypeId]
			,[PART]
			)
		VALUES (
			 source.[OrderWorkPlanId]
			,source.[SpecialCareTypeId]
			,source.[IsInHouse]
			,source.[PartName]
			,source.[KLINE]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[CreatedByUserId]
			,source.[UpdateUserID]
			,source.[OrderLineCnt]
			,source.[OrdersProductTypeId]
			,source.[PART]
			);

	
MERGE INTO [dbo].[OrderDetailsItems] AS dest
USING (
	SELECT 
	     o.[SerialNumber]
		,od.OrderDetailId
		,o.[ManufacturerNumber]
		,o.[Devicemodel] as [DeviceModel]
		,o.[SpecialCareTypeId]
		,o.[InHouse] as [IsInHouse]
		,o.[PartName]
		,o.[MbaReportNumber]
		,mc.[ID] as [MainCategoryId]
		,sc.[OrdersSecondaryCategoryId]
		,mf.[OrdersDeviceManufacturerId]
		,c.[CustomerId]
		,o.[KLINE]
		,o.[SERN]
	    ,o.[ProductLocation]
		,NULL AS [StatusId]
		,GETDATE() as [CreatedDate]
		,GETDATE() as [UpdatedDate]
		,0 as [CreatedByUserId]
		,0 as [UpdateUserID]
	FROM [stg].[stg_Orders] as o
	JOIN [dbo].[Source] as s ON o.SourceSystem = s.SourceName
	JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderSourceId = o.SourceOrderId AND wp.SourceId = s.SourceId
	JOIN [dbo].[OrderDetails] as od ON wp.[OrderWorkPlanId] = od.[OrderWorkPlanId] AND o.[KLINE] = od.[KLINE] 
	LEFT JOIN [dbo].[MainCategories] as mc ON o.MainCategorySourceId = mc.MainCategoryName and mc.IsDeleted = 0
	LEFT JOIN [dbo].[OrdersSecondaryCategories] as sc ON o.SecondCategorySourceId = sc.OrdersSecondaryCategoryName and sc.IsDeleted = 0
	LEFT JOIN [dbo].[OrdersDeviceManufacturers] as mf ON mf.OrdersDeviceManufacturerName = o.ManufacturerNumber and mf.IsDeleted = 0
	LEFT JOIN [dbo].[Customers] as c ON c.CustomerIdFromSource = o.CustomerSourceId AND c.SourceId = s.SourceId and c.IsDeleted = 0
	WHERE o.[SERN] IS NOT NULL
	) AS source
	ON dest.OrderDetailId = source.OrderDetailId AND source.[SERN] = dest.[SERN]
/*WHEN MATCHED
	THEN
		UPDATE
		SET  dest.[SerialNumber] = source.[SerialNumber]
			,dest.[ManufacturerNumber] = source.[ManufacturerNumber]
			,dest.[DeviceModel] = source.[DeviceModel]
			,dest.[MbaReportNumber] = source.[MbaReportNumber]
			,dest.[OrdersMainCategoryId] = source.[OrdersMainCategoryId]
			,dest.[OrdersSecondaryCategoryId] = source.[OrdersSecondaryCategoryId]
			,dest.[OrdersDeviceManufacturerId] = source.[OrdersDeviceManufacturerId]
			,dest.[StatusId] = source.[StatusId]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[UpdateUserID] = source.[UpdateUserID]*/
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[OrderDetailId]
			,[SerialNumber]
			,[ManufacturerNumber]
			,[DeviceModel]
			,[MbaReportNumber]
			,[MainCategoryId]
			,[OrdersSecondaryCategoryId]
			,[OrdersDeviceManufacturerId]
			,[CreatedDate]
			,[UpdatedDate]
			,[CreatedByUserId]
			,[UpdateUserID]
			,[SERN]
			)
		VALUES (
			 source.[OrderDetailId]
			,source.[SerialNumber]
			,source.[ManufacturerNumber]
			,source.[DeviceModel]
			,source.[MbaReportNumber]
			,source.[MainCategoryId]
			,source.[OrdersSecondaryCategoryId]
			,source.[OrdersDeviceManufacturerId]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[CreatedByUserId]
			,source.[UpdateUserID]
			,source.[SERN]
			);
END