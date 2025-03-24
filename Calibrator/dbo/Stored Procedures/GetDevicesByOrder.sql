-- =============================================
-- Author:		Shamailov Slavik
-- Create date: 06/03/2025
-- Description:	Get devices by order number
-- =============================================
CREATE PROCEDURE [dbo].[GetDevicesByOrder]
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

	SELECT	OrderNumber, PartDescription AS [Device type], DepartmentName AS [Main field], DeviceDescription AS [Secondary field], 
			SerialNumber AS [Device number], DeviceModel AS [Device model], MbaReportNumber
	FROM    dbo.Orders
	WHERE   (OrderNumber = TRIM(@OrderNumber))
	ORDER BY OrderNumber, MbaReportNumber

END
