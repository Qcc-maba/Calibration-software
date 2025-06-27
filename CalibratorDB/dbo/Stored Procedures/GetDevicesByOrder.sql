-- =============================================
-- Author:		Shamailov Slavik
-- Create date: 06/03/2025
-- Description:	Get devices by order number
-- =============================================
CREATE PROCEDURE [dbo].[GetDevicesByOrder] --'LA25102864'
	@OrderNumber NVARCHAR(20),
	@MainCategories NVARCHAR(MAX) = NULL,
	@SecondaryCategories NVARCHAR(MAX) = NULL,
	@DeviceManufacturer NVARCHAR(MAX) = NULL,
	@DeviceModels NVARCHAR(MAX) = NULL
AS
BEGIN

	SET NOCOUNT ON;
	

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
'SELECT DISTINCT
     op.OrderNumber
	,od.OrderWorkPlanId as OrderId
	,od.OrderDetailId
	,opt.OrdersProductTypeName AS DeviceType
	,mc.OrdersMainCategoryName AS DepartmentId
	,mc.OrdersMainCategoryName as MainCategory
	,sc.OrdersSecondaryCategoryName AS SecondCategory
	--,itm.SerialNumber
	--,itm.DeviceModel
	--,itm.MbaReportNumber
	--,od.OrderDetailId
	,odm.OrdersDeviceManufacturerName as DeviceManufacturer
	,od.OrderLineCnt
	,od.PartName
FROM [dbo].[OrderDetails] as od
JOIN [dbo].[OrderWorkPlans] as op ON od.OrderWorkPlanId = op.OrderWorkPlanId
LEFT JOIN [dbo].[OrderDetailsItems] as itm ON itm.OrderDetailId = od.OrderDetailId
LEFT JOIN [dbo].[OrdersMainCategories] as mc ON itm.OrdersMainCategoryId = mc.OrdersMainCategoryId
LEFT JOIN [dbo].[OrdersSecondaryCategories] sc ON itm.OrdersSecondaryCategoryId = sc.OrdersSecondaryCategoryId
LEFT JOIN [dbo].[OrdersProductTypes] as opt ON od.OrdersProductTypeId = opt.OrdersProductTypeId
LEFT JOIN [dbo].[OrdersDeviceManufacturers] as odm ON itm.OrdersDeviceManufacturerId = odm.OrdersDeviceManufacturerId 
'
,IIF(@MainCategories IS NOT NULL,' JOIN #MainCategories as mcf ON mc.OrdersMainCategoryName COLLATE DATABASE_DEFAULT = mcf.MainCategory COLLATE DATABASE_DEFAULT',' ')
,IIF(@SecondaryCategories IS NOT NULL,' JOIN #SecondaryCategories as scf ON sc.OrdersSecondaryCategoryName COLLATE DATABASE_DEFAULT   = scf.SecondaryCategory COLLATE DATABASE_DEFAULT ',' ')
,IIF(@DeviceManufacturer IS NOT NULL,' JOIN #DeviceManufacturer as dmf ON odm.OrdersDeviceManufacturerName COLLATE DATABASE_DEFAULT  = dmf.DeviceManufacturer COLLATE DATABASE_DEFAULT ',' ')
,IIF(@DeviceModels IS NOT NULL,' JOIN #DeviceModels as dm ON itm.DeviceModel COLLATE DATABASE_DEFAULT = dm.DeviceModel COLLATE DATABASE_DEFAULT ',' ')
,'
WHERE OrderNumber = TRIM(''',@OrderNumber,''')

')
PRINT @sql
EXEC sp_executesql @sql

END