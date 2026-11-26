/*
    Test-GetAllEquipment-IncludeAssigned.sql  (MBA-1045)
    Read-only. Run after deploying dbo.GetAllEquipment, on STAGE and PROD.

    For every date that has a live device booking (plus today), checks:
      1. default mode returns only devices with no booking row on the date, and every such device;
         OrderNumber, OrderId and BookedOrderNumbers are NULL.
      2. @IncludeAssigned = 1 returns every non-deleted device exactly once.
      3. in that mode a device is marked booked (OrderNumber not NULL) exactly when a booking on a
         non-cancelled order exists, OrderNumber is one of BookedOrderNumbers, and
         BookedOrderNumbers lists exactly the distinct non-cancelled orders.
    One result row per failed check; an empty result plus the final PASS row means every check held.
*/
SET NOCOUNT ON;

DECLARE @Results TABLE (CheckDate DATE, Failure NVARCHAR(400) COLLATE DATABASE_DEFAULT);
DECLARE @Dates TABLE (d DATE PRIMARY KEY);

INSERT INTO @Dates (d)
SELECT DISTINCT AssigmentDate FROM dbo.MeasurementDevicesToOrderHeaders WHERE IsDeleted = 0 AND AssigmentDate IS NOT NULL
UNION SELECT CAST(GETDATE() AS DATE);

CREATE TABLE #Out (
    ID NVARCHAR(MAX) COLLATE DATABASE_DEFAULT, Title NVARCHAR(MAX) COLLATE DATABASE_DEFAULT, MainClassId NVARCHAR(MAX) COLLATE DATABASE_DEFAULT, SubClassId NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
    DepartmentId NVARCHAR(MAX) COLLATE DATABASE_DEFAULT, StatusId NVARCHAR(MAX) COLLATE DATABASE_DEFAULT, StatusDescriptionENG NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
    StatusDescriptionHEB NVARCHAR(MAX) COLLATE DATABASE_DEFAULT, MainCategory NVARCHAR(MAX) COLLATE DATABASE_DEFAULT, OrderNumber NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
    OrderId NVARCHAR(MAX) COLLATE DATABASE_DEFAULT, Manufacturer NVARCHAR(MAX) COLLATE DATABASE_DEFAULT, DisplayToCoordinator NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
    MabaID NVARCHAR(MAX) COLLATE DATABASE_DEFAULT, CalibrationDate NVARCHAR(MAX) COLLATE DATABASE_DEFAULT, Channels NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
    AassignedChannels NVARCHAR(MAX) COLLATE DATABASE_DEFAULT, StabilityTime NVARCHAR(MAX) COLLATE DATABASE_DEFAULT, StabilitySize NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
    CalibrationDate2 NVARCHAR(MAX) COLLATE DATABASE_DEFAULT, NextCalibration NVARCHAR(MAX) COLLATE DATABASE_DEFAULT, DeviceMainClass NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
    BookedOrderNumbers NVARCHAR(MAX) COLLATE DATABASE_DEFAULT);

DECLARE @d DATE;
DECLARE dc CURSOR LOCAL FAST_FORWARD FOR SELECT d FROM @Dates;
OPEN dc;
FETCH NEXT FROM dc INTO @d;
WHILE @@FETCH_STATUS = 0
BEGIN
    -- 1. default mode
    TRUNCATE TABLE #Out;
    INSERT INTO #Out EXEC dbo.GetAllEquipment @CheckDate = @d;

    INSERT INTO @Results
    SELECT @d, CONCAT('default: unexpected device ', o.ID) FROM #Out AS o
    WHERE EXISTS (SELECT 1 FROM dbo.MeasurementDevicesToOrderHeaders AS coh
                  WHERE coh.MeasurementDeviceId = CAST(o.ID AS INT) AND coh.IsDeleted = 0 AND coh.AssigmentDate = @d)
       OR o.OrderNumber IS NOT NULL OR o.OrderId IS NOT NULL OR o.BookedOrderNumbers IS NOT NULL;

    INSERT INTO @Results
    SELECT @d, CONCAT('default: missing free device ', c.ID) FROM dbo.MeasurementDevices AS c
    WHERE c.IsDeleted = 0
      AND NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevicesToOrderHeaders AS coh
                      WHERE coh.MeasurementDeviceId = c.ID AND coh.IsDeleted = 0 AND coh.AssigmentDate = @d)
      AND NOT EXISTS (SELECT 1 FROM #Out AS o WHERE CAST(o.ID AS INT) = c.ID);

    -- 2. include mode: every device once
    TRUNCATE TABLE #Out;
    INSERT INTO #Out EXEC dbo.GetAllEquipment @CheckDate = @d, @IncludeAssigned = 1;

    INSERT INTO @Results
    SELECT @d, CONCAT('include: device ', ID, ' returned ', COUNT(*), ' times') FROM #Out GROUP BY ID HAVING COUNT(*) > 1;

    INSERT INTO @Results
    SELECT @d, CONCAT('include: missing device ', c.ID) FROM dbo.MeasurementDevices AS c
    WHERE c.IsDeleted = 0 AND NOT EXISTS (SELECT 1 FROM #Out AS o WHERE CAST(o.ID AS INT) = c.ID);

    -- 3. booking columns
    INSERT INTO @Results
    SELECT @d, CONCAT('include: device ', o.ID, ' booked=', IIF(o.OrderNumber IS NULL, 'no', 'yes'),
                      ' expected=', ISNULL(x.Expected, '(none)'), ' got=', ISNULL(o.BookedOrderNumbers, '(none)'))
    FROM #Out AS o
    OUTER APPLY (
        SELECT STRING_AGG(e.OrderNumber, ',') WITHIN GROUP (ORDER BY e.OrderNumber) AS Expected
        FROM (SELECT DISTINCT LTRIM(RTRIM(op.OrderNumber)) AS OrderNumber
              FROM dbo.MeasurementDevicesToOrderHeaders AS coh
              JOIN dbo.OrderWorkPlans AS op ON op.OrderWorkPlanId = coh.OrderWorkPlanId AND op.IsCancelled = 0
              WHERE coh.MeasurementDeviceId = CAST(o.ID AS INT) AND coh.IsDeleted = 0 AND coh.AssigmentDate = @d) AS e
    ) AS x
    WHERE ISNULL(o.BookedOrderNumbers, '') <> ISNULL(x.Expected, '')
       OR IIF(o.OrderNumber IS NULL, 0, 1) <> IIF(x.Expected IS NULL, 0, 1)
       OR (o.OrderNumber IS NOT NULL AND CHARINDEX(',' + o.OrderNumber + ',', ',' + o.BookedOrderNumbers + ',') = 0);

    FETCH NEXT FROM dc INTO @d;
END
CLOSE dc;
DEALLOCATE dc;

DROP TABLE #Out;

SELECT CheckDate, Failure FROM @Results
UNION ALL
SELECT NULL, CONCAT(IIF(EXISTS (SELECT 1 FROM @Results), 'FAIL', 'PASS'), ': ', (SELECT COUNT(*) FROM @Dates), ' dates checked')
ORDER BY CheckDate;
