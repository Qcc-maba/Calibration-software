

-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 15/06/2025
-- Description:	Get all measurement devices manufacturers
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE  [dbo].[GetAllMeasurementDevicesManufacturers]
AS
SELECT 
     OrdersDeviceManufacturerId as ID
	,OrdersDeviceManufacturerDescription as Name
FROM [dbo].[OrdersDeviceManufacturers]
WHERE [IsDeleted] = 0