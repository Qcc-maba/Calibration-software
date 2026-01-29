-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 29/01/2026
-- Description:	Get equipment assigned for order
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[GetEquipmentAssignedToOrder]
@OrderWorkPlanId INT,
@CarId INT = NULL,
@AssigmentStartDate DATE = NULL,
@AssigmentEndDate DATE = NULL
AS
SELECT c.[ID]
      ,CONCAT(COALESCE(c.[Description],'N/A'), ' ',c.MabaID) AS Title
	  ,c.[MainClassId]
	  ,c.[SubClassId]
	  ,c.[MainCategoryId] as [DepartmentId]
	  ,mdmc.[NameHebrew] as DeviceMainClass
	  ,coh.AssigmentDate	
	  ,coh.CarId
	  ,coh.OrderWorkPlanId
FROM [dbo].[MeasurementDevices] as c
JOIN [dbo].[MeasurementDevicesToOrderHeaders] as coh ON c.ID = coh.MeasurementDeviceId AND coh.IsDeleted = 0
LEFT JOIN [dbo].[MainCategories] as mmc ON c.[MainCategoryId] = mmc.ID
LEFT JOIN [dbo].[Statuses] as s ON c.MeasurementDeviceStatusId = s.StatusId
LEFT JOIN [dbo].[MeasurementDevicesMainClasses] as mc ON c.MainClassId = mc.Id
LEFT JOIN [dbo].[OrderWorkPlans] as op ON op.OrderWorkPlanId = coh.OrderWorkPlanId AND op.IsCancelled = 0  
LEFT JOIN [dbo].[MeasurementDevicesMainClasses] as mdmc ON c.MainClassId = mdmc.Id
WHERE coh.OrderWorkPlanId = @OrderWorkPlanId
AND (@CarId IS NULL OR coh.CarId = @CarId)
AND ( (@AssigmentStartDate IS NULL AND @AssigmentEndDate IS NULL) OR (coh.AssigmentDate >= @AssigmentStartDate AND coh.AssigmentDate <= @AssigmentEndDate))