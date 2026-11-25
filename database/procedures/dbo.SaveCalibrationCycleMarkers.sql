/*
    dbo.SaveCalibrationCycleMarkers                                                        MBA-983
    ---------------------------------------------------------------------------------------------
    Saves one chamber cycle's markers as a whole, in one transaction: the set sent replaces the set
    saved. Markers are saved with the cycle so a reload or re-opening the order shows them again, and
    the per-type results on the Summary screen and in the report stay the same (Jira 38416, 38479).

    @OrderDetailsItemId + @CalibrationCycleStartDate  the cycle (the key of dbo.CalibrationCycles;
            cycles have no id). It must exist and be live, so a new cycle is saved first.

    @Markers  JSON array; [] clears the cycle's markers. One object per marker:
        {"Type": "Stabilization",
         "Time1": "2026-11-20T09:58:00.000", "Time2": "2026-11-20T10:00:00.000", "Time3": null,
         "PeakMode": "Overshoot",
         "Min": 19.8, "Max": 20.4, "Average": 20.1,
         "SecondaryMin": null, "SecondaryMax": null, "SecondaryAverage": null}
        Type      Calibration | Stabilization | DoorOpening | PowerFailure | General
        Time1-3   the lines, wall-clock time like the cycle's start; as many as the type has
                  (Calibration, Stabilization 2; DoorOpening, PowerFailure 3; General 1 or 2)
        PeakMode  Overshoot | Undershoot, Stabilization only; null = not chosen yet
        Min, Max, Average (+ Secondary* for the RH value of a Temperature + RH cycle)
                  the results the app calculated from the readings between the marker's lines.
                  A General marker has none. Optional: a marker placed where there are no readings
                  has none either.
        Absent keys read as null. Key names are checked exactly, so a misspelled key is refused
        rather than read as absent.

    Rules (Nofar, MBA-983 and 38474), refused with THROW 51000:
        - one marker of each type per cycle;
        - the type's number of lines, strictly in time order;
        - the Stabilization end may be at the Calibration start but not after it;
        - PeakMode only on Stabilization; no results on General; Min <= Max.
    Also refused: an unknown user, a cycle that does not exist or is deleted, malformed JSON.

    The report lock (dbo.SetCalibrationRemarksLock) is not checked, as it is not for the cycle's
    point values: the graph screen saves both the same way.

    @Apply  0 (default) writes nothing and returns the set as it would be saved; 1 saves.
    Saving the same set again writes nothing (Outcome NoChange).

    One result set: one row per marker - Outcome (WouldSave | Saved | NoChange), MarkerType,
    Time1, Time2, Time3, PeakMode and the six results. An empty set returns no rows.
*/
CREATE OR ALTER PROCEDURE dbo.SaveCalibrationCycleMarkers
    @LoggedInUserEmail         NVARCHAR(255),
    @OrderDetailsItemId        INT,
    @CalibrationCycleStartDate DATETIME2(0),
    @Markers                   NVARCHAR(MAX),
    @Apply                     BIT = 0
/*
EXEC dbo.SaveCalibrationCycleMarkers
    @LoggedInUserEmail = N'ezequiel_lo@mba.co.il', @OrderDetailsItemId = 3077,
    @CalibrationCycleStartDate = '2026-10-20 09:00:00',
    @Markers = N'[{"Type":"Calibration","Time1":"2026-10-20T10:00:00","Time2":"2026-10-20T10:30:00",
                   "Min":19.9,"Max":20.2,"Average":20.05}]',
    @Apply = 0
*/
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* TOP (1): dbo.Users.Email is not unique (see dbo.SaveCalibrationCycleSettings) */
    DECLARE @UserId INT = (SELECT TOP (1) ID FROM dbo.Users WHERE Email = @LoggedInUserEmail ORDER BY ID);

    IF @UserId IS NULL
        THROW 51000, 'Unknown user.', 1;
    IF @CalibrationCycleStartDate IS NULL
        THROW 51000, 'CalibrationCycleStartDate is needed.', 1;
    IF @Markers IS NULL OR ISJSON(@Markers) = 0 OR LEFT(LTRIM(@Markers), 1) <> N'['
        THROW 51000, 'Markers must be a JSON array.', 1;
    IF EXISTS (SELECT 1 FROM OPENJSON(@Markers) AS e WHERE e.[type] <> 5)
        THROW 51000, 'Every marker must be a JSON object.', 1;
    /* JSON paths are case-sensitive: a misspelled key would silently read as absent */
    IF EXISTS (SELECT 1 FROM OPENJSON(@Markers) AS e
               CROSS APPLY OPENJSON(e.[value]) AS k
               WHERE k.[key] COLLATE Latin1_General_100_BIN2
                     NOT IN (N'Type', N'Time1', N'Time2', N'Time3', N'PeakMode', N'Min', N'Max', N'Average',
                             N'SecondaryMin', N'SecondaryMax', N'SecondaryAverage'))
        THROW 51000, 'Unknown key in a marker: only Type, Time1-3, PeakMode, Min, Max, Average and Secondary* are read.', 1;

    /* ---- the set as sent ------------------------------------------------------------------- */
    DROP TABLE IF EXISTS #New;
    SELECT MarkerType            = NULLIF(LTRIM(RTRIM(j.MarkerType)), N'') COLLATE DATABASE_DEFAULT,
           j.Time1, j.Time2, j.Time3,
           PeakMode              = NULLIF(LTRIM(RTRIM(j.PeakMode)), N'') COLLATE DATABASE_DEFAULT,
           j.MinValue, j.MaxValue, j.AverageValue,
           j.SecondaryMinValue, j.SecondaryMaxValue, j.SecondaryAverageValue
    INTO #New
    FROM OPENJSON(@Markers) AS e
    CROSS APPLY OPENJSON(e.[value])
         WITH (MarkerType            NVARCHAR(20)  N'$.Type',
               Time1                 DATETIME2(3)  N'$.Time1',
               Time2                 DATETIME2(3)  N'$.Time2',
               Time3                 DATETIME2(3)  N'$.Time3',
               PeakMode              NVARCHAR(10)  N'$.PeakMode',
               MinValue              DECIMAL(18,6) N'$.Min',
               MaxValue              DECIMAL(18,6) N'$.Max',
               AverageValue          DECIMAL(18,6) N'$.Average',
               SecondaryMinValue     DECIMAL(18,6) N'$.SecondaryMin',
               SecondaryMaxValue     DECIMAL(18,6) N'$.SecondaryMax',
               SecondaryAverageValue DECIMAL(18,6) N'$.SecondaryAverage') AS j;

    /* compared in binary so that "calibration" is refused, not stored in another spelling */
    IF EXISTS (SELECT 1 FROM #New
               WHERE MarkerType IS NULL
                  OR MarkerType COLLATE Latin1_General_100_BIN2
                     NOT IN (N'Calibration', N'Stabilization', N'DoorOpening', N'PowerFailure', N'General'))
        THROW 51000, 'Type must be Calibration, Stabilization, DoorOpening, PowerFailure or General.', 1;
    IF EXISTS (SELECT 1 FROM #New GROUP BY MarkerType HAVING COUNT(*) > 1)
        THROW 51000, 'One marker of each type per cycle.', 1;
    IF EXISTS (SELECT 1 FROM #New WHERE Time1 IS NULL)
        THROW 51000, 'Every marker needs Time1.', 1;
    IF EXISTS (SELECT 1 FROM #New
               WHERE (MarkerType IN (N'Calibration', N'Stabilization') AND (Time2 IS NULL OR Time3 IS NOT NULL))
                  OR (MarkerType IN (N'DoorOpening', N'PowerFailure')  AND (Time2 IS NULL OR Time3 IS NULL))
                  OR (MarkerType = N'General'                          AND Time3 IS NOT NULL))
        THROW 51000, 'Wrong number of lines: Calibration and Stabilization have 2, DoorOpening and PowerFailure 3, General 1 or 2.', 1;
    IF EXISTS (SELECT 1 FROM #New WHERE Time1 >= Time2 OR Time2 >= Time3)
        THROW 51000, 'The lines of a marker must be in time order.', 1;
    IF EXISTS (SELECT 1 FROM #New
               WHERE PeakMode IS NOT NULL
                 AND (MarkerType <> N'Stabilization'
                      OR PeakMode COLLATE Latin1_General_100_BIN2 NOT IN (N'Overshoot', N'Undershoot')))
        THROW 51000, 'PeakMode is Overshoot or Undershoot, on the Stabilization marker only.', 1;
    IF EXISTS (SELECT 1 FROM #New
               WHERE MarkerType = N'General'
                 AND COALESCE(MinValue, MaxValue, AverageValue,
                              SecondaryMinValue, SecondaryMaxValue, SecondaryAverageValue) IS NOT NULL)
        THROW 51000, 'A General marker is a visual mark only: it has no results.', 1;
    IF EXISTS (SELECT 1 FROM #New WHERE MinValue > MaxValue OR SecondaryMinValue > SecondaryMaxValue)
        THROW 51000, 'Min must not be greater than Max.', 1;
    IF EXISTS (SELECT 1 FROM #New AS s
               JOIN #New AS c ON c.MarkerType = N'Calibration'
               WHERE s.MarkerType = N'Stabilization' AND s.Time2 > c.Time1)
        THROW 51000, 'The Stabilization marker must end at or before the Calibration marker starts.', 1;

    BEGIN TRANSACTION;

    /* holding the cycle row, so two saves of the same cycle cannot interleave */
    IF NOT EXISTS (SELECT 1 FROM dbo.CalibrationCycles WITH (UPDLOCK, HOLDLOCK)
                   WHERE OrderDetailsItemId = @OrderDetailsItemId
                     AND CalibrationCycleStartDate = @CalibrationCycleStartDate
                     AND IsDeleted = 0)
        THROW 51000, 'No live calibration cycle starts at that time on this line.', 1;

    DROP TABLE IF EXISTS #Old;
    SELECT m.CalibrationCycleMarkerId, m.MarkerType, m.Time1, m.Time2, m.Time3, m.PeakMode,
           m.MinValue, m.MaxValue, m.AverageValue,
           m.SecondaryMinValue, m.SecondaryMaxValue, m.SecondaryAverageValue
    INTO #Old
    FROM dbo.CalibrationCycleMarkers AS m WITH (UPDLOCK, HOLDLOCK)
    WHERE m.OrderDetailsItemId = @OrderDetailsItemId
      AND m.CalibrationCycleStartDate = @CalibrationCycleStartDate
      AND m.IsDeleted = 0;

    /* EXCEPT treats two NULLs as equal */
    DECLARE @NoChange BIT =
        CASE WHEN (SELECT COUNT(*) FROM #Old) = (SELECT COUNT(*) FROM #New)
              AND NOT EXISTS (SELECT MarkerType, Time1, Time2, Time3, PeakMode, MinValue, MaxValue, AverageValue,
                                     SecondaryMinValue, SecondaryMaxValue, SecondaryAverageValue
                              FROM #New
                              EXCEPT
                              SELECT MarkerType, Time1, Time2, Time3, PeakMode, MinValue, MaxValue, AverageValue,
                                     SecondaryMinValue, SecondaryMaxValue, SecondaryAverageValue
                              FROM #Old)
             THEN 1 ELSE 0 END;

    IF @Apply = 1 AND @NoChange = 0
    BEGIN
        UPDATE m
        SET IsDeleted = 1, UpdatedDate = GETDATE(), UpdateUserID = @UserId
        FROM dbo.CalibrationCycleMarkers AS m
        JOIN #Old AS o ON o.CalibrationCycleMarkerId = m.CalibrationCycleMarkerId;

        INSERT dbo.CalibrationCycleMarkers
              (OrderDetailsItemId, CalibrationCycleStartDate, MarkerType, Time1, Time2, Time3, PeakMode,
               MinValue, MaxValue, AverageValue, SecondaryMinValue, SecondaryMaxValue, SecondaryAverageValue,
               CreatedByUserId)
        SELECT @OrderDetailsItemId, @CalibrationCycleStartDate, n.MarkerType, n.Time1, n.Time2, n.Time3, n.PeakMode,
               n.MinValue, n.MaxValue, n.AverageValue, n.SecondaryMinValue, n.SecondaryMaxValue, n.SecondaryAverageValue,
               @UserId
        FROM #New AS n;
    END;

    COMMIT TRANSACTION;

    SELECT Outcome = CASE WHEN @NoChange = 1 THEN N'NoChange'
                          WHEN @Apply = 1    THEN N'Saved'
                          ELSE N'WouldSave' END,
           n.MarkerType, n.Time1, n.Time2, n.Time3, n.PeakMode,
           n.MinValue, n.MaxValue, n.AverageValue,
           n.SecondaryMinValue, n.SecondaryMaxValue, n.SecondaryAverageValue
    FROM #New AS n
    ORDER BY n.Time1;
END;
GO
