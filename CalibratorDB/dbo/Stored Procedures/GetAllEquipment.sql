
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/04/2025
-- Description:	Get all calibration equipments
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[GetAllEquipment]
@MainCategoryId INT = NULL,
@CheckDate DATE = NULL
AS

IF @CheckDate IS NULL SET @CheckDate = GETDATE()

SELECT c.[ID]
      ,CONCAT(COALESCE(c.[Description],'N/A'), ' ',c.MabaID) AS Title
	  ,c.[MainClassId]
	  ,c.[SubClassId]
	  ,c.[MainCategoryId] as [DepartmentId]
      ,s.[StatusId]
	  ,s.[StatusDescriptionENG]	
	  ,s.[StatusDescriptionHEB] 
	  ,mmc.MainCategoryName AS [MainCategory]
      -----------------------------
	  ,op.OrderNumber as OrderNumber
	  ,coh.OrderWorkPlanId as OrderId
	  ,c.Manufacturer
	  ,c.DisplayToCoordinator
FROM [dbo].[MeasurementDevices] as c
LEFT JOIN [dbo].[MainCategories] as mmc ON c.[MainCategoryId] = mmc.ID
LEFT JOIN [dbo].[Statuses] as s ON c.MeasurementDeviceStatusId = s.StatusId
LEFT JOIN [dbo].[MeasurementDevicesMainClasses] as mc ON c.MainClassId = mc.Id
LEFT JOIN [dbo].[MeasurementDevicesToOrderHeaders] as coh ON c.ID = coh.MeasurementDeviceId AND coh.IsDeleted = 0 AND coh.AssigmentDate = @CheckDate
LEFT JOIN [dbo].[OrderWorkPlans] as op ON op.OrderWorkPlanId = coh.OrderWorkPlanId AND op.IsCancelled = 0  
WHERE c.IsDeleted = 0  /*AND COALESCE(s.StatusDescriptionENG,'Available') = 'Available'*/ AND coh.MeasurementDeviceId IS NULL
AND (@MainCategoryId IS NULL OR c.[MainCategoryId]  = @MainCategoryId)