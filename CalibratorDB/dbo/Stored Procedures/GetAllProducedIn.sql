
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 08/06/2025
-- Description:	This SP return all device manufacturers
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-276
-- =============================================
CREATE   PROCEDURE [dbo].[GetAllProducedIn]
AS
BEGIN
	SELECT DISTINCT
	       mf.OrdersDeviceManufacturerId
		  ,mf.OrdersDeviceManufacturerName
		  ,mf.OrdersDeviceManufacturerDescription as ProducedIn
	  FROM [dbo].[OrdersDeviceManufacturers] as mf 
	  WHERE mf.[IsDeleted] = 0
END