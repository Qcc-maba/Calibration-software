-- =============================================
-- Author:		Shamailov Slavik
-- Create date: 06/03/2025
-- Description:	Get devices by order number
-- =============================================
CREATE PROCEDURE [dbo].[GetDevicesByOrder] --'LA25100040  '
	@OrderNumber nvarchar(20),
	@MainCategories nvarchar(MAX) = NULL,
	@SecondaryCategories nvarchar(MAX) = NULL,
	@DeviceManufacturer nvarchar(MAX) = NULL,
	@DeviceModels nvarchar(MAX) = NULL
AS
BEGIN

	SET NOCOUNT ON;
	

DROP TABLE IF EXISTS #MainCategories
CREATE TABLE #MainCategories
(
MainCategory NVARCHAR(50)
)
INSERT #MainCategories(MainCategory)
SELECT DISTINCT v.Value FROM dbo.ParseCSVToTable(@MainCategories) as v


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
	,od.PartDescription AS DeviceType
	,od.DepartmentId 
	,od.MainCategory
	,od.SecondCategory
	,od.SerialNumber
	,od.DeviceModel
	,od.MbaReportNumber
	,od.OrderDetailId
	,od.DeviceManufacturer
FROM [dbo].[OrderDetails] as od
JOIN [dbo].[OrderWorkPlans] as op ON od.OrderWorkPlanId = op.OrderWorkPlanId
'
,IIF(@MainCategories IS NOT NULL,' JOIN #MainCategories as mc ON od.MainCategory COLLATE DATABASE_DEFAULT  = mc.MainCategory COLLATE DATABASE_DEFAULT ',' ')
,IIF(@SecondaryCategories IS NOT NULL,' JOIN #SecondaryCategories as sc ON od.SecondCategory COLLATE DATABASE_DEFAULT   = sc.SecondaryCategory COLLATE DATABASE_DEFAULT ',' ')
,IIF(@DeviceManufacturer IS NOT NULL,' JOIN #DeviceManufacturer as dmf ON od.DeviceManufacturer COLLATE DATABASE_DEFAULT  = dmf.DeviceManufacturer COLLATE DATABASE_DEFAULT ',' ')
,IIF(@DeviceModels IS NOT NULL,' JOIN #DeviceModels as dm ON od.DeviceModel COLLATE DATABASE_DEFAULT = dm.DeviceModel COLLATE DATABASE_DEFAULT ',' ')
,'
WHERE OrderNumber = TRIM(''',@OrderNumber,''')
ORDER BY OrderNumber
	,MbaReportNumber
')
PRINT @sql
EXEC sp_executesql @sql

END