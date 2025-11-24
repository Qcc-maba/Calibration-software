
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
	@Page NVARCHAR(100) = 'coordinator-orders'
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
WHERE 1=1
'
,IIF(@OrderNumber IS NOT NULL,'AND op.OrderNumber = TRIM('''+@OrderNumber+''')',' ')
,CASE WHEN @ExtIntFilter IS NOT NULL THEN ' AND od.IsInHouse='+CAST(@ExtIntFilter as NVARCHAR(MAX))+' 'ELSE ' ' END
)
PRINT @sql
EXEC sp_executesql @sql

END