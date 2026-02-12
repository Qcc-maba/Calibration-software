CREATE   PROCEDURE  [dbo].[GetAllMeasurementDevicesManufacturers]
AS
SELECT 
     OrdersDeviceManufacturerId as ID
	,OrdersDeviceManufacturerDescription as Name
FROM [dbo].[OrdersDeviceManufacturers]
WHERE [IsDeleted] = 0