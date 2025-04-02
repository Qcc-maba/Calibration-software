-- =============================================
-- Author:		Shamailov Slavik
-- Create date: 06/03/2025
-- Description:	Get devices by order number
-- =============================================
CREATE PROCEDURE [dbo].[GetDevicesByOrder] --'LA25100040  '
	@OrderNumber as varchar(20)
AS
BEGIN

	SET NOCOUNT ON;

	--Device type
	--Main field
	--Secondary field
	--Number of points
	--Device number
	--Device model

SELECT 
     op.OrderNumber
	,od.OrderWorkPlanId as OrderId
	,od.PartDescription AS [Device type]
	,od.DepartmentId 
	,d.DepartmentName AS [Main field]
	,od.DeviceDescription AS [Secondary field]
	,od.SerialNumber AS [Device number]
	,od.DeviceModel AS [Device model]
	,od.MbaReportNumber
FROM [dbo].[OrderDetails] as od
JOIN [dbo].[OrderWorkPlans] as op ON od.OrderWorkPlanId = op.OrderWorkPlanId
LEFT JOIN [dbo].[Departments] as d ON d.ID = od.DepartmentId
WHERE (OrderNumber = TRIM(@OrderNumber))

ORDER BY OrderNumber
	,MbaReportNumber

END