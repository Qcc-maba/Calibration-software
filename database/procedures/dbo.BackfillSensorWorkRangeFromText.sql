/*
    dbo.BackfillSensorWorkRangeFromText                                                MBA-902
    ---------------------------------------------------------------------------------------------
    Fills WorkRangeMin/Max (and the second range, where the sensor has one) for the 37 sensors that
    carried their range only as free text in DeviceRange.

    kyulan.dbo.tblInstr is exhausted: dbo.ImportInstrumentWorkRangeFromKyulan already took every
    numeric range the registry had (85 of 152 sensors on STAGE). For the remaining 67 the registry
    holds nothing numeric at all, and 37 of them carry text like '0÷100%RH;-40÷60°C' instead.

    The numbers below were read off that text by a parser written against the 16 distinct formats
    that actually occur, and every row is listed here explicitly with its source text alongside, so
    the reading can be checked by eye rather than trusted. Nothing is parsed at run time.

    Three text formats were deliberately NOT converted - the RTL ones, '150-(80-)', '196-',
    '0-150'. In those the minus sign trails the number, so '150-(80-)' means -80..150 and a naive
    read gives 80..150 - the wrong sign on a lower bound, on a feature whose job is to flag
    out-of-range readings. Every row using them already has numbers from kyulan, so nothing is lost.

    UPDATE only, and only where WorkRangeMin and WorkRangeMax are both still NULL: a value that is
    already there came from an actual calibration and is better than anything read off a label.
    Idempotent - running it twice changes nothing the second time.

    Units: 13 = °C, 30 = %RH (dbo.MeasurementDeviceUnits).
    Run with @Apply = 0 first; it reports what would change and touches nothing.
*/
CREATE OR ALTER PROCEDURE dbo.BackfillSensorWorkRangeFromText
    @Apply BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Src TABLE
    (
        MabaID           NVARCHAR(100) COLLATE DATABASE_DEFAULT,
        WorkRangeMin     NUMERIC(18, 6),
        WorkRangeMax     NUMERIC(18, 6),
        WorkRangeUnitId  INT,
        WorkRangeMin2    NUMERIC(18, 6),
        WorkRangeMax2    NUMERIC(18, 6),
        WorkRangeUnitId2 INT,
        SourceText       NVARCHAR(400)
    );

    INSERT INTO @Src (MabaID, WorkRangeMin, WorkRangeMax, WorkRangeUnitId,
                      WorkRangeMin2, WorkRangeMax2, WorkRangeUnitId2, SourceText)
    VALUES
    (N'21-538', 0, 100, 30, NULL, NULL, NULL, N'0÷100%RH'),
    (N'21-539', 0, 100, 30, NULL, NULL, NULL, N'0÷100%RH'),
    (N'21-540', 0, 100, 30, NULL, NULL, NULL, N'0÷100%RH'),
    (N'21-561', -40, 60, 13, 0, 100, 30, N'0÷100%RH;-40÷60°C'),
    (N'21-562', -40, 60, 13, 0, 100, 30, N'0÷100%RH;-40÷60°C'),
    (N'21-563', -40, 60, 13, 0, 100, 30, N'0÷100%RH;-40÷60°C'),
    (N'21-564', -40, 60, 13, 0, 100, 30, N'0÷100%RH;-40÷60°C'),
    (N'21-565', -40, 60, 13, 0, 100, 30, N'0÷100%RH;-40÷60°C'),
    (N'21-570', -40, 60, 13, 0, 100, 30, N'-40÷60°C;0÷100RH'),
    (N'21-577/1', -120, 100, 13, NULL, NULL, NULL, N'(-120)-100°C'),
    (N'21-577/3', -120, 100, 13, NULL, NULL, NULL, N'(-120)-100°C'),
    (N'21-577/4', -120, 100, 13, NULL, NULL, NULL, N'(-120)-100°C'),
    (N'21-577/5', -120, 100, 13, NULL, NULL, NULL, N'(-120)-100°C'),
    (N'21-581', 0, 60, 13, 0, 100, 30, N'0÷60°C,0÷100%RH'),
    (N'21-604', -40, 60, 13, 0, 100, 30, N'-40÷60°C/0÷100%RH'),
    (N'21-619', -40, 60, 13, 0, 100, 30, N'-40÷60°C/0÷100%RH'),
    (N'21-620', -40, 60, 13, 0, 100, 30, N'-40÷60°C/0÷100%RH'),
    (N'21-654/2', -90, 100, 13, NULL, NULL, NULL, N'-90-100°c'),
    (N'21-712/1', -120, 100, 13, NULL, NULL, NULL, N'-120°c - 100°c'),
    (N'21-712/2', -120, 100, 13, NULL, NULL, NULL, N'-120°c - 100°c'),
    (N'21-712/3', -120, 100, 13, NULL, NULL, NULL, N'-120°c - 100°c'),
    (N'21-712/4', -120, 100, 13, NULL, NULL, NULL, N'-120°c - 100°c'),
    (N'21-712/5', -120, 100, 13, NULL, NULL, NULL, N'-120°c - 100°c'),
    (N'31-18', -40, 60, 13, 0, 100, 30, N'-40÷60°C  0-100%RH'),
    (N'31-22', -50, 100, 13, 0, 100, 30, N'-50-100C 0-100%RH'),
    (N'31-23', -50, 100, 13, 0, 100, 30, N'-50-100C 0-100%RH'),
    (N'31-3', -40, 60, 13, 0, 100, 30, N'0÷100% RH+ (-40)÷60°C'),
    (N'31-4', -40, 60, 13, 0, 100, 30, N'0÷100% RH+ (-40)÷60°C'),
    (N'31-5', -40, 60, 13, 0, 100, 30, N'0÷100% RH+ (-40)÷60°C'),
    (N'31-6', -40, 60, 13, 0, 100, 30, N'0-100%RH, (-40)-60C'),
    (N'31-67', 0, 100, 13, 0, 100, 30, N'0÷100%RH, 0÷100°c'),
    (N'31-68', 0, 100, 13, 0, 100, 30, N'0÷100%RH, 0÷100°c'),
    (N'31-69', 0, 100, 13, 0, 100, 30, N'0÷100%RH, 0÷100°c'),
    (N'31-7', 0, 60, 13, 0, 100, 30, N'0-60°C, 0-100% RH'),
    (N'31-70', -40, 60, 13, 0, 100, 30, N'-40÷60°C/0÷100%RH'),
    (N'31-71', -40, 60, 13, 0, 100, 30, N'-40÷60°C/0÷100%RH'),
    (N'31-8', 0, 60, 13, 0, 100, 30, N'0-60C,0-100%RH');

    /* The source text must still match what is in the row. If someone corrected DeviceRange since
       these numbers were read, this proc must not quietly apply a stale reading. */
    SELECT s.MabaID, m.ID AS MeasurementDeviceId, s.SourceText, m.DeviceRange,
           s.WorkRangeMin, s.WorkRangeMax, s.WorkRangeUnitId,
           s.WorkRangeMin2, s.WorkRangeMax2, s.WorkRangeUnitId2
    INTO #Apply
    FROM @Src AS s
    INNER JOIN dbo.MeasurementDevices AS m
            ON m.MabaID = s.MabaID
           AND m.IsDeleted = 0
    WHERE m.WorkRangeMin IS NULL
      AND m.WorkRangeMax IS NULL
      AND m.DeviceRange COLLATE DATABASE_DEFAULT = s.SourceText COLLATE DATABASE_DEFAULT;

    SELECT (SELECT COUNT(*) FROM @Src)   AS RowsInScript,
           (SELECT COUNT(*) FROM #Apply) AS RowsToUpdate,
           (SELECT COUNT(*) FROM #Apply WHERE WorkRangeMin2 IS NOT NULL) AS WithSecondRange,
           (SELECT COUNT(*) FROM @Src s WHERE NOT EXISTS
                (SELECT 1 FROM #Apply a WHERE a.MabaID = s.MabaID)) AS SkippedAlreadySetOrChanged;

    IF @Apply = 1
    BEGIN
        UPDATE m
        SET WorkRangeMin     = a.WorkRangeMin,
            WorkRangeMax     = a.WorkRangeMax,
            WorkRangeUnitId  = a.WorkRangeUnitId,
            WorkRangeMin2    = a.WorkRangeMin2,
            WorkRangeMax2    = a.WorkRangeMax2,
            WorkRangeUnitId2 = a.WorkRangeUnitId2,
            UpdateDate       = GETDATE()
        FROM dbo.MeasurementDevices AS m
        INNER JOIN #Apply AS a ON a.MeasurementDeviceId = m.ID;

        SELECT @@ROWCOUNT AS RowsUpdated;
    END
    ELSE
        SELECT MabaID, DeviceRange, WorkRangeMin, WorkRangeMax, WorkRangeUnitId,
               WorkRangeMin2, WorkRangeMax2, WorkRangeUnitId2
        FROM #Apply ORDER BY MabaID;
END
