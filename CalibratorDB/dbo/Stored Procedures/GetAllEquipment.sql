-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/04/2025
-- Description:	Get all calibration equipments
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[GetAllEquipment]
AS

SELECT c.[ID]
      ,c.[Description] AS Title
	  ,c.[MainClassId]
	  ,c.[SubClassId]
	  ,c.[DepartmentId]
      ,s.[StatusId]
	  ,s.[StatusDescriptionENG]	
	  ,s.[StatusDescriptionHEB]   
      -----------------------------
	  ,op.OrderNumber as OrderNumber
	  ,coh.OrderWorkPlanId as OrderId
	  ,c.ManufacturerId
FROM [dbo].[MeasurementDevices] as c
LEFT JOIN [dbo].[Statuses] as s ON c.MeasurementDeviceStatusId = s.StatusId
LEFT JOIN [dbo].[MeasurementDevicesToOrderHeaders] as coh ON c.ID = coh.MeasurementDeviceId AND coh.IsDeleted = 0
LEFT JOIN [dbo].[OrderWorkPlans] as op ON op.OrderWorkPlanId = coh.OrderWorkPlanId AND op.IsCancelled = 0
WHERE c.IsDeleted = 0 --AND s.StatusDescriptionENG = 'Available'