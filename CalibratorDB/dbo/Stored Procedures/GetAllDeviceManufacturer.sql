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
	odm.OrdersDeviceManufacturerDescription as DeviceManufacturer,
	ss.SourceName
FROM [dbo].[OrdersDeviceManufacturers] as odm
JOIN [dbo].[Source] as ss ON odm.SourceId = ss.SourceId