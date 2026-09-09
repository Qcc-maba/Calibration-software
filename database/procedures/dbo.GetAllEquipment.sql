/*
    dbo.GetAllEquipment
    ---------------------------------------------------------------------------------------------
    Original author: Eduard Kudlaiev, 02/04/2025
    All calibration equipment available for assignment - this is what fills the equipment and
    sensor pickers in the calibration wizard.

    2026-08-24 (MBA-902): the proc had no ORDER BY at all, so the picker listed devices in whatever
    order the join happened to produce - 21-131, 21-682, 21-528/10, 21-604, 21-697, 21-17 - which
    is unusable for finding a device by its number, and unstable between calls.

    Sorted on MabaID's numeric segments rather than as text, so 21-17 comes before 21-131 (plain
    text sort puts 21-131 first, because '1' sorts before '7'). Devices whose MabaID does not
    follow the nn-nnn shape sort last rather than being dropped.

    AassignedChannels came out of STRING_AGG in join order too, so a sensor holding 0,1,2,3,6,7
    could render as "3,0,7,1,6,2". Now numeric.

    No rows, filters or columns changed.
*/
CREATE OR ALTER PROCEDURE [dbo].[GetAllEquipment]
@MainCategoryId INT = NULL,
@CheckDate DATE = NULL,
@MainClassId INT = NULL
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
SELECT sr.SensorMeasurementDeviceId, STRING_AGG(sr.ChannelNumber,',') WITHIN GROUP (ORDER BY sr.ChannelNumber) as AassignedChannels
FROM [dbo].[ChannelsToSensorRelation] as sr
WHERE sr.IsDeleted = 0
GROUP BY sr.SensorMeasurementDeviceId
) as ach ON c.ID = ach.SensorMeasurementDeviceId
WHERE c.IsDeleted = 0  /*AND COALESCE(s.StatusDescriptionENG,'Available') = 'Available'*/ AND coh.MeasurementDeviceId IS NULL
AND (@MainCategoryId IS NULL OR c.[MainCategoryId]  = @MainCategoryId)
AND (@MainClassId IS NULL OR c.MainClassId  = @MainClassId)
-- MBA-902: numeric order on MabaID's two segments; anything not shaped nn-nnn sorts last
ORDER BY
	 IIF(TRY_CAST(LEFT(c.MabaID, CHARINDEX('-', c.MabaID + '-') - 1) AS INT) IS NULL, 1, 0),
	 TRY_CAST(LEFT(c.MabaID, CHARINDEX('-', c.MabaID + '-') - 1) AS INT),
	 TRY_CAST(LEFT(STUFF(c.MabaID, 1, CHARINDEX('-', c.MabaID + '-'), ''),
	               CHARINDEX('/', STUFF(c.MabaID, 1, CHARINDEX('-', c.MabaID + '-'), '') + '/') - 1) AS INT),
	 c.MabaID
