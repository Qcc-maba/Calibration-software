
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
		  ,mf.OrdersDeviceManufacturerDescription as ProducedIn
		  ,ss.SourceName
	  FROM [dbo].[OrderWorkPlans] as wp
	  JOIN [dbo].[Source] as ss ON wp.[SourceId] = ss.[SourceId]
	  JOIN [dbo].[OrderDetails] as od ON od.[OrderWorkPlanId] = wp.[OrderWorkPlanId]
	  JOIN [dbo].[OrdersDeviceManufacturers] as mf ON od.OrdersDeviceManufacturerId = mf.OrdersDeviceManufacturerId
	  WHERE od.[IsDeleted] = 0 and wp.[IsCancelled] = 0
END