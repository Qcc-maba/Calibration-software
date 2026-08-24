/*
    dbo.ImportInstrumentWorkRangeFromKyulan                                            MBA-475
    ---------------------------------------------------------------------------------------------
    Fills WorkRangeMin / WorkRangeMax / WorkRangeUnitId on dbo.MeasurementDevices from the legacy
    instrument registry, kyulan.dbo.tblInstr, over the Priority linked server.

    Why this exists: every one of the ~2,070 devices has a NULL work range, while kyulan holds a
    range for 2,436 instruments. The identity is already being carried across - only these three
    columns were never mapped. MBA-475 ("highlight a row when a value is more than 10C beyond the
    sensor range") cannot work until they are.

    This is an UPDATE of existing rows only. It never inserts, never deletes, and never overwrites
    a value that is already there - deliberately, because something other than the documented SSIS
    package is also writing to this table and I do not want two writers fighting. Rows the registry
    does not know about are left exactly as they are.

    Units map through MeasurementDeviceUnits.MeasurementDeviceUnitSourceId, which holds the kyulan
    tblUnits id. A range whose unit cannot be mapped is still imported - the numbers are worth
    having - but it is counted separately so the gap is visible rather than silent.

    Run with @Apply = 0 first: it reports what would change and touches nothing.

    Result sets:
      1. summary counters
      2. with @Apply = 0, the rows that would be filled (capped at 200 for readability)
*/
CREATE OR ALTER PROCEDURE dbo.ImportInstrumentWorkRangeFromKyulan
    @Apply BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    CREATE TABLE #Kyulan
    (
        MabaID       NVARCHAR(100) COLLATE DATABASE_DEFAULT,
        WorkRangeMin DECIMAL(18, 6),
        WorkRangeMax DECIMAL(18, 6),
        WorkRangeUnit INT
    );

    /* OPENQUERY so the scan runs on the remote server rather than dragging tblInstr across. */
    INSERT INTO #Kyulan (MabaID, WorkRangeMin, WorkRangeMax, WorkRangeUnit)
    SELECT MabaID COLLATE DATABASE_DEFAULT, WorkRangeMin, WorkRangeMax, WorkRangeUnit
    FROM OPENQUERY([31.168.173.93], '
        SELECT MabaID, WorkRangeMin, WorkRangeMax, WorkRangeUnit
        FROM kyulan.dbo.tblInstr
        WHERE MabaID IS NOT NULL
          AND WorkRangeMin IS NOT NULL
          AND WorkRangeMax IS NOT NULL');

    /* One row per MabaID: the registry has a few duplicates, and a silent double-match would make
       the UPDATE non-deterministic. Lowest range wins only so the choice is repeatable. */
    ;WITH Ranked AS
    (
        SELECT MabaID, WorkRangeMin, WorkRangeMax, WorkRangeUnit,
               ROW_NUMBER() OVER (PARTITION BY MabaID ORDER BY WorkRangeMin, WorkRangeMax) AS rn
        FROM #Kyulan
    )
    SELECT MabaID COLLATE DATABASE_DEFAULT AS MabaID, WorkRangeMin, WorkRangeMax, WorkRangeUnit
    INTO #Source
    FROM Ranked WHERE rn = 1;

    SELECT
        s.MabaID COLLATE DATABASE_DEFAULT AS MabaID,
        m.ID AS MeasurementDeviceId,
        s.WorkRangeMin,
        s.WorkRangeMax,
        u.MeasurementDeviceUnitId
    INTO #Candidates
    FROM #Source AS s
    INNER JOIN dbo.MeasurementDevices AS m
            ON m.MabaID = s.MabaID
           AND m.IsDeleted = 0
    LEFT JOIN dbo.MeasurementDeviceUnits AS u
           ON u.MeasurementDeviceUnitSourceId = s.WorkRangeUnit
          AND u.IsDeleted = 0
    WHERE m.WorkRangeMin IS NULL      /* never overwrite */
      AND m.WorkRangeMax IS NULL;

    IF @Apply = 1
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

                UPDATE m
                SET m.WorkRangeMin    = c.WorkRangeMin,
                    m.WorkRangeMax    = c.WorkRangeMax,
                    m.WorkRangeUnitId = COALESCE(c.MeasurementDeviceUnitId, m.WorkRangeUnitId),
                    m.UpdateDate      = SYSUTCDATETIME()
                FROM dbo.MeasurementDevices AS m
                INNER JOIN #Candidates AS c ON c.MeasurementDeviceId = m.ID;

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            THROW;
        END CATCH
    END

    SELECT
        CASE WHEN @Apply = 1 THEN 'applied' ELSE 'preview only' END      AS Mode,
        (SELECT COUNT(*) FROM #Source)                                    AS RegistryInstrumentsWithRange,
        (SELECT COUNT(*) FROM dbo.MeasurementDevices WHERE IsDeleted = 0) AS DevicesTotal,
        (SELECT COUNT(*) FROM #Candidates)                                AS Matched,
        (SELECT COUNT(*) FROM #Candidates WHERE MeasurementDeviceUnitId IS NULL) AS MatchedButUnitUnmapped,
        (SELECT COUNT(*) FROM dbo.MeasurementDevices WHERE IsDeleted = 0 AND WorkRangeMin IS NOT NULL) AS DevicesWithRangeNow;

    IF @Apply = 0
        SELECT TOP (200) * FROM #Candidates ORDER BY MabaID;

    DROP TABLE #Kyulan; DROP TABLE #Source; DROP TABLE #Candidates;
END
