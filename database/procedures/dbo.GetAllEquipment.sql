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

    2026-11-26 (MBA-1045): @IncludeAssigned. The scheduling screen has to warn when a device is
    already booked on the day (a warning, not a block), but the default call drops every device
    that has any booking on @CheckDate, so a booked device never reaches the list and the screen
    cannot say where it is.

    @IncludeAssigned = 0 (the default) returns the same rows and values as before: only devices
    with no booking row on the date (a cancelled order's booking still hides the device),
    OrderNumber and OrderId always NULL. The additions are the BookedOrderNumbers and
    BookedOrderIds columns, NULL in this mode, and the booking lookups are skipped. The wizard's
    pickers and every other caller (they read columns by name) are unchanged.

    @IncludeAssigned = 1 also returns booked devices, still one row per device:
      - OrderId / OrderNumber: one booking holding the device that day (lowest order number; an
        order with no number sorts last), so the existing "taken by order X" display keeps working.
        OrderId is the "booked" signal: it is set whenever a live booking exists, even when that
        order has no OrderNumber.
      - BookedOrderIds: every order (OrderWorkPlanId) holding it that day, comma separated, sorted.
        More than one means the device is double-booked; the caller decides which is "the current
        order" by id.
      - BookedOrderNumbers: the same orders' numbers, for display (an order without a number is
        left out, so count orders with BookedOrderIds, not with this).
    Bookings on a cancelled order do not count as taken in this mode. The default mode still treats
    them as taken, as it always has (left as is so its output does not move). That is the only
    case where the two modes disagree: OrderWorkPlanId is NOT NULL with a trusted foreign key, so a
    booking row always has its order.
*/
CREATE OR ALTER PROCEDURE [dbo].[GetAllEquipment]
@MainCategoryId INT = NULL,
@CheckDate DATE = NULL,
@MainClassId INT = NULL,
@IncludeAssigned BIT = 0
AS

IF @CheckDate IS NULL SET @CheckDate = GETDATE()
IF @IncludeAssigned IS NULL SET @IncludeAssigned = 0

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
	  ,bk.OrderNumber as OrderNumber
	  ,bk.OrderWorkPlanId as OrderId
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
	  ,bkl.BookedOrderNumbers
	  ,bki.BookedOrderIds
FROM [dbo].[MeasurementDevices] as c
LEFT JOIN [dbo].[MainCategories] as mmc ON c.[MainCategoryId] = mmc.ID
LEFT JOIN [dbo].[Statuses] as s ON c.MeasurementDeviceStatusId = s.StatusId
LEFT JOIN [dbo].[MeasurementDevicesMainClasses] as mc ON c.MainClassId = mc.Id
LEFT JOIN [dbo].[MeasurementDevicesMainClasses] as mdmc ON c.MainClassId = mdmc.Id
-- MBA-1045: the first live booking (non-cancelled order) holding the device on the date.
-- Both lookups only run with @IncludeAssigned = 1; in the default mode they could only return NULL.
OUTER APPLY
(
SELECT TOP (1) NULLIF(LTRIM(RTRIM(op.OrderNumber)), '') AS OrderNumber, coh.OrderWorkPlanId
FROM [dbo].[MeasurementDevicesToOrderHeaders] as coh
JOIN [dbo].[OrderWorkPlans] as op ON op.OrderWorkPlanId = coh.OrderWorkPlanId AND op.IsCancelled = 0
WHERE @IncludeAssigned = 1 AND coh.MeasurementDeviceId = c.ID AND coh.IsDeleted = 0 AND coh.AssigmentDate = @CheckDate
ORDER BY IIF(NULLIF(LTRIM(RTRIM(op.OrderNumber)), '') IS NULL, 1, 0), LTRIM(RTRIM(op.OrderNumber)), coh.OrderWorkPlanId
) as bk
-- MBA-1045: every order holding it that day; more than one id = double-booked
OUTER APPLY
(
SELECT STRING_AGG(o.OrderNumber, ',') WITHIN GROUP (ORDER BY o.OrderNumber) AS BookedOrderNumbers
FROM
(
SELECT DISTINCT coh.OrderWorkPlanId, NULLIF(LTRIM(RTRIM(op.OrderNumber)), '') AS OrderNumber
FROM [dbo].[MeasurementDevicesToOrderHeaders] as coh
JOIN [dbo].[OrderWorkPlans] as op ON op.OrderWorkPlanId = coh.OrderWorkPlanId AND op.IsCancelled = 0
WHERE @IncludeAssigned = 1 AND coh.MeasurementDeviceId = c.ID AND coh.IsDeleted = 0 AND coh.AssigmentDate = @CheckDate
) as o
) as bkl
-- same orders by id (separate scope: two STRING_AGGs with different orderings cannot share one)
OUTER APPLY
(
SELECT STRING_AGG(CAST(o.OrderWorkPlanId AS VARCHAR(20)), ',') WITHIN GROUP (ORDER BY o.OrderWorkPlanId) AS BookedOrderIds
FROM
(
SELECT DISTINCT coh.OrderWorkPlanId
FROM [dbo].[MeasurementDevicesToOrderHeaders] as coh
JOIN [dbo].[OrderWorkPlans] as op ON op.OrderWorkPlanId = coh.OrderWorkPlanId AND op.IsCancelled = 0
WHERE @IncludeAssigned = 1 AND coh.MeasurementDeviceId = c.ID AND coh.IsDeleted = 0 AND coh.AssigmentDate = @CheckDate
) as o
) as bki
LEFT JOIN 
(
SELECT sr.SensorMeasurementDeviceId, STRING_AGG(sr.ChannelNumber,',') WITHIN GROUP (ORDER BY sr.ChannelNumber) as AassignedChannels
FROM [dbo].[ChannelsToSensorRelation] as sr
WHERE sr.IsDeleted = 0
GROUP BY sr.SensorMeasurementDeviceId
) as ach ON c.ID = ach.SensorMeasurementDeviceId
WHERE c.IsDeleted = 0  /*AND COALESCE(s.StatusDescriptionENG,'Available') = 'Available'*/
-- Default: drop a device with any live booking row on the date, cancelled order or not (unchanged)
AND (@IncludeAssigned = 1 OR NOT EXISTS (
	SELECT 1 FROM [dbo].[MeasurementDevicesToOrderHeaders] as coh
	WHERE coh.MeasurementDeviceId = c.ID AND coh.IsDeleted = 0 AND coh.AssigmentDate = @CheckDate))
AND (@MainCategoryId IS NULL OR c.[MainCategoryId]  = @MainCategoryId)
AND (@MainClassId IS NULL OR c.MainClassId  = @MainClassId)
-- MBA-902: numeric order on MabaID's two segments; anything not shaped nn-nnn sorts last
ORDER BY
	 IIF(TRY_CAST(LEFT(c.MabaID, CHARINDEX('-', c.MabaID + '-') - 1) AS INT) IS NULL, 1, 0),
	 TRY_CAST(LEFT(c.MabaID, CHARINDEX('-', c.MabaID + '-') - 1) AS INT),
	 TRY_CAST(LEFT(STUFF(c.MabaID, 1, CHARINDEX('-', c.MabaID + '-'), ''),
	               CHARINDEX('/', STUFF(c.MabaID, 1, CHARINDEX('-', c.MabaID + '-'), '') + '/') - 1) AS INT),
	 c.MabaID
