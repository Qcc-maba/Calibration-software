
-- =============================================
-- Author:		Slavik Shamailov
-- Create date: 02/03/2025
-- Description:	Sync 'Orders' from amaba db
-- =============================================
CREATE PROCEDURE [dbo].[SyncOrdersTable]	
AS
BEGIN

DECLARE @UpdatedRows INT

	SET NOCOUNT ON;

	INSERT INTO Orders (
			   [OrderNumber]
			  ,[OpenDate]
			  ,[CustomerId]
			  ,[CustomerName]
			  ,[CustomerPhone]
			  ,[CustomerContactName]
			  ,[CustomerCity]
			  ,[CustomerAddress]
			  ,[CustomerContactPhone]
			  ,[MBAContactName]
			  ,[MBAContactPhone]
			  ,[MBAContactMobile]
			  ,[ClientRemarks]
			  ,[MbaReportNumber]
			  ,[SerialNumber]
			  ,[ManufacturerNumber]
			  ,[DeviceDescription]
			  ,[DeviceModel]
			  ,[CalibDate]
			  ,[NextCalibDate]
			  ,[CalibMonth]
			  ,[ReturnDate]
			  ,[PartName]
			  ,[PartDescription]
			  ,[IsInHouse]
			  ,[DepartmentCode]
			  ,[DepartmentName]
			  ,[CalibStatusCode]
			  ,[CalibStatus]
			  ,[DeviceManufacturer]
			  ,[Klita]	
	)	
		SELECT [OrderNumber]
			  ,[OpenDate]
			  ,[CustomerID]
			  ,[CustomerName]
			  ,[CustomerPhone]
			  ,[CustomerContactName]
			  ,[CustomerCity]
			  ,[CustomerAddress]
			  ,[CustomerContactPhone]
			  ,[MBAContactName]
			  ,[MBAContactPhone]
			  ,[MBAContactMobile]
			  ,[ClientRemarks]
			  ,[MbaReportNumber]
			  ,[Serial Number]
			  ,[Manufacturer Number]
			  ,[Device Description]
			  ,[Device model]
			  ,[CalibDate]
			  ,[NextCalibDate]
			  ,[CALIBMONTH]
			  ,[ReturnDate]
			  ,[Part Name]
			  ,[Part Description]
			  ,[InHouse]
			  ,[DepartmentCode]
			  ,[DepartmentName]
			  ,[StatusCode]
			  ,[CalibStatud]
			  ,[Device manufacturer]
			  ,[Klita]
		  FROM  [31.154.20.231].amaba.dbo.[vwGetOrders_WorkPlan_Full]
  
	WHERE  (NOT EXISTS
								 (SELECT        1 AS Expr1
								   FROM            dbo.Orders
								   WHERE        (OrderNumber =  vwGetOrders_WorkPlan_Full.OrderNumber))) AND ([OpenDate] >= DATEADD(DAY, - 365, GETDATE()))

	SET @UpdatedRows = @@ROWCOUNT
	PRINT 'Rows affected : ' + CAST(@UpdatedRows AS VARCHAR(10))

END

	
