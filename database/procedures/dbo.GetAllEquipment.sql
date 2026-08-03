-- =============================================
-- Proc:        dbo.GetAllEquipment
-- Jira:        MBA-157 (parent MBA-89 "Assign equipment to the order")
-- Author:      Eduard Kudlaiev (original, 02/04/2025) — re-authored as reviewable file for MBA-157
-- Description: Returns the list of calibration equipment (measurement devices / masters) that
--              is AVAILABLE to be assigned to an order. Backs the "Assign equipment to order"
--              dialog: tRPC `equipment.getGroupedByCategory` -> `EXEC dbo.GetAllEquipment @CheckDate`
--              (also reused by `orders`, `cars.getAllEquipment`, and `sensors` routers, the last
--              filtering with @MainClassId = 2 / 5).
--
--              Only equipment that is NOT already assigned to any order on @CheckDate is returned
--              (LEFT JOIN to MeasurementDevicesToOrderHeaders on that date, keep rows where the
--              join misses -> coh.MeasurementDeviceId IS NULL). Deleted devices are excluded.
--
-- Params:
--   @MainCategoryId INT = NULL  -- optional filter on MeasurementDevices.MainCategoryId (department)
--   @CheckDate      DATE = NULL -- assignment date to check availability against; defaults to today
--   @MainClassId    INT = NULL  -- optional filter on MeasurementDevices.MainClassId (device family)
--
-- Output columns consumed by the FE (see raw-equipment.ts TRawEquipment):
--   ID, Title, StatusId, StatusDescriptionENG, StatusDescriptionHEB, MainCategory,
--   OrderNumber, Manufacturer, DisplayToCoordinator
--   (plus MainClassId, SubClassId, DepartmentId, OrderId, MabaID, CalibrationDate, Channels,
--    AassignedChannels, StabilityTime, StabilitySize, NextCalibration, DeviceMainClass used
--    elsewhere / reserved). The FE maps missing SecondaryCategory / CalibratorId to null.
--
-- NOTE for review: logic is preserved verbatim from the live OBJECT_DEFINITION; this file only
--   wraps it as CREATE OR ALTER and adds the header. See open questions in the task report.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetAllEquipment]
    @MainCategoryId INT = NULL,
    @CheckDate      DATE = NULL,
    @MainClassId    INT = NULL
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
      ,c.[MabaID]
      ,c.[CalibrationDate]
      ,c.[Channels]
      ,ach.AassignedChannels
      ,c.[StabilityTime]
      ,c.[StabilitySize]
      ,c.[CalibrationDate]
      ,c.[NextCalibration]
      ,mdmc.[NameHebrew] as DeviceMainClass
FROM [dbo].[MeasurementDevices] as c
LEFT JOIN [dbo].[MainCategories] as mmc ON c.[MainCategoryId] = mmc.ID
LEFT JOIN [dbo].[Statuses] as s ON c.MeasurementDeviceStatusId = s.StatusId
LEFT JOIN [dbo].[MeasurementDevicesMainClasses] as mc ON c.MainClassId = mc.Id
LEFT JOIN [dbo].[MeasurementDevicesToOrderHeaders] as coh ON c.ID = coh.MeasurementDeviceId AND coh.IsDeleted = 0 AND coh.AssigmentDate = @CheckDate
LEFT JOIN [dbo].[OrderWorkPlans] as op ON op.OrderWorkPlanId = coh.OrderWorkPlanId AND op.IsCancelled = 0
LEFT JOIN [dbo].[MeasurementDevicesMainClasses] as mdmc ON c.MainClassId = mdmc.Id
LEFT JOIN
(
SELECT sr.SensorMeasurementDeviceId, STRING_AGG(sr.ChannelNumber,',') as AassignedChannels
FROM [dbo].[ChannelsToSensorRelation] as sr
WHERE sr.IsDeleted = 0
GROUP BY sr.SensorMeasurementDeviceId
) as ach ON c.ID = ach.SensorMeasurementDeviceId
WHERE c.IsDeleted = 0  /*AND COALESCE(s.StatusDescriptionENG,'Available') = 'Available'*/ AND coh.MeasurementDeviceId IS NULL
AND (@MainCategoryId IS NULL OR c.[MainCategoryId]  = @MainCategoryId)
AND (@MainClassId IS NULL OR c.MainClassId  = @MainClassId)
GO
