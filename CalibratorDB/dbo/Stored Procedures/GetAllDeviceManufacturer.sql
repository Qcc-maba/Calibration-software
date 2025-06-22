-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 15/05/2025
-- Description:	Get device manufacturer
-- JiraLink: 
-- =============================================
CREATE    PROCEDURE [dbo].[GetAllDeviceManufacturer]
AS
SELECT 
	odm.OrdersDeviceManufacturerId, 
	odm.OrdersDeviceManufacturerDescription as DeviceManufacturer
FROM [dbo].[OrdersDeviceManufacturers] as odm