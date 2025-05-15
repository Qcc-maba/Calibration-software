-- =============================================
-- Author:		Shamailov Slavik
-- Create date: 06/03/2025
-- Description:	Get devices by order number
-- =============================================
CREATE PROCEDURE [dbo].[GetDevicesByOrder] --'LA25100040  '
	@OrderNumber NVARCHAR(20),
	@MainCategories NVARCHAR(50) = NULL,
	@SecondaryCategories NVARCHAR(50) = NULL,
	@DeviceManufacturer NVARCHAR(255) = NULL,
	@DeviceModels NVARCHAR(30) = NULL
AS
BEGIN

	SET NOCOUNT ON;

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
WHERE OrderNumber = TRIM(''',@OrderNumber,''')
'
,CASE WHEN @MainCategories IS NOT NULL THEN' AND od.MainCategory = '''+@MainCategories+''' 'ELSE ' ' END
,CASE WHEN @SecondaryCategories IS NOT NULL THEN' AND od.SecondCategory = '''+@SecondaryCategories+''' 'ELSE ' ' END
,CASE WHEN @DeviceManufacturer IS NOT NULL THEN' AND od.DeviceManufacturer = '''+@DeviceManufacturer+''' 'ELSE ' ' END
,CASE WHEN @DeviceModels IS NOT NULL THEN' AND od.DeviceModel = '''+@DeviceModels+''' 'ELSE ' ' END
,'
ORDER BY OrderNumber
	,MbaReportNumber
')
PRINT @sql
EXEC sp_executesql @sql

END