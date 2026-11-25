/* QUOTED_IDENTIFIER / ANSI_NULLS ON, whatever client deploys this (sqlcmd defaults QUOTED_IDENTIFIER
   to OFF): the filtered unique index on dbo.CalibrationCycleMarkers needs them, and so does every
   procedure that writes the table, which keeps the settings it was created with. */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
    dbo.CalibrationCycleMarkers                                                            MBA-983
    ---------------------------------------------------------------------------------------------
    The markers a calibrator placed on one chamber cycle's graph, with the results each one gives.
    Until MBA-983 the markers lived only in the browser: after a reload a saved cycle had none, so
    nothing that depends on them - the per-type results on the Summary screen and in the report -
    could be shown again (Jira 38416).

    What a marker belongs to
    ------------------------
    One cycle, by the key of dbo.CalibrationCycles: (OrderDetailsItemId, CalibrationCycleStartDate).
    Cycles have no id. Changing a cycle's start time copies the cycle to the new key and soft-deletes
    the old row, so dbo.MoveCalibrationCycleMarkers carries the markers along in the same
    transaction, and dbo.DeleteCalibrationCycle retires them with the cycle.

    At most one live marker of each type per cycle (Nofar, 38474): the filtered unique index below.

    The marker types and their lines (Nofar, MBA-983 description and 38474)
    ------------------------------------------------------------------------
        Calibration    2 lines  results from line 1 to line 2
        Stabilization  2 lines  results from line 1 to line 2, plus PeakMode:
                                Overshoot = the highest reading, Undershoot = the lowest
        DoorOpening    3 lines  1 = event starts, 2 = event ends, 3 = chamber stable again;
                                results from line 2 to line 3 (the recovery)
        PowerFailure   3 lines  the same lines as DoorOpening; results from line 2 to line 3
        General        1 or 2   a visual mark only, no results
    The lines of a marker are strictly in time order. Across markers, the Stabilization end may be
    at the Calibration start but not after it; that rule needs two rows, so
    dbo.SaveCalibrationCycleMarkers checks it.

    Times are the station's wall-clock time, as dbo.CalibrationCycles stores the cycle's, to the
    millisecond: a marker sits on a logger sample, and samples come faster than once a second.

    Why the results are stored
    --------------------------
    The graph's readings are in the browser only while the session that read them is open. After a
    reload they are gone - the reason the cycle's point values are saved too (MBA-1008). So the app
    sends each marker's Min, Max and Average with it, calculated from the readings between its lines,
    and the Summary screen and the report print those. Duration is not stored: it is the difference
    between two of the stored times. The Secondary* results are the second measured value (RH) of a
    Temperature + RH cycle (MBA-800); NULL on a cycle that has one value.

    A save never updates a row: it soft-deletes the set it replaces and inserts the new one. Only
    dbo.MoveCalibrationCycleMarkers changes a live row, and only its CalibrationCycleStartDate.
*/
IF OBJECT_ID('dbo.CalibrationCycleMarkers', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CalibrationCycleMarkers
    (
        CalibrationCycleMarkerId  INT IDENTITY(1,1) NOT NULL,
        OrderDetailsItemId        INT               NOT NULL,
        CalibrationCycleStartDate DATETIME2(0)      NOT NULL,
        MarkerType                NVARCHAR(20)      NOT NULL,
        Time1                     DATETIME2(3)      NOT NULL,
        Time2                     DATETIME2(3)      NULL,
        Time3                     DATETIME2(3)      NULL,
        PeakMode                  NVARCHAR(10)      NULL,
        MinValue                  DECIMAL(18,6)     NULL,
        MaxValue                  DECIMAL(18,6)     NULL,
        AverageValue              DECIMAL(18,6)     NULL,
        SecondaryMinValue         DECIMAL(18,6)     NULL,
        SecondaryMaxValue         DECIMAL(18,6)     NULL,
        SecondaryAverageValue     DECIMAL(18,6)     NULL,
        IsDeleted                 BIT               NOT NULL
            CONSTRAINT DF_CalibrationCycleMarkers_IsDeleted DEFAULT (0),
        CreatedDate               DATETIME2(0)      NOT NULL
            CONSTRAINT DF_CalibrationCycleMarkers_CreatedDate DEFAULT (GETDATE()),
        CreatedByUserId           INT               NULL,
        UpdatedDate               DATETIME2(0)      NULL,
        UpdateUserID              INT               NULL,

        CONSTRAINT PK_CalibrationCycleMarkers PRIMARY KEY CLUSTERED (CalibrationCycleMarkerId),
        CONSTRAINT FK_CalibrationCycleMarkers_CalibrationCycles
            FOREIGN KEY (OrderDetailsItemId, CalibrationCycleStartDate)
            REFERENCES dbo.CalibrationCycles (OrderDetailsItemId, CalibrationCycleStartDate),
        CONSTRAINT CK_CalibrationCycleMarkers_MarkerType CHECK
            (MarkerType IN (N'Calibration', N'Stabilization', N'DoorOpening', N'PowerFailure', N'General')),
        /* how many lines each type has */
        CONSTRAINT CK_CalibrationCycleMarkers_Lines CHECK
            (   (MarkerType IN (N'Calibration', N'Stabilization') AND Time2 IS NOT NULL AND Time3 IS NULL)
             OR (MarkerType IN (N'DoorOpening', N'PowerFailure')  AND Time2 IS NOT NULL AND Time3 IS NOT NULL)
             OR (MarkerType = N'General'                          AND Time3 IS NULL)),
        CONSTRAINT CK_CalibrationCycleMarkers_TimeOrder CHECK
            ((Time2 IS NULL OR Time1 < Time2) AND (Time3 IS NULL OR Time2 < Time3)),
        CONSTRAINT CK_CalibrationCycleMarkers_PeakMode CHECK
            (   PeakMode IS NULL
             OR (MarkerType = N'Stabilization' AND PeakMode IN (N'Overshoot', N'Undershoot'))),
        /* a General marker is a visual mark only */
        CONSTRAINT CK_CalibrationCycleMarkers_GeneralHasNoResults CHECK
            (   MarkerType <> N'General'
             OR (    MinValue IS NULL AND MaxValue IS NULL AND AverageValue IS NULL
                 AND SecondaryMinValue IS NULL AND SecondaryMaxValue IS NULL AND SecondaryAverageValue IS NULL)),
        CONSTRAINT CK_CalibrationCycleMarkers_MinMax CHECK
            (    (MinValue IS NULL OR MaxValue IS NULL OR MinValue <= MaxValue)
             AND (SecondaryMinValue IS NULL OR SecondaryMaxValue IS NULL OR SecondaryMinValue <= SecondaryMaxValue))
    );
END
GO

/* one live marker of each type per cycle (Nofar, 38474) */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_CalibrationCycleMarkers_CycleType'
                                         AND object_id = OBJECT_ID('dbo.CalibrationCycleMarkers'))
CREATE UNIQUE NONCLUSTERED INDEX UX_CalibrationCycleMarkers_CycleType
    ON dbo.CalibrationCycleMarkers (OrderDetailsItemId, CalibrationCycleStartDate, MarkerType)
    WHERE IsDeleted = 0;
GO
