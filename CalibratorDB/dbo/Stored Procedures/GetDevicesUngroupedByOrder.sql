
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 24/11/2025
-- Description:	Get ungrouped devices data to show lowest level data about device for calibration
-- =============================================
CREATE   PROCEDURE [dbo].[GetDevicesUngroupedByOrder]
	@OrderNumber NVARCHAR(20) = NULL,
	@MainCategories NVARCHAR(MAX) = NULL,
	@SecondaryCategories NVARCHAR(MAX) = NULL,
	@DeviceManufacturer NVARCHAR(50) = NULL,
	@DeviceModels NVARCHAR(MAX) = NULL,
	@GlobalSearch NVARCHAR(MAX) = NULL,
	@Page NVARCHAR(100) = 'coordinator-orders',
    @PageNumber AS INT = 1,                  -- Resulting page for pagination, starting in 1
    @RowsOfPage AS INT = 10,                 -- Result page size
    @OrderBy AS NVARCHAR(MAX) = 'OrderNumber',      -- OrderBy column
    @OrderByAsc AS BIT = 1,                   -- OrderBy direction (ASC/DESC)
	@OrderWorkPlanIds NVARCHAR(MAX) = NULL,
	@OrderWorkDetailsItemsIds NVARCHAR(MAX) = NULL,
	@ExcludeAwaitingCollectionOrders BIT = 0
AS
BEGIN

SET NOCOUNT ON;

--IF @OrderNumber IS NULL OR @OrderWorkPlanIds IS NULL 
--	THROW 51000, 'Parameters @OrderNumber or @OrderWorkPlanIds should be specified.',1
/*
Filter logic by page
/coordinator-orders - @page = ‘coordinator-orders’ 
/external-schedule - @page = ‘external-schedule’
/internal-orders - @page = ‘internal-orders’
/calibration-wizard - @page = ‘calibration-wizard’ 
/external-orders - @page = 'external-orders'
*/
/*-------------------------------------------------*/

DECLARE @ExtIntFilter BIT = NULL

IF @Page IN (N'external-schedule',N'external-orders',N'coordinator-orders') SET @ExtIntFilter = 0 -- IsInHouse = 0 for external orders

IF @Page IN (N'internal-orders') SET @ExtIntFilter = 1 -- IsInHouse = 0 for internal orders

IF @ExcludeAwaitingCollectionOrders = 1
BEGIN
   
	DROP TABLE IF EXISTS #AwaitingCollectionOrders
	CREATE TABLE #AwaitingCollectionOrders(OrderWorkPlanId INT)

	INSERT #AwaitingCollectionOrders(OrderWorkPlanId)
	SELECT wp.OrderWorkPlanId
	FROM [dbo].[OrderWorkPlans] as wp
	JOIN Statuses as s ON wp.OrderOverallStatusId = s.StatusId
	WHERE s.StatusDescriptionENG='AwaitingCollection'
/*	SELECT od.OrderWorkPlanId
	FROM [dbo].[OrderDetails] as od
	JOIN [dbo].[OrderDetailsItems] as itm ON itm.OrderDetailId = od.OrderDetailId
	LEFT JOIN [dbo].[Statuses] as scs ON itm.CalibrationStatusId = scs.StatusId
	GROUP BY od.OrderWorkPlanId
	HAVING MIN(COALESCE(scs.StatusDescriptionENG,'N/A')) = MAX(COALESCE(scs.StatusDescriptionENG,'N/A'))
	AND MAX(COALESCE(scs.StatusDescriptionENG,'N/A')) IN('AwaitingCollection','ReadyForPacking','AwaitingCollection','ReadyForDelivery')
	*/
	CREATE UNIQUE CLUSTERED INDEX IDX_AwaitingCollectionOrders ON #AwaitingCollectionOrders(OrderWorkPlanId)



END

/*-------------------------------------------------*/	

/*IF @OrderBy NOT IN 
(N'OrderNumber',
N'OrderId',N'OrderDetailId',N'OrderDetailsItemId',
N'DeviceType',N'DepartmentId',N'MainCategory',N'SecondCategory',N'SerialNumber',N'AdditionalDeviceNumber',N'DeviceModel',N'MbaReportNumber',N'DeviceManufacturer',
N'CalibrationStatus',N'IsChecked',N'CustomerId',N'ActualCalibrationDate',N'CalibrationDeadline',N'CustomerName',N'Calibrators',N'SpecialTreatment'
)
THROW 51000, 'Incorrect value for parameter @OrderBy. Available values 
|OrderNumber
|OrderId|OrderDetailId|OrderDetailsItemId
|DeviceType|DepartmentId|MainCategory|SecondCategory|SerialNumber|AdditionalDeviceNumber|DeviceModel|MbaReportNumber|DeviceManufacturer
|CalibrationStatus|IsChecked|CustomerId|ActualCalibrationDate|CalibrationDeadline|CustomerName|Calibrators|SpecialTreatment
', 1;*/

DROP TABLE IF EXISTS #MainCategories
CREATE TABLE #MainCategories
(
MainCategory NVARCHAR(50) 
)
INSERT #MainCategories(MainCategory)
SELECT DISTINCT CAST(v.Value AS NVARCHAR(50)) FROM dbo.ParseCSVToTable(@MainCategories) as v


DROP TABLE IF EXISTS #SecondaryCategories
CREATE TABLE #SecondaryCategories
(
SecondaryCategory NVARCHAR(50) 
)
INSERT #SecondaryCategories(SecondaryCategory)
SELECT DISTINCT v.Value FROM dbo.ParseCSVToTable(@SecondaryCategories) as v

DROP TABLE IF EXISTS #DeviceModels
CREATE TABLE #DeviceModels
(
DeviceModel NVARCHAR(30) 
)
INSERT #DeviceModels(DeviceModel)
SELECT DISTINCT v.Value FROM dbo.ParseCSVToTable(@DeviceModels) as v


DECLARE @StatusesForOrders NVARCHAR(MAX)

SELECT @StatusesForOrders=STRING_AGG(s.StatusId,',')
FROM [dbo].[Statuses] as s
JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
WHERE sc.StatusDescriptionENG='OrderStatus' AND s.StatusDescriptionENG <> 'Executed'


DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'SELECT
     op.OrderNumber
	,od.OrderWorkPlanId as OrderId
	,od.OrderDetailId
	,itm.OrderDetailsItemId
	,opt.OrdersProductTypeName AS DeviceType
	,mc.ID AS DepartmentId
	,mc.MainCategoryName as MainCategory
	,sc.SecondaryCategoryName AS SecondCategory
	,itm.SerialNumber
    ,itm.AdditionalDeviceNumber
	,itm.DeviceModel
	,itm.MbaReportNumber
	,itm. OrdersDeviceManufacturer as DeviceManufacturer
	,cals.[StatusDescriptionHEB] as CalibrationStatus
	,ordst.[StatusDescriptionHEB] as OrderStatus
	,ordst.[StatusDescriptionENG] as OrderStatusENG
	,itm.[IsChecked]
	,op.[CustomerId]
	,itm.[ActualCalibrationDate]
	,itm.ExpectedReturnDate as CalibrationDeadline
	,c.CustomerName
	,cbl.Calibrators
	,scs.StatusDescriptionHEB as SpecialTreatment
	,itm.CustomerReceivingDate	
	,itm.ShippingDoc	
	,itm.ShippingAddress
	,c.CustomerAddress
	,custeqv.details as AdditionalEquipment
	,op.ShipTypeDesc as ShippingMethod
	,itm.[StickerAmount]
	,stist.[StatusDescriptionHEB] as [StickerType]
	,COUNT(1) OVER() as ItemsCount
FROM [dbo].[OrderDetails] as od
JOIN [dbo].[OrderWorkPlans] as op ON od.OrderWorkPlanId = op.OrderWorkPlanId
LEFT JOIN [dbo].[Statuses] as scs ON od.SpecialCareTypeId = scs.StatusId
LEFT JOIN [dbo].[OrderDetailsItems] as itm ON itm.OrderDetailId = od.OrderDetailId
LEFT JOIN [dbo].[Customers] as c ON op.[CustomerId] = c.[CustomerId]
LEFT JOIN [dbo].[MainCategories] as mc ON od.MainCategoryId = mc.ID
LEFT JOIN [dbo].[SecondaryCategories] sc ON od.SecondaryCategoryId = sc.ID
LEFT JOIN [dbo].[OrdersProductTypes] as opt ON od.OrdersProductTypeId = opt.OrdersProductTypeId
LEFT JOIN [dbo].[Statuses] as cals ON cals.[StatusId] = itm.[CalibrationStatusId]
LEFT JOIN [dbo].[Statuses] as ordst ON ordst.[StatusId] = op.[OrderOverallStatusId]
LEFT JOIN [dbo].[Statuses] as stist ON stist.[StatusId] = itm.[StickerTypeId]
OUTER APPLY
(
SELECT [OrderWorkPlanId]
      ,STRING_AGG(CONCAT(u.FirstName,'' '',u.LastName),'','') as Calibrators
  FROM [dbo].[CalibratorsToWorkPlan] as c
  JOIN [dbo].[Users] as u ON c.[CalibratorId] = u.[ID]
  WHERE op.OrderWorkPlanId = c.[OrderWorkPlanId] 
  GROUP BY [OrderWorkPlanId]
) as cbl 
OUTER APPLY
(
SELECT
    d.OrderDetailsItemId,
    ''['' +
    STRING_AGG(
        CONCAT(''{'',
       ''"ItemsCount":'', d.[ItemsCount],'','',
       ''"AccessoryDescription":'',''"'',d.[AccessoryDescription],''",'',
       ''"AccessoryLocation":'',''"'',d.[AccessoryLocation],''"'',
       ''}''
        ),
        '',''
    )
    + '']'' AS details
FROM [dbo].[ClientAccessoryOrderDetailsItems] AS d
WHERE d.OrderDetailsItemId = itm.OrderDetailsItemId
GROUP BY d.OrderDetailsItemId
) as custeqv
'
,IIF(@OrderWorkPlanIds IS NOT NULL,' JOIN STRING_SPLIT('''+@OrderWorkPlanIds+''','','') as wpf ON op.OrderWorkPlanId = wpf.value',' ')
,IIF(@OrderWorkDetailsItemsIds IS NOT NULL,' JOIN STRING_SPLIT('''+@OrderWorkDetailsItemsIds+''','','') as wpf1 ON itm.OrderDetailsItemId = wpf1.value',' ')
,IIF(@MainCategories IS NOT NULL,' JOIN #MainCategories as mcf ON mc.MainCategoryName COLLATE DATABASE_DEFAULT = mcf.MainCategory COLLATE DATABASE_DEFAULT',' ')
,IIF(@SecondaryCategories IS NOT NULL,' JOIN #SecondaryCategories as scf ON sc.SecondaryCategoryName COLLATE DATABASE_DEFAULT   = scf.SecondaryCategory COLLATE DATABASE_DEFAULT ',' ')
,IIF(@DeviceModels IS NOT NULL,' JOIN #DeviceModels as dm ON itm.DeviceModel COLLATE DATABASE_DEFAULT = dm.DeviceModel COLLATE DATABASE_DEFAULT ',' ')
,'
WHERE op.OrderOverallStatusId IN(',@StatusesForOrders,') 
'
,IIF(@ExcludeAwaitingCollectionOrders = 1,'AND NOT EXISTS (SELECT 1 FROM #AwaitingCollectionOrders as f WHERE f.OrderWorkPlanId = op.OrderWorkPlanId)','')
,IIF(@OrderNumber IS NOT NULL,'AND op.OrderNumber = TRIM('''+@OrderNumber+''')',' ')
,IIF(@DeviceManufacturer IS NOT NULL,'AND itm.OrdersDeviceManufacturer LIKE ''%'+@DeviceManufacturer+'%''',' ')
,CASE WHEN @ExtIntFilter IS NOT NULL THEN ' AND od.IsInHouse='+CAST(@ExtIntFilter as NVARCHAR(MAX))+' 'ELSE ' ' END
 ,CASE WHEN @GlobalSearch IS NOT NULL THEN ' AND CONCAT(op.OrderNumber,opt.OrdersProductTypeName,mc.MainCategoryName,sc.SecondaryCategoryName,itm.SerialNumber,itm.AdditionalDeviceNumber,itm.DeviceModel,itm.MbaReportNumber,itm.OrdersDeviceManufacturer,cals.[StatusDescriptionHEB],c.CustomerName,cbl.Calibrators,scs.StatusDescriptionHEB) LIKE N''%'+ @GlobalSearch +'%'''ELSE ' ' END
,  'ORDER BY ' , @OrderBy , CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END , ' OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')

PRINT @sql
EXEC sp_executesql @sql

END