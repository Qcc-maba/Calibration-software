CREATE   PROCEDURE [dbo].[SyncOrders]
/*
Created date: 12/03/2024
Description: This stored procedure will be sheduled based to synchonize data between amaba and calibrator.
			 As we not able define business key, it generated based on hash. In calibrator db we will have attributes which 
			 cover trancking modified date.
*/
AS
SET NOCOUNT ON;

DECLARE @dt DATETIME = GETDATE()

MERGE INTO [dbo].[Orders] AS dest
USING (
SELECT 
	   [OrderNumber]
      ,[OpenDate]
      ,[CustomerID] as [CustomerId]
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
      ,[Serial Number] as [SerialNumber]
      ,[Manufacturer Number] as [ManufacturerNumber]
      ,[Device Description] as [DeviceDescription]
      ,[Device model] as [DeviceModel]
      ,[CalibDate]
      ,[NextCalibDate]
      ,[CALIBMONTH] as [CalibMonth]
      ,[ReturnDate]
      ,[Part Name] as [PartName]
      ,[Part Description] as [PartDescription]
      ,[InHouse] as [IsInHouse]
      ,[DepartmentCode]
      ,[DepartmentName]
      ,[StatusCode] as [CalibStatusCode]
      ,[CalibStatud] as [CalibStatus]
      ,[Device manufacturer] as [DeviceManufacturer]
      ,[Klita]
      ,HASHBYTES('SHA2_256', CONCAT (
			COALESCE([OrderNumber], '')
			,COALESCE([OpenDate], '')
			,COALESCE([CustomerID], '')
			,COALESCE([CustomerName], '')
			,COALESCE([CustomerPhone], '')
			,COALESCE([CustomerContactName], '')
			,COALESCE([CustomerCity], '')
			,COALESCE([CustomerAddress], '')
			,COALESCE([CustomerContactPhone], '')
			,COALESCE([MBAContactName], '')
			,COALESCE([MBAContactPhone], '')
			,COALESCE([MBAContactMobile], '')
			,COALESCE([ClientRemarks], '')
			,COALESCE([MbaReportNumber], '')
			,COALESCE([Serial Number], '')
			,COALESCE([Manufacturer Number], '')
			,COALESCE([Device Description], '')
			,COALESCE([Device model], '')
			,COALESCE([CalibDate], '')
			,COALESCE([NextCalibDate], '')
			,COALESCE([CALIBMONTH], '')
			,COALESCE([ReturnDate], '')
			,COALESCE([Part Name], '')
			,COALESCE([Part Description], '')
			,COALESCE([InHouse], '')
			,COALESCE([DepartmentCode], '')
			,COALESCE([DepartmentName], '')
			,COALESCE([StatusCode], '')
			,COALESCE([CalibStatud], '')
			,COALESCE([Device manufacturer], '')
			,COALESCE([Klita], '')
			)) AS BkGen
FROM [31.168.173.93].[amaba].[dbo].[vwGetOrders_WorkPlan_Full]
WHERE OpenDate >= DATEADD(year,-4,GETDATE())
	) AS source
	ON dest.[BkGen] = source.[BkGen]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
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
			,[BkGen]
			,[ModifiedDate]
			)
		VALUES (
			source.[OrderNumber]
			,source.[OpenDate]
			,source.[CustomerId]
			,source.[CustomerName]
			,source.[CustomerPhone]
			,source.[CustomerContactName]
			,source.[CustomerCity]
			,source.[CustomerAddress]
			,source.[CustomerContactPhone]
			,source.[MBAContactName]
			,source.[MBAContactPhone]
			,source.[MBAContactMobile]
			,source.[ClientRemarks]
			,source.[MbaReportNumber]
			,source.[SerialNumber]
			,source.[ManufacturerNumber]
			,source.[DeviceDescription]
			,source.[DeviceModel]
			,source.[CalibDate]
			,source.[NextCalibDate]
			,source.[CalibMonth]
			,source.[ReturnDate]
			,source.[PartName]
			,source.[PartDescription]
			,source.[IsInHouse]
			,source.[DepartmentCode]
			,source.[DepartmentName]
			,source.[CalibStatusCode]
			,source.[CalibStatus]
			,source.[DeviceManufacturer]
			,source.[Klita]
			,source.[BkGen]
			,@dt
			)
WHEN NOT MATCHED BY SOURCE
THEN UPDATE
SET Deleted = 1,
[ModifiedDate] = @dt
;