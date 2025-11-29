
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 24/11/2025
-- Description:	Get ungrouped devices data to show lowest level data about device for calibration
-- =============================================
CREATE   PROCEDURE [dbo].[GetDevicesUngroupedByOrder]
	@OrderNumber NVARCHAR(20) = NULL,
	@MainCategories NVARCHAR(MAX) = NULL,
	@SecondaryCategories NVARCHAR(MAX) = NULL,
	@DeviceManufacturer NVARCHAR(MAX) = NULL,
	@DeviceModels NVARCHAR(MAX) = NULL,
	@GlobalSearch NVARCHAR(MAX) = NULL,
	@Page NVARCHAR(100) = 'coordinator-orders',
    @PageNumber AS INT = 1,                  -- Resulting page for pagination, starting in 1
    @RowsOfPage AS INT = 10,                 -- Result page size
    @OrderBy AS NVARCHAR(MAX) = 'OrderNumber',      -- OrderBy column
    @OrderByAsc AS BIT = 1                   -- OrderBy direction (ASC/DESC)
AS
BEGIN

SET NOCOUNT ON;

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

/*-------------------------------------------------*/	

IF @OrderBy NOT IN 
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
', 1;

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

DROP TABLE IF EXISTS #DeviceManufacturer
CREATE TABLE #DeviceManufacturer
(
DeviceManufacturer NVARCHAR(255) 
)
INSERT #DeviceManufacturer(DeviceManufacturer)
SELECT DISTINCT v.Value FROM dbo.ParseCSVToTable(@DeviceManufacturer) as v

DROP TABLE IF EXISTS #DeviceModels
CREATE TABLE #DeviceModels
(
DeviceModel NVARCHAR(30) 
)
INSERT #DeviceModels(DeviceModel)
SELECT DISTINCT v.Value FROM dbo.ParseCSVToTable(@DeviceModels) as v


DECLARE @StatusesForOrders NVARCHAR(MAX)

SELECT @StatusesForOrders=STRING_AGG(s.StatusId,',')
FROM [Calibrator].[dbo].[Statuses] as s
JOIN [Calibrator].[dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
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
	,ddd.OrdersDeviceManufacturerDescription as DeviceManufacturer
	,cals.[StatusDescriptionHEB] as CalibrationStatus
	,itm.[IsChecked]
	,op.[CustomerId]
	,itm.[ActualCalibrationDate]
	,op.ExpectedReturnDate as CalibrationDeadline
	,c.CustomerName
	,cbl.Calibrators
	,scs.StatusDescriptionHEB as SpecialTreatment
	,itm.CustomerReceivingDate	
	,itm.ShippingDoc	
	,itm.ShippingAddress
	,COUNT(1) OVER(PARTITION BY 1 ORDER BY op.[OrderNumber] ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as ItemsCount
FROM [dbo].[OrderDetails] as od
JOIN [dbo].[OrderWorkPlans] as op ON od.OrderWorkPlanId = op.OrderWorkPlanId
LEFT JOIN [dbo].[Statuses] as scs ON od.SpecialCareTypeId = scs.StatusId
LEFT JOIN [dbo].[OrderDetailsItems] as itm ON itm.OrderDetailId = od.OrderDetailId
LEFT JOIN [dbo].[Customers] as c ON op.[CustomerId] = c.[CustomerId]
LEFT JOIN [dbo].[MainCategories] as mc ON od.MainCategoryId = mc.ID
LEFT JOIN [dbo].[SecondaryCategories] sc ON od.SecondaryCategoryId = sc.ID
LEFT JOIN [dbo].[OrdersProductTypes] as opt ON od.OrdersProductTypeId = opt.OrdersProductTypeId
LEFT JOIN [dbo].[OrdersDeviceManufacturers] as ddd ON itm.OrdersDeviceManufacturerId = ddd.OrdersDeviceManufacturerId
LEFT JOIN [dbo].[Statuses] as cals ON cals.[StatusId] = itm.[CalibrationStatusId]
LEFT JOIN 
(
SELECT [OrderWorkPlanId]
      ,STRING_AGG(CONCAT(u.FirstName,'' '',u.LastName),'','') as Calibrators
  FROM [dbo].[CalibratorsToWorkPlan] as c
  JOIN [dbo].[Users] as u ON c.[CalibratorId] = u.[ID]
  GROUP BY [OrderWorkPlanId]
) as cbl ON op.OrderWorkPlanId = cbl.[OrderWorkPlanId] 
'
,IIF(@MainCategories IS NOT NULL,' JOIN #MainCategories as mcf ON mc.MainCategoryName COLLATE DATABASE_DEFAULT = mcf.MainCategory COLLATE DATABASE_DEFAULT',' ')
,IIF(@SecondaryCategories IS NOT NULL,' JOIN #SecondaryCategories as scf ON sc.SecondaryCategoryName COLLATE DATABASE_DEFAULT   = scf.SecondaryCategory COLLATE DATABASE_DEFAULT ',' ')
,IIF(@DeviceManufacturer IS NOT NULL,' JOIN #DeviceManufacturer as dmf ON ddd.[OrdersDeviceManufacturerDescription] COLLATE DATABASE_DEFAULT  = dmf.DeviceManufacturer COLLATE DATABASE_DEFAULT ',' ')
,IIF(@DeviceModels IS NOT NULL,' JOIN #DeviceModels as dm ON itm.DeviceModel COLLATE DATABASE_DEFAULT = dm.DeviceModel COLLATE DATABASE_DEFAULT ',' ')
,'
WHERE op.OrderOverallStatusId IN(',@StatusesForOrders,') 
'
,IIF(@OrderNumber IS NOT NULL,'AND op.OrderNumber = TRIM('''+@OrderNumber+''')',' ')
,CASE WHEN @ExtIntFilter IS NOT NULL THEN ' AND od.IsInHouse='+CAST(@ExtIntFilter as NVARCHAR(MAX))+' 'ELSE ' ' END
 ,CASE WHEN @GlobalSearch IS NOT NULL THEN ' AND CONCAT(op.OrderNumber,opt.OrdersProductTypeName,mc.MainCategoryName,sc.SecondaryCategoryName,itm.SerialNumber,itm.AdditionalDeviceNumber,itm.DeviceModel,itm.MbaReportNumber,ddd.OrdersDeviceManufacturerDescription,cals.[StatusDescriptionHEB],c.CustomerName,cbl.Calibrators,scs.StatusDescriptionHEB) LIKE N''%'+ @GlobalSearch +'%'''ELSE ' ' END
,  'ORDER BY ' , @OrderBy , CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END , ' OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')

PRINT @sql
EXEC sp_executesql @sql

END