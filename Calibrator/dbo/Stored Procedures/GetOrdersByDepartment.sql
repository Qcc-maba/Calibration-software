
-- =============================================
-- Author:		Shamailov Slavik
-- Create date: 24/12/2024
-- Description:	Get orders and work plan data for depatment
-- =============================================
CREATE PROCEDURE [dbo].[GetOrdersByDepartment]
	@DepartmentId int	
AS
BEGIN
	DECLARE @ResCount int;
	SELECT	dbo.vwGetOrderDevices.DEPTDES AS Department, dbo.vwGetOrdersData.OrderNumber AS [Order Number], dbo.vwGetOrderDevices.MBANUM AS [MBA Number], 
			dbo.vwGetOrderDevices.[Open Date], 
			dbo.vwGetOrdersData.CustomerName as [Client Name], 
			dbo.vwGetOrderDevices.NextCalibDate as [Calibration last date], dbo.vwGetOrderDevices.[Device Description] as Equipment, 
			dbo.vwGetOrdersData.CustomerPhone, dbo.vwGetOrdersData.CustomerContactName, dbo.vwGetOrdersData.CustomerCity, dbo.vwGetOrdersData.CustomerAddress, dbo.vwGetOrdersData.MBAContactName, 
			dbo.vwGetOrdersData.MBAContactPhone, dbo.vwGetOrdersData.MBAContactMobile, 
			dbo.vwGetOrderDevices.[Device model], dbo.vwGetOrderDevices.[Serial Number], dbo.vwGetOrderDevices.[Device manufacturer], 
			dbo.vwGetOrdersData.ClientRemarks
	FROM    dbo.vwGetOrdersData INNER JOIN
			dbo.vwGetOrderDevices ON dbo.vwGetOrdersData.OrderNumber = dbo.vwGetOrderDevices.[Order Number] INNER JOIN
			dbo.UsersToDepartments ON dbo.vwGetOrderDevices.DEPT = dbo.UsersToDepartments.DepartmentId
	WHERE   (dbo.UsersToDepartments.DepartmentId = @DepartmentId)    ;

	SELECT @ResCount =  @@ROWCOUNT;
	return @ResCount;
END
