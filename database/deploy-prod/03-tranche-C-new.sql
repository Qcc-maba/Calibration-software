/*  TRANCHE C - procedures that do not exist on PROD at all.
    Lowest risk: nothing calls them yet. Deploy after tranche A.  */

/* ================= dbo.AddOrderNote ================= */
/*
    dbo.AddOrderNote                                                                    MBA-907
    ---------------------------------------------------------------------------------------------
    Adds one note to an order. Append-only: there is no edit, because a note is a record of what
    somebody thought at a moment and rewriting it destroys that. Correcting a note means writing
    another one; removing it means dbo.DeleteOrderNote, which soft-deletes.

    The order must exist and must not be cancelled - a note on a cancelled order would never be
    read by anyone.

    Blank text is refused rather than stored. An empty note is the kind of thing that fills a column
    with rows nobody can act on, and the screen already has to handle "no notes yet".

    Returns the new note as the list procedure would render it, so the caller can prepend it without
    a second round trip.
*/
CREATE OR ALTER PROCEDURE dbo.AddOrderNote
    @LoggedInUserEmail NVARCHAR(100),
    @OrderWorkPlanId   INT,
    @NoteText          NVARCHAR(2000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Text NVARCHAR(2000) = NULLIF(LTRIM(RTRIM(@NoteText)), N'');

    IF @Text IS NULL
        THROW 53001, 'A note cannot be empty.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.OrderWorkPlans
                   WHERE OrderWorkPlanId = @OrderWorkPlanId AND IsCancelled = 0)
        THROW 53002, 'No such order, or the order is cancelled.', 1;

    DECLARE @UserId INT;
    SELECT TOP (1) @UserId = u.ID FROM dbo.Users AS u
    WHERE LOWER(LTRIM(RTRIM(u.Email))) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)));

    INSERT INTO dbo.OrderNote (OrderWorkPlanId, NoteText, CreatedByUserId, CreatedByEmail)
    VALUES (@OrderWorkPlanId, @Text, @UserId, LOWER(LTRIM(RTRIM(@LoggedInUserEmail))));

    DECLARE @NoteId BIGINT = CAST(SCOPE_IDENTITY() AS BIGINT);

    SELECT n.OrderNoteId                                   AS id,
           n.OrderWorkPlanId                               AS orderId,
           n.NoteText                                      AS note,
           n.CreatedByEmail                                AS authorEmail,
           COALESCE(u.FirstName + N' ' + u.LastName, n.CreatedByEmail) AS authorName,
           CONVERT(VARCHAR(16), n.CreatedDate, 120)        AS createdAt
    FROM dbo.OrderNote AS n
    LEFT JOIN dbo.Users AS u ON u.ID = n.CreatedByUserId
    WHERE n.OrderNoteId = @NoteId;
END
GO

/* ================= dbo.AssignMeasurmentPointsToCalibrationCycle ================= */
CREATE OR ALTER PROCEDURE [dbo].[AssignMeasurmentPointsToCalibrationCycle]
    @LoggedInUserEmail NVARCHAR(200),
    @Data NVARCHAR(MAX)
-- =============================================
-- Author:		Kate Zashalovska
-- Create date: 03/06/2025
-- Description:	Populate table MeasurmentPointsToCalibrationCycles during calibration process setup
-- =============================================
AS
BEGIN 
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @LoggedInUserId INT 
        DECLARE @SourceId TINYINT

        SELECT 
         @LoggedInUserId  = d.UserId 
        ,@SourceId = d.SourceId
        FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

        DROP TABLE IF EXISTS #parsedData

        CREATE TABLE #parsedData
        (
            OrderDetailsItemId INT,
            CalibrationCycleStartDate DATETIME2(0),
            MeasurmentPointName NVARCHAR(100) COLLATE Latin1_General_100_CI_AI_SC,
            SensorMeasurementDeviceId INT,
            MeasurmentPointCoordX DECIMAL(10,4),
            MeasurmentPointCoordY DECIMAL(10,4),
            ChannelNumber INT,
            MasterValue DECIMAL(10,4),
            MasterValueUnitId INT,
            AdditionalValue DECIMAL(10,4),
            AdditionalValueUnitId INT,
            StabilityValue DECIMAL(10,4),
            UncertancyValue DECIMAL(10,4),
            MeasuredValue DECIMAL(10,4),
            MeasuredValueUnitId INT
        )

        INSERT #parsedData
        (
            OrderDetailsItemId,
            CalibrationCycleStartDate,
            MeasurmentPointName,
            SensorMeasurementDeviceId,
            MeasurmentPointCoordX,
            MeasurmentPointCoordY,
            ChannelNumber,
            MasterValue,
            MasterValueUnitId,
            AdditionalValue,
            AdditionalValueUnitId,
            StabilityValue,
            UncertancyValue,
            MeasuredValue,
            MeasuredValueUnitId
        )
        SELECT 
            d.OrderDetailsItemId,
            d.CalibrationCycleStartDate,
            c.MeasurmentPointName,
            c.SensorMeasurementDeviceId,
            c.MeasurmentPointCoordX,
            c.MeasurmentPointCoordY,
            c.ChannelNumber,
            c.MasterValue,
            c.MasterValueUnitId,
            c.AdditionalValue,
            c.AdditionalValueUnitId,
            c.StabilityValue,
            c.UncertancyValue,
            c.MeasuredValue,
            c.MeasuredValueUnitId
        FROM OPENJSON(@Data) 
        WITH (
            OrderDetailsItemId INT,
            CalibrationCycleStartDate DATETIME2(0),
            Points NVARCHAR(MAX) AS JSON
        ) AS d
        OUTER APPLY OPENJSON(d.Points)
        WITH (
            MeasurmentPointName NVARCHAR(100),
            MeasurmentPointCoordX DECIMAL(10,4),
            MeasurmentPointCoordY DECIMAL(10,4),
            SensorMeasurementDeviceId INT,
            ChannelNumber INT,
            MasterValue DECIMAL(10,4),
            MasterValueUnitId INT,
            AdditionalValue DECIMAL(10,4),
            AdditionalValueUnitId INT,
            StabilityValue DECIMAL(10,4),
            UncertancyValue DECIMAL(10,4),
            MeasuredValue DECIMAL(10,4),
            MeasuredValueUnitId INT
        ) AS c

        BEGIN TRANSACTION;

        /* Apply soft delete to data which no longer valid FOR THIS SPECIFIC CYCLE */
        UPDATE dest
        SET IsDeleted = 1, UpdatedDate = GETDATE()
        FROM [dbo].[MeasurmentPointsToCalibrationCycles] as dest 
        LEFT JOIN #parsedData as pd
            ON pd.OrderDetailsItemId = dest.OrderDetailsItemId
               AND pd.CalibrationCycleStartDate = dest.CalibrationCycleStartDate
               AND pd.SensorMeasurementDeviceId = dest.SensorMeasurementDeviceId
               AND pd.ChannelNumber = dest.ChannelNumber
        WHERE dest.IsDeleted = 0 
          AND pd.SensorMeasurementDeviceId IS NULL
          AND dest.OrderDetailsItemId IN (SELECT OrderDetailsItemId FROM #parsedData WHERE OrderDetailsItemId IS NOT NULL)
          AND dest.CalibrationCycleStartDate IN (SELECT CalibrationCycleStartDate FROM #parsedData WHERE CalibrationCycleStartDate IS NOT NULL)

        /* Insert new data or update existing FOR THIS SPECIFIC CYCLE */
        MERGE INTO [dbo].[MeasurmentPointsToCalibrationCycles] AS dest
        USING (
            SELECT
                d.OrderDetailsItemId,
                d.CalibrationCycleStartDate,
                d.SensorMeasurementDeviceId,
                d.MeasurmentPointName,
                d.MeasurmentPointCoordX,
                d.MeasurmentPointCoordY,
                d.ChannelNumber,
                d.MasterValue,
                d.MasterValueUnitId,
                d.AdditionalValue,
                d.AdditionalValueUnitId,
                d.StabilityValue,
                d.UncertancyValue,
                d.MeasuredValue,
                d.MeasuredValueUnitId
            FROM #parsedData as d
            WHERE d.OrderDetailsItemId IS NOT NULL 
              AND d.CalibrationCycleStartDate IS NOT NULL
              AND d.ChannelNumber IS NOT NULL 
              AND d.SensorMeasurementDeviceId IS NOT NULL
        ) AS source
        ON   dest.[OrderDetailsItemId] = source.[OrderDetailsItemId]
             AND dest.[CalibrationCycleStartDate] = source.[CalibrationCycleStartDate]
             AND dest.[SensorMeasurementDeviceId] = source.[SensorMeasurementDeviceId]
             AND dest.[ChannelNumber] = source.[ChannelNumber]
             AND dest.[IsDeleted] = 0
        WHEN MATCHED AND ( 
                   COALESCE(dest.[MeasurmentPointName],'') <> COALESCE(source.[MeasurmentPointName],'')
                OR COALESCE(dest.[MeasurmentPointCoordX],0) <> COALESCE(source.[MeasurmentPointCoordX],0)
                OR COALESCE(dest.[MeasurmentPointCoordY],0) <> COALESCE(source.[MeasurmentPointCoordY],0)
                OR COALESCE(dest.[MasterValue],0) <> COALESCE(source.[MasterValue],0)
                OR COALESCE(dest.[MasterValueUnitId],0) <> COALESCE(source.[MasterValueUnitId],0)
                OR COALESCE(dest.[AdditionalValue],0) <> COALESCE(source.[AdditionalValue],0)
                OR COALESCE(dest.[AdditionalValueUnitId],0) <> COALESCE(source.[AdditionalValueUnitId],0)
                OR COALESCE(dest.[StabilityValue],0) <> COALESCE(source.[StabilityValue],0)
                OR COALESCE(dest.[UncertancyValue],0) <> COALESCE(source.[UncertancyValue],0)
                OR COALESCE(dest.[MeasuredValue],0) <> COALESCE(source.[MeasuredValue],0)
                OR COALESCE(dest.[MeasuredValueUnitId],0) <> COALESCE(source.[MeasuredValueUnitId],0)
        )
        THEN
            UPDATE
            SET  dest.[MeasurmentPointName] = source.[MeasurmentPointName]
                ,dest.[MeasurmentPointCoordX] = source.[MeasurmentPointCoordX]
                ,dest.[MeasurmentPointCoordY] = source.[MeasurmentPointCoordY]
                ,dest.[UpdatedDate] = GETDATE()
                ,dest.[UpdateUserID] = @LoggedInUserId
                ,dest.[MasterValue] = source.[MasterValue]
                ,dest.[MasterValueUnitId] = source.[MasterValueUnitId]
                ,dest.[AdditionalValue] = source.[AdditionalValue]
                ,dest.[AdditionalValueUnitId] = source.[AdditionalValueUnitId]
                ,dest.[StabilityValue] = source.[StabilityValue]
                ,dest.[UncertancyValue] = source.[UncertancyValue]
                ,dest.[MeasuredValue] = source.[MeasuredValue]
                ,dest.[MeasuredValueUnitId] = source.[MeasuredValueUnitId]
        WHEN NOT MATCHED BY TARGET
        THEN
            INSERT (
                  [OrderDetailsItemId],
                  [CalibrationCycleStartDate],
                  [SensorMeasurementDeviceId],
                  [MeasurmentPointName],
                  [MeasurmentPointCoordX],
                  [MeasurmentPointCoordY],
                  [ChannelNumber],
                  [UpdateUserID],
                  [MasterValue],
                  [MasterValueUnitId],
                  [AdditionalValue],
                  [AdditionalValueUnitId],
                  [StabilityValue],
                  [UncertancyValue],
                  [MeasuredValue],
                  [MeasuredValueUnitId]
            )
            VALUES (
                 source.[OrderDetailsItemId]
                ,source.[CalibrationCycleStartDate]
                ,source.[SensorMeasurementDeviceId]
                ,source.[MeasurmentPointName]
                ,source.[MeasurmentPointCoordX]
                ,source.[MeasurmentPointCoordY]
                ,source.[ChannelNumber]
                ,@LoggedInUserId
                ,source.[MasterValue]
                ,source.[MasterValueUnitId]
                ,source.[AdditionalValue]
                ,source.[AdditionalValueUnitId]
                ,source.[StabilityValue]
                ,source.[UncertancyValue]
                ,source.[MeasuredValue]
                ,source.[MeasuredValueUnitId]
            );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ================= dbo.AssignMeasurmentPointsToOrderDetailsItemsV2 ================= */
CREATE OR ALTER PROCEDURE [dbo].[AssignMeasurmentPointsToOrderDetailsItemsV2]
@LoggedInUserEmail NVARCHAR(255),
@Data NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LoggedInUserId INT;
    SELECT @LoggedInUserId = ID FROM [dbo].[Users] WHERE Email = @LoggedInUserEmail;

    IF OBJECT_ID('tempdb..#parsedData') IS NOT NULL DROP TABLE #parsedData;

    SELECT 
        d.OrderDetailsItemId,
        c.MeasurmentPointsToOrderDetailsItemId,
        c.MeasurmentPointName,
        c.MeasurmentPointCoordX,
        c.MeasurmentPointCoordY,
        ISNULL(c.SensorMeasurementDeviceId, 843) AS SensorMeasurementDeviceId,
        c.ChannelNumber,
        c.MasterValue,
        c.MasterValueUnitId,
        c.AdditionalValue,
        c.AdditionalValueUnitId,
        c.StabilityValue,
        c.UncertancyValue,
        c.MeasuredValue,
        c.MeasuredValueUnitId,
        c.SerialNumber,  -- UUT Serial Number
        c.MbaReportNumber,
        c.Tolerance,
        c.NominalValue
    INTO #parsedData
    FROM OPENJSON(@Data) 
    WITH (
        OrderDetailsItemId INT,
        Points NVARCHAR(MAX) AS JSON
    ) AS d
    OUTER APPLY OPENJSON(d.Points)
    WITH (
        MeasurmentPointsToOrderDetailsItemId INT,
        MeasurmentPointName NVARCHAR(100),
        MeasurmentPointCoordX DECIMAL(10,4),
        MeasurmentPointCoordY DECIMAL(10,4),
        SensorMeasurementDeviceId INT,
        ChannelNumber INT,
        MasterValue DECIMAL(10,4),
        MasterValueUnitId INT,
        AdditionalValue DECIMAL(10,4),
        AdditionalValueUnitId INT,
        StabilityValue DECIMAL(10,4),
        UncertancyValue DECIMAL(10,4),
        MeasuredValue DECIMAL(10,4),
        MeasuredValueUnitId INT,
        SerialNumber NVARCHAR(100),
        MbaReportNumber NVARCHAR(100),
        Tolerance DECIMAL(18,6),
        NominalValue DECIMAL(18,6)
    ) AS c;

    /* 1. UPDATE existing measurement points */
    UPDATE dest
    SET  dest.ChannelNumber             = src.ChannelNumber
        ,dest.SensorMeasurementDeviceId = src.SensorMeasurementDeviceId
        ,dest.MasterValue               = src.MasterValue
        ,dest.MasterValueUnitId         = src.MasterValueUnitId
        ,dest.AdditionalValue           = src.AdditionalValue
        ,dest.AdditionalValueUnitId     = src.AdditionalValueUnitId
        ,dest.StabilityValue            = src.StabilityValue
        ,dest.UncertancyValue           = src.UncertancyValue
        ,dest.MeasuredValue             = src.MeasuredValue
        ,dest.MeasuredValueUnitId       = src.MeasuredValueUnitId
        ,dest.SerialNumber              = src.SerialNumber
        ,dest.MbaReportNumber           = src.MbaReportNumber
        ,dest.Tolerance                 = src.Tolerance
        ,dest.NominalValue              = src.NominalValue
        ,dest.UpdatedDate               = GETDATE()
        ,dest.UpdateUserID              = @LoggedInUserId
    FROM [dbo].[MeasurmentPointsToOrderDetailsItems] dest
    JOIN #parsedData src
        ON dest.MeasurmentPointsToOrderDetailsItemId = src.MeasurmentPointsToOrderDetailsItemId
    WHERE dest.IsDeleted = 0
      AND src.MeasurmentPointsToOrderDetailsItemId IS NOT NULL;

    /* 2. INSERT new rows */
    INSERT INTO [dbo].[MeasurmentPointsToOrderDetailsItems] (
        OrderDetailsItemId, SensorMeasurementDeviceId, MeasurmentPointName,
        MeasurmentPointCoordX, MeasurmentPointCoordY, ChannelNumber, UpdateUserID,
        MasterValue, MasterValueUnitId, AdditionalValue, AdditionalValueUnitId,
        StabilityValue, UncertancyValue, MeasuredValue, MeasuredValueUnitId,
        SerialNumber, MbaReportNumber, Tolerance, NominalValue
    )
    SELECT 
        src.OrderDetailsItemId, src.SensorMeasurementDeviceId, src.MeasurmentPointName,
        src.MeasurmentPointCoordX, src.MeasurmentPointCoordY, src.ChannelNumber, @LoggedInUserId,
        src.MasterValue, src.MasterValueUnitId, src.AdditionalValue, src.AdditionalValueUnitId,
        src.StabilityValue, src.UncertancyValue, src.MeasuredValue, src.MeasuredValueUnitId,
        src.SerialNumber, src.MbaReportNumber, src.Tolerance, src.NominalValue
    FROM #parsedData src
    LEFT JOIN [dbo].[MeasurmentPointsToOrderDetailsItems] dest
        ON dest.MeasurmentPointsToOrderDetailsItemId = src.MeasurmentPointsToOrderDetailsItemId
        AND dest.IsDeleted = 0
    WHERE dest.MeasurmentPointsToOrderDetailsItemId IS NULL
      AND src.OrderDetailsItemId IS NOT NULL
      AND src.ChannelNumber IS NOT NULL;

    /* 3. UPDATE SerialNumber and MbaReportNumber in OrderDetailsItems -- NEW (as a backup fallback) */
    UPDATE odi
    SET odi.SerialNumber = COALESCE(pd.SerialNumber, odi.SerialNumber),
        odi.MbaReportNumber = COALESCE(pd.MbaReportNumber, odi.MbaReportNumber)
    FROM [dbo].[OrderDetailsItems] odi
    JOIN (
        SELECT DISTINCT OrderDetailsItemId, 
                        MIN(NULLIF(SerialNumber, '')) AS SerialNumber,
                        MIN(NULLIF(MbaReportNumber, '')) AS MbaReportNumber
        FROM #parsedData
        GROUP BY OrderDetailsItemId
    ) pd ON odi.OrderDetailsItemId = pd.OrderDetailsItemId;

END
GO

/* ================= dbo.BackfillMeasurementPointNames ================= */
/*
    dbo.BackfillMeasurementPointNames                                                   MBA-902
    ---------------------------------------------------------------------------------------------
    Names the measurement points that were saved without one.

    220 of the 366 saved points carry MeasurmentPointName = ''. The column is NOT NULL, so a blank
    name was stored rather than refused, and the chamber diagram draws each of them as a circle with
    nothing in it - which is what "why am I seeing an empty circle" is.

    AssignMeasurmentPointsToOrderDetailsItems now fills a blank name in as the next free T number,
    so no new ones appear. This names the ones already stored.

    Numbering follows the convention the named points already use, T1..T11, and continues from the
    highest T number that order item already holds, so an item with T1..T3 named and two blanks gets
    T4 and T5 rather than a collision. Within an item, blanks are numbered by channel and then by
    position, so the numbering is stable and repeatable rather than dependent on row order.

    Touches only rows whose name is blank. Idempotent - the second run finds nothing.

    Run with @Apply = 0 first: it reports what would be named and touches nothing.
*/
CREATE OR ALTER PROCEDURE dbo.BackfillMeasurementPointNames
    @Apply BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SELECT mp.OrderDetailsItemId,
           ISNULL(MAX(TRY_CAST(SUBSTRING(mp.MeasurmentPointName, 2, 10) AS INT)), 0) AS MaxUsed
    INTO #Base
    FROM dbo.MeasurmentPointsToOrderDetailsItems AS mp
    WHERE mp.IsDeleted = 0 AND mp.MeasurmentPointName LIKE 'T[0-9]%'
    GROUP BY mp.OrderDetailsItemId;

    SELECT mp.MeasurmentPointsToOrderDetailsItemId AS PointId,
           mp.OrderDetailsItemId,
           mp.ChannelNumber,
           'T' + CAST(ISNULL(b.MaxUsed, 0)
                      + ROW_NUMBER() OVER (PARTITION BY mp.OrderDetailsItemId
                                           ORDER BY mp.ChannelNumber,
                                                    mp.MeasurmentPointCoordX,
                                                    mp.MeasurmentPointCoordY)
                      AS NVARCHAR(10)) AS NewName
    INTO #Apply
    FROM dbo.MeasurmentPointsToOrderDetailsItems AS mp
    LEFT JOIN #Base AS b ON b.OrderDetailsItemId = mp.OrderDetailsItemId
    WHERE mp.IsDeleted = 0
      AND LTRIM(RTRIM(ISNULL(mp.MeasurmentPointName, N''))) = N'';

    SELECT COUNT(*)                                  AS WouldName,
           COUNT(DISTINCT OrderDetailsItemId)        AS AcrossOrderItems
    FROM #Apply;

    IF @Apply = 1
    BEGIN
        UPDATE mp
        SET MeasurmentPointName = a.NewName,
            UpdatedDate         = GETDATE()
        FROM dbo.MeasurmentPointsToOrderDetailsItems AS mp
        INNER JOIN #Apply AS a ON a.PointId = mp.MeasurmentPointsToOrderDetailsItemId;

        SELECT @@ROWCOUNT AS RowsNamed;
    END
    ELSE
        SELECT TOP (50) OrderDetailsItemId, ChannelNumber, NewName
        FROM #Apply ORDER BY OrderDetailsItemId, NewName;
END
GO

/* ================= dbo.BackfillSensorWorkRangeFromText ================= */
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
GO

/* ================= dbo.ClassifyUnclassifiedMeasurementDevices ================= */
/*
    dbo.ClassifyUnclassifiedMeasurementDevices                                         MBA-902
    ---------------------------------------------------------------------------------------------
    Sets MainClassId on measurement devices that never had one.

    1,828 of the 2,032 active devices carry MainClassId = NULL, so every picker that filters by
    device class silently offered a fraction of the fleet - 31-21 ("מד חום ספרתי עם רגש") looked
    like a missing device when it was only a missing classification.

    Two rules, both approved explicitly, both read off the Hebrew description:
        contains אוגר or לוגר  -> 7  Data logger   (419 devices)
        contains רגש           -> 2  Sensor         (68 devices)

    Logger is tested FIRST and wins on its own. Nine devices read 'אוגר נתונים לטמפ' ולחות עם רגש'
    - a data logger that has a sensor in it - and they are loggers, not sensors. That is why the
    counts come out 419 + 68 and not 419 + 77.

    UPDATE only, and only where MainClassId IS NULL. It never reclassifies a device that somebody
    already classified, so it is safe to re-run and cannot undo a manual correction.

    Deliberately NOT applied to the other 1,341 unclassified devices. Their descriptions carry no
    keyword that maps to a class with any confidence, and guessing a device class wrong is worse
    than leaving it blank - the wrong guess puts a device in a picker where a calibrator may
    actually select it. Those need the reviewed spreadsheet pass.

    Run with @Apply = 0 first: it reports what would change and touches nothing.
*/
CREATE OR ALTER PROCEDURE dbo.ClassifyUnclassifiedMeasurementDevices
    @Apply BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @DataLogger INT = 7, @Sensor INT = 2;

    SELECT md.ID AS MeasurementDeviceId, md.MabaID, md.Description, md.Connection,
           CASE
               WHEN md.Description LIKE N'%אוגר%' OR md.Description LIKE N'%לוגר%' THEN @DataLogger
               WHEN md.Description LIKE N'%רגש%'                                   THEN @Sensor
           END AS NewMainClassId
    INTO #Apply
    FROM dbo.MeasurementDevices AS md
    WHERE md.IsDeleted = 0
      AND md.MainClassId IS NULL
      AND (md.Description LIKE N'%אוגר%' OR md.Description LIKE N'%לוגר%' OR md.Description LIKE N'%רגש%');

    SELECT c.Id AS MainClassId, c.NameEnglish, c.NameHebrew,
           COUNT(a.MeasurementDeviceId) AS WouldClassify,
           (SELECT COUNT(*) FROM dbo.MeasurementDevices m
             WHERE m.IsDeleted = 0 AND m.MainClassId = c.Id) AS ClassifiedAlready
    FROM dbo.MeasurementDevicesMainClasses AS c
    LEFT JOIN #Apply AS a ON a.NewMainClassId = c.Id
    WHERE c.Id IN (@DataLogger, @Sensor)
    GROUP BY c.Id, c.NameEnglish, c.NameHebrew;

    IF @Apply = 1
    BEGIN
        UPDATE md
        SET MainClassId = a.NewMainClassId,
            UpdateDate  = GETDATE()
        FROM dbo.MeasurementDevices AS md
        INNER JOIN #Apply AS a ON a.MeasurementDeviceId = md.ID
        WHERE md.MainClassId IS NULL;

        SELECT @@ROWCOUNT AS RowsUpdated;
    END
    ELSE
        SELECT MabaID, Description, Connection, NewMainClassId FROM #Apply ORDER BY NewMainClassId, MabaID;
END
GO

/* ================= dbo.CreateCustomerPortalRequest ================= */
/*
    dbo.CreateCustomerPortalRequest                                                     MBA-903
    ---------------------------------------------------------------------------------------------
    Records one request a customer submits from the portal. Backs seven popups in Figma node
    6768-597 that previously had no procedure to write to.

    Which parameters each type uses - everything else stays NULL:

      ReportUpdate             @MbaReportNumber or @ItemIds, @Reason
                               (single popup and the multi-report popup are the same call; the
                                multi one just passes several ids in @ItemIds)
      Shipment                 @ShippingMethod, @ShippingDocument, @RequestedDate (תאריך איסוף),
                               @CustomerSiteId, @DeviceLocation, @Notes
      CalibrationExtension     @RequestedDate (the new validity date), @Reason
      CalibrationCancellation  @RequestedDate (the calibration date being cancelled), @Reason
      Quote                    @CalibrationLocation, @CustomerSiteId, @DeviceCount, @ItemIds,
                               @CalibrateToDeviceSpec, @Notes, @AttachmentPath (from-file variant)
      QuoteFeedback            @QuoteNumber, @Notes
      DeviceRemoval            @ItemIds or @CustomerDeviceId, @Reason

    Identity follows the other customer-portal procedures: @LoggedInUserEmail resolves to a
    CustomerId through dbo.CustomerContacts, and the request is recorded against that customer. An
    address that matches no contact is rejected rather than written with a NULL customer - an
    unattributable request is worse than a failed one, because nobody would ever answer it.

    Ownership is enforced, not assumed. Every id in @ItemIds must belong to the calling customer's
    own orders; anything else is dropped and reported in RejectedItemCount. A caller cannot file a
    request against another customer's device by guessing an id.

    @ItemIds is a comma-separated list of OrderDetailsItemId. Blank and non-numeric entries are
    ignored - note that STRING_SPLIT('', ',') returns one row holding an empty string and
    CAST('' AS INT) is 0, which is exactly how MBA-902 silently wiped channel assignments. An empty
    list here is legitimate: several request types are about an order or a report, not about a
    device.

    Returns the new CustomerPortalRequestId, the number of items attached, and how many were
    rejected as not belonging to the caller.
*/
CREATE OR ALTER PROCEDURE dbo.CreateCustomerPortalRequest
    @LoggedInUserEmail     NVARCHAR(100),
    @RequestType           NVARCHAR(40),
    @ItemIds               NVARCHAR(MAX)  = NULL,   /* OrderDetailsItemId list */
    @OrderWorkPlanId       INT            = NULL,
    @CustomerDeviceId      INT            = NULL,
    @MbaReportNumber       NVARCHAR(100)  = NULL,
    @QuoteNumber           NVARCHAR(100)  = NULL,
    @RequestedDate         DATE           = NULL,
    @Reason                NVARCHAR(1000) = NULL,
    @Notes                 NVARCHAR(2000) = NULL,
    @ShippingMethod        NVARCHAR(100)  = NULL,
    @ShippingDocument      NVARCHAR(100)  = NULL,
    @CustomerSiteId        INT            = NULL,
    @DeviceLocation        NVARCHAR(200)  = NULL,
    @DeviceCount           INT            = NULL,
    @CalibrationLocation   NVARCHAR(20)   = NULL,
    @CalibrateToDeviceSpec BIT            = NULL,
    @AttachmentPath        NVARCHAR(400)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RequestType NOT IN (N'ReportUpdate', N'Shipment', N'CalibrationExtension',
                            N'CalibrationCancellation', N'Quote', N'QuoteFeedback', N'DeviceRemoval')
        THROW 52001, 'Unknown RequestType.', 1;

    IF @CalibrationLocation IS NOT NULL AND @CalibrationLocation NOT IN (N'lab', N'customer')
        THROW 52002, 'CalibrationLocation must be lab or customer.', 1;

    DECLARE @CustomerId INT, @CustomerContactId INT;

    SELECT TOP (1) @CustomerId = cc.CustomerId, @CustomerContactId = cc.CustomerContactId
    FROM dbo.CustomerContacts AS cc
    WHERE cc.IsDeleted = 0
      AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)))
    ORDER BY cc.CustomerContactId ASC;

    IF @CustomerId IS NULL
        THROW 52003, 'The submitting address does not belong to any customer contact.', 1;

    /* MBA-902 lesson: drop blanks and non-numerics rather than letting them become 0. */
    CREATE TABLE #Ids (OrderDetailsItemId INT PRIMARY KEY);

    INSERT INTO #Ids (OrderDetailsItemId)
    SELECT DISTINCT CAST(LTRIM(RTRIM(value)) AS INT)
    FROM STRING_SPLIT(ISNULL(@ItemIds, N''), ',')
    WHERE LTRIM(RTRIM(value)) <> N''
      AND LTRIM(RTRIM(value)) NOT LIKE '%[^0-9]%';

    /* Only items that really belong to this customer survive. */
    SELECT i.OrderDetailsItemId, it.MbaReportNumber, it.SerialNumber
    INTO #Owned
    FROM #Ids AS i
    INNER JOIN dbo.OrderDetailsItems AS it ON it.OrderDetailsItemId = i.OrderDetailsItemId
    INNER JOIN dbo.OrderDetails      AS od ON od.OrderDetailId      = it.OrderDetailId
    INNER JOIN dbo.OrderWorkPlans    AS wp ON wp.OrderWorkPlanId    = od.OrderWorkPlanId
    WHERE wp.CustomerId = @CustomerId
      AND ISNULL(it.IsDeleted, 0) = 0
      AND ISNULL(od.IsDeleted, 0) = 0;

    DECLARE @Rejected INT = (SELECT COUNT(*) FROM #Ids) - (SELECT COUNT(*) FROM #Owned);

    BEGIN TRAN;

        INSERT INTO dbo.CustomerPortalRequest
            (RequestType, Status, CustomerId, CustomerContactId, SubmittedByEmail,
             OrderWorkPlanId, OrderDetailsItemId, CustomerDeviceId, MbaReportNumber, QuoteNumber,
             RequestedDate, Reason, Notes, ShippingMethod, ShippingDocument, CustomerSiteId,
             DeviceLocation, DeviceCount, CalibrationLocation, CalibrateToDeviceSpec, AttachmentPath)
        VALUES
            (@RequestType, N'New', @CustomerId, @CustomerContactId,
             LOWER(LTRIM(RTRIM(@LoggedInUserEmail))),
             @OrderWorkPlanId,
             (SELECT MIN(OrderDetailsItemId) FROM #Owned),   /* the single-device shortcut */
             @CustomerDeviceId, @MbaReportNumber, @QuoteNumber,
             @RequestedDate, @Reason, @Notes, @ShippingMethod, @ShippingDocument, @CustomerSiteId,
             @DeviceLocation, @DeviceCount, @CalibrationLocation, @CalibrateToDeviceSpec, @AttachmentPath);

        DECLARE @RequestId BIGINT = CAST(SCOPE_IDENTITY() AS BIGINT);

        INSERT INTO dbo.CustomerPortalRequestItem
            (CustomerPortalRequestId, OrderDetailsItemId, MbaReportNumber, SerialNumber)
        SELECT @RequestId, o.OrderDetailsItemId, o.MbaReportNumber, o.SerialNumber
        FROM #Owned AS o;

    COMMIT;

    SELECT @RequestId                              AS customerPortalRequestId,
           (SELECT COUNT(*) FROM #Owned)           AS itemCount,
           @Rejected                               AS rejectedItemCount;
END
GO

/* ================= dbo.CreateOrderApprovalRequest ================= */
/*
    dbo.CreateOrderApprovalRequest
    ------------------------------
    Issue a one-time approve/reject link for an order and remember who it was mailed to.

    The caller (the app) generated a random token, hashed it with the server-side pepper and
    passes only the digest — the plaintext token lives in the e-mail and nowhere else.

    Any earlier link that is still open for the same order is invalidated first, so a re-send
    always leaves exactly one usable link per order. Links that were already answered are left
    untouched — they are the audit trail of what the customer decided and when.

    Parameters:
      @OrderWorkPlanId INT           (required)
      @TokenHash       VARBINARY(32) (required) HMAC-SHA256 of the token
      @Email           NVARCHAR(100) (required) recipient
      @CustomerContactId INT  = NULL
      @TtlSeconds      INT    = 1209600  (14 days — a customer may answer after a weekend)

    Returns one row:
      Status ∈ { 'Created', 'OrderNotFound', 'OrderCancelled' }, OrderApprovalRequestId,
      OrderNumber, ExpiresAt, SupersededCount
*/
CREATE OR ALTER PROCEDURE dbo.CreateOrderApprovalRequest
    @OrderWorkPlanId   INT,
    @TokenHash         VARBINARY(32),
    @Email             NVARCHAR(100),
    @CustomerContactId INT = NULL,
    @TtlSeconds        INT = 1209600
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @OrderNumber NVARCHAR(20),
            @CustomerId  INT,
            @IsCancelled BIT;

    SELECT @OrderNumber = wp.OrderNumber,
           @CustomerId  = wp.CustomerId,
           @IsCancelled = wp.IsCancelled
    FROM dbo.OrderWorkPlans AS wp
    WHERE wp.OrderWorkPlanId = @OrderWorkPlanId;

    IF @OrderNumber IS NULL
    BEGIN
        SELECT CAST(N'OrderNotFound' AS NVARCHAR(20)) AS Status,
               CAST(NULL AS BIGINT)                   AS OrderApprovalRequestId,
               CAST(NULL AS NVARCHAR(20))             AS OrderNumber,
               CAST(NULL AS DATETIME2(3))             AS ExpiresAt,
               0                                      AS SupersededCount;
        RETURN;
    END

    IF @IsCancelled = 1
    BEGIN
        SELECT CAST(N'OrderCancelled' AS NVARCHAR(20)) AS Status,
               CAST(NULL AS BIGINT)                    AS OrderApprovalRequestId,
               @OrderNumber                            AS OrderNumber,
               CAST(NULL AS DATETIME2(3))              AS ExpiresAt,
               0                                       AS SupersededCount;
        RETURN;
    END

    DECLARE @Now       DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @ExpiresAt DATETIME2(3) = DATEADD(SECOND, @TtlSeconds, @Now);
    DECLARE @Superseded INT = 0;

    BEGIN TRANSACTION;

        UPDATE dbo.OrderApprovalRequest
        SET InvalidatedAt = @Now
        WHERE OrderWorkPlanId = @OrderWorkPlanId
          AND RespondedAt   IS NULL
          AND InvalidatedAt IS NULL;

        SET @Superseded = @@ROWCOUNT;

        INSERT dbo.OrderApprovalRequest
            (OrderWorkPlanId, OrderNumber, TokenHash, CustomerId, CustomerContactId,
             SentToEmail, CreatedAt, ExpiresAt)
        VALUES
            (@OrderWorkPlanId, @OrderNumber, @TokenHash, @CustomerId, @CustomerContactId,
             LOWER(LTRIM(RTRIM(@Email))), @Now, @ExpiresAt);

        DECLARE @Id BIGINT = SCOPE_IDENTITY();

    COMMIT TRANSACTION;

    SELECT CAST(N'Created' AS NVARCHAR(20)) AS Status,
           @Id                              AS OrderApprovalRequestId,
           @OrderNumber                     AS OrderNumber,
           @ExpiresAt                       AS ExpiresAt,
           @Superseded                      AS SupersededCount;
END
GO

/* ================= dbo.DeleteCalibrationCycle ================= */
-- =============================================
-- Author:		Kate Zashalovska
-- Create date: 31/07/2025
-- Description:	Soft delete calibration cycle and its associated points
-- JiraLink: 
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[DeleteCalibrationCycle]
    @LoggedInUserEmail NVARCHAR(200),
    @OrderDetailsItemId INT,
    @CalibrationCycleStartDate DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LoggedInUserId INT 
    SELECT @LoggedInUserId = d.UserId FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

    -- Soft delete the cycle
    UPDATE [dbo].[CalibrationCycles]
    SET IsDeleted = 1,
        UpdatedDate = GETDATE(),
        UpdateUserID = @LoggedInUserId
    WHERE OrderDetailsItemId = @OrderDetailsItemId
      AND CalibrationCycleStartDate = @CalibrationCycleStartDate
      AND IsDeleted = 0;

    -- Soft delete associated points
    UPDATE [dbo].[MeasurmentPointsToCalibrationCycles]
    SET IsDeleted = 1,
        UpdatedDate = GETDATE(),
        UpdateUserID = @LoggedInUserId
    WHERE OrderDetailsItemId = @OrderDetailsItemId
      AND CalibrationCycleStartDate = @CalibrationCycleStartDate
      AND IsDeleted = 0;
END
GO

/* ================= dbo.DeleteOrderNote ================= */
/*
    dbo.DeleteOrderNote                                                                 MBA-907
    ---------------------------------------------------------------------------------------------
    Soft-deletes one note. Only its author may remove it - a coordinator cannot erase somebody
    else's account of what happened.

    Nothing is removed from the table, so a note that mattered can still be recovered.
*/
CREATE OR ALTER PROCEDURE dbo.DeleteOrderNote
    @LoggedInUserEmail NVARCHAR(100),
    @OrderNoteId       BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Email NVARCHAR(100) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)));

    IF NOT EXISTS (SELECT 1 FROM dbo.OrderNote
                   WHERE OrderNoteId = @OrderNoteId AND IsDeleted = 0)
        THROW 53011, 'No such note.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.OrderNote
                   WHERE OrderNoteId = @OrderNoteId AND CreatedByEmail = @Email)
        THROW 53012, 'Only the author of a note may remove it.', 1;

    UPDATE dbo.OrderNote
    SET IsDeleted = 1,
        DeletedDate = SYSUTCDATETIME(),
        DeletedByUserId = (SELECT TOP (1) u.ID FROM dbo.Users u
                           WHERE LOWER(LTRIM(RTRIM(u.Email))) = @Email)
    WHERE OrderNoteId = @OrderNoteId;

    SELECT @OrderNoteId AS id;
END
GO

/* ================= dbo.DuplicateCustomerDevice ================= */
/*
    dbo.DuplicateCustomerDevice                                                         MBA-903
    ---------------------------------------------------------------------------------------------
    Copies a customer device, for the "שכפול מכשיר" action in the portal's device menu.

    A customer who owns forty identical thermometers should enter one and copy it thirty-nine
    times, changing only the serial number. Today there is no procedure for it, so the action has
    nowhere to write.

    Everything descriptive is copied - category, manufacturer, model, accuracy, units,
    specification, calibration interval, report language. The things that identify one physical
    instrument are NOT: SerialNumber, ManufacturerNumber and AdditionalDeviceNumber come from the
    caller, and the calibration history does not follow, because the copy has never been
    calibrated. LastAdjustmentDate and NextCalibrationDate are deliberately left for the caller
    rather than inherited: a copy inheriting the original's next-calibration date would silently
    tell the customer a brand new device is already due.

    Ownership is enforced: the source device must belong to the calling customer.

    A serial number that already exists for this customer is refused. Two devices with the same
    serial cannot be told apart on a report, which is the one thing a calibration certificate must
    get right.

    @Copies makes several at once for the bulk case. Serial numbers must then be supplied as a
    comma-separated list of the same length, since only the customer knows them.
*/
CREATE OR ALTER PROCEDURE dbo.DuplicateCustomerDevice
    @LoggedInUserEmail    NVARCHAR(100),
    @CustomerDeviceId     INT,
    @SerialNumbers        NVARCHAR(MAX),        /* one per copy, comma separated */
    @DeviceLocation       NVARCHAR(200) = NULL,
    @CustomerSiteId       INT           = NULL,
    @NextCalibrationDate  DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CustomerId INT, @UserId INT;

    SELECT TOP (1) @CustomerId = cc.CustomerId
    FROM dbo.CustomerContacts AS cc
    WHERE cc.IsDeleted = 0
      AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)))
    ORDER BY cc.CustomerContactId ASC;

    IF @CustomerId IS NULL
        THROW 52021, 'The calling address does not belong to any customer contact.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.CustomerDevices AS d
                   WHERE d.CustomerDeviceID = @CustomerDeviceId
                     AND d.CustomerId = @CustomerId
                     AND d.IsDeleted = 0)
        THROW 52022, 'The device to copy does not belong to the caller.', 1;

    /* Blanks dropped rather than becoming empty serials - same care as MBA-902. */
    CREATE TABLE #Serials (SerialNumber NVARCHAR(100) PRIMARY KEY);

    INSERT INTO #Serials (SerialNumber)
    SELECT DISTINCT LTRIM(RTRIM(value))
    FROM STRING_SPLIT(ISNULL(@SerialNumbers, N''), ',')
    WHERE LTRIM(RTRIM(value)) <> N'';

    IF NOT EXISTS (SELECT 1 FROM #Serials)
        THROW 52023, 'At least one serial number is required.', 1;

    DECLARE @Clash NVARCHAR(100);
    SELECT TOP (1) @Clash = s.SerialNumber
    FROM #Serials AS s
    WHERE EXISTS (SELECT 1 FROM dbo.CustomerDevices AS d
                  WHERE d.CustomerId = @CustomerId
                    AND d.IsDeleted = 0
                    AND LTRIM(RTRIM(d.SerialNumber)) = s.SerialNumber);

    IF @Clash IS NOT NULL
        THROW 52024, 'A device with one of these serial numbers already exists for this customer.', 1;

    INSERT INTO dbo.CustomerDevices
        (CustomerId, MainCategoryId, SecondaryCategoryId, CustomerSiteId, CustomerContactId,
         OrdersProductTypeId, Accuracy, OrdersDeviceManufacturer, DeviceLocation, Model,
         SerialNumber, ManufacturerNumber, AdditionalDeviceNumber, DateFormatStructure,
         NextCalibrationDate, CalibrationIntervalMonths, ReportLanguage, IsThirdPartyCalibration,
         BatteriesReplacement, CalibrationMethod, SpecificationReferenceId,
         MeasurementsSpecificationId, PrimaryMeasurmentUnitId, SecondaryMeasurmentUnitId,
         GuardBand, CreatedDate, IsDeleted)
    SELECT
         src.CustomerId, src.MainCategoryId, src.SecondaryCategoryId,
         COALESCE(@CustomerSiteId, src.CustomerSiteId), src.CustomerContactId,
         src.OrdersProductTypeId, src.Accuracy, src.OrdersDeviceManufacturer,
         COALESCE(@DeviceLocation, src.DeviceLocation), src.Model,
         s.SerialNumber,
         NULL,                      /* ManufacturerNumber identifies one instrument */
         NULL,                      /* AdditionalDeviceNumber likewise */
         src.DateFormatStructure,
         @NextCalibrationDate,      /* never inherited - see the header */
         src.CalibrationIntervalMonths, src.ReportLanguage, src.IsThirdPartyCalibration,
         src.BatteriesReplacement, src.CalibrationMethod, src.SpecificationReferenceId,
         src.MeasurementsSpecificationId, src.PrimaryMeasurmentUnitId, src.SecondaryMeasurmentUnitId,
         src.GuardBand, GETDATE(), 0
    FROM dbo.CustomerDevices AS src
    CROSS JOIN #Serials AS s
    WHERE src.CustomerDeviceID = @CustomerDeviceId;

    SELECT d.CustomerDeviceID AS customerDeviceId, d.SerialNumber AS serialNumber
    FROM dbo.CustomerDevices AS d
    INNER JOIN #Serials AS s ON s.SerialNumber = d.SerialNumber
    WHERE d.CustomerId = @CustomerId AND d.IsDeleted = 0;
END
GO

/* ================= dbo.GetCustomerPortalRequestList ================= */
/*
    dbo.GetCustomerPortalRequestList                                                    MBA-903
    ---------------------------------------------------------------------------------------------
    The requests a customer has submitted from the portal, newest first, with their status.

    Without this the customer submits into silence: the popups write a request and nothing ever
    shows it again. This is the "did anyone see what I asked for" screen, and it is also what lets
    the UI stop a customer filing the same extension request four times.

    Output columns are camelCase to match the front-end row types, the same convention as
    GetCustomerRequests and GetCustomerDeviceList.

    statusLabel and typeLabel are the Hebrew the screen shows. They are resolved here rather than
    in the client so that the portal and any MBA-side view cannot drift into calling the same
    status two different things.

    Scoped to the caller's own customer, so it cannot return another customer's requests even if a
    request id is guessed. @Status and @RequestType are optional filters; the list is otherwise
    returned whole, since filtering and sorting are done client-side.
*/
CREATE OR ALTER PROCEDURE dbo.GetCustomerPortalRequestList
    @LoggedInUserEmail NVARCHAR(100),
    @Status            NVARCHAR(20) = NULL,
    @RequestType       NVARCHAR(40) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT;

    SELECT TOP (1) @CustomerId = cc.CustomerId
    FROM dbo.CustomerContacts AS cc
    WHERE cc.IsDeleted = 0
      AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)))
    ORDER BY cc.CustomerContactId ASC;

    SELECT
         r.CustomerPortalRequestId                         AS id
        ,r.RequestType                                     AS requestType
        ,CASE r.RequestType
            WHEN N'ReportUpdate'            THEN N'בקשה לעדכון דוח'
            WHEN N'Shipment'                THEN N'הזמנה לשינוע'
            WHEN N'CalibrationExtension'    THEN N'הארכת תוקף כיול'
            WHEN N'CalibrationCancellation' THEN N'בקשה לביטול הכיול'
            WHEN N'Quote'                   THEN N'בקשה להצעת מחיר'
            WHEN N'QuoteFeedback'           THEN N'התייחסות לקוח'
            WHEN N'DeviceRemoval'           THEN N'מחיקת מכשיר'
         END                                               AS typeLabel
        ,r.Status                                          AS status
        ,CASE r.Status
            WHEN N'New'        THEN N'חדש'
            WHEN N'InProgress' THEN N'בטיפול'
            WHEN N'Approved'   THEN N'אושר'
            WHEN N'Rejected'   THEN N'נדחה'
            WHEN N'Cancelled'  THEN N'בוטל'
            WHEN N'Done'       THEN N'הסתיים'
         END                                               AS statusLabel
        ,r.OrderWorkPlanId                                 AS orderId
        ,wp.OrderNumber                                    AS orderNumber
        ,r.MbaReportNumber                                 AS mbaReportNumber
        ,r.QuoteNumber                                     AS quoteNumber
        ,CONVERT(VARCHAR(10), r.RequestedDate, 104)        AS requestedDate
        ,r.Reason                                          AS reason
        ,r.Notes                                           AS notes
        ,r.ShippingMethod                                  AS shippingMethod
        ,r.ShippingDocument                                AS shippingDocument
        ,r.DeviceLocation                                  AS deviceLocation
        ,r.CalibrationLocation                             AS calibrationLocation
        ,r.AttachmentPath                                  AS attachmentPath
        ,COALESCE(r.DeviceCount, itm.ItemCount)            AS deviceCount
        ,itm.SerialNumbers                                 AS serialNumbers
        ,r.SubmittedByEmail                                AS submittedByEmail
        ,CONVERT(VARCHAR(10), r.CreatedDate, 104)          AS createdDate
        ,CONVERT(VARCHAR(10), r.ResolvedDate, 104)         AS resolvedDate
        ,r.ResolutionNotes                                 AS resolutionNotes
    FROM dbo.CustomerPortalRequest AS r
    LEFT JOIN dbo.OrderWorkPlans AS wp ON wp.OrderWorkPlanId = r.OrderWorkPlanId
    OUTER APPLY
    (
        SELECT COUNT(*) AS ItemCount,
               STRING_AGG(i.SerialNumber, N', ') WITHIN GROUP (ORDER BY i.SerialNumber) AS SerialNumbers
        FROM dbo.CustomerPortalRequestItem AS i
        WHERE i.CustomerPortalRequestId = r.CustomerPortalRequestId
    ) AS itm
    WHERE r.CustomerId = @CustomerId
      AND r.IsDeleted = 0
      AND (@Status      IS NULL OR r.Status      = @Status)
      AND (@RequestType IS NULL OR r.RequestType = @RequestType)
    ORDER BY r.CreatedDate DESC;
END
GO

/* ================= dbo.GetMeasurmentPointsForCalibrationCycle ================= */
-- =============================================
-- Author:		Kate Zashalovska
-- Create date: 03/06/2026
-- Description:	Get Measurment Points For Calibration Cycle
-- JiraLink: 
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[GetMeasurmentPointsForCalibrationCycle]
    @OrderDetailsItemId INT,
    @CalibrationCycleStartDate DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM [dbo].[MeasurmentPointsToCalibrationCycles]
    WHERE OrderDetailsItemId = @OrderDetailsItemId
      AND CalibrationCycleStartDate = @CalibrationCycleStartDate
      AND IsDeleted = 0;
END
GO

/* ================= dbo.GetOrderApprovalDetails ================= */
/*
    dbo.GetOrderApprovalDetails
    ---------------------------
    Everything the coordination e-mail ("אישור תיאום כיול") needs about one order, in a single
    row so a Prisma $queryRaw call can read it (only the first result set survives that API).

    Parameters:
      @OrderWorkPlanId INT  (required)

    Returns exactly 0 or 1 rows:
      OrderWorkPlanId, OrderNumber, CustomerId, CustomerName, CustomerNameENG,
      ClientConfirmationStatus  — current status, ENG ('New' when the column is NULL)
      IsCancelled
      PlacementDate             — תאריך שיבוץ: earliest CalibratorsToWorkPlan.AssigmentDate
      SiteAddress               — אתר הלקוח (first non-empty site on the order lines)
      CalibrationRange          — תחומי הכיול, comma separated MainCategories (Priority: תחום כיול)
      ContactName / ContactEmail / ContactPhone — the recipient of the e-mail
      ContactId
      RecipientCount            — how many contacts of this customer have an e-mail at all
      CalibratorsJson           — [{ "Name": "...", "Phone": "..." }]  שם וטלפון הכייל
      DevicesJson               — [{ "PartName", "ProductType", "Manufacturer", "Model",
                                     "SerialNumber", "AdditionalDeviceNumber", "Quantity" }]
                                  רשימת כלים — see the comment on the column below for the
                                  per-device / per-line fallback.
      SkusJson                  — ["999999", ...] distinct מק"טים, for the Priority intake call

    Contact resolution: contacts of the order's customer that have an e-mail, preferring one
    attached to a site that appears on the order, then the lowest CustomerContactId — the same
    "deterministic pick" rule dbo.GetCustomerPortalContactByEmail uses.

    Read-only.
*/
CREATE OR ALTER PROCEDURE dbo.GetOrderApprovalDetails
    @OrderWorkPlanId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @OrderWorkPlanId IS NULL
        RETURN;

    /* Sites that appear on this order's lines — used to prefer a site contact. */
    DROP TABLE IF EXISTS #OrderSites;
    CREATE TABLE #OrderSites (CustomerSiteId INT PRIMARY KEY);

    INSERT #OrderSites (CustomerSiteId)
    SELECT DISTINCT od.CustomerSiteId
    FROM dbo.OrderDetails AS od
    WHERE od.OrderWorkPlanId = @OrderWorkPlanId
      AND od.IsDeleted = 0
      AND od.CustomerSiteId IS NOT NULL;

    DECLARE @CustomerId INT =
    (
        SELECT wp.CustomerId
        FROM dbo.OrderWorkPlans AS wp
        WHERE wp.OrderWorkPlanId = @OrderWorkPlanId
    );

    DECLARE @ContactId    INT,
            @ContactName  NVARCHAR(100),
            @ContactEmail NVARCHAR(100),
            @ContactPhone NVARCHAR(100),
            @RecipientCount INT = 0;

    SELECT TOP (1)
        @ContactId    = cc.CustomerContactId,
        @ContactName  = cc.CustomerContactName,
        @ContactEmail = LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))),
        @ContactPhone = COALESCE(NULLIF(LTRIM(RTRIM(cc.CustomerContactPhone)), N''),
                                 cc.CustomerContactAdditionalPhoneNumber)
    FROM dbo.CustomerContacts AS cc
    WHERE cc.IsDeleted = 0
      AND cc.CustomerId = @CustomerId
      AND NULLIF(LTRIM(RTRIM(cc.CustomerContactEmail)), N'') IS NOT NULL
    ORDER BY
        CASE WHEN EXISTS (SELECT 1 FROM #OrderSites AS s WHERE s.CustomerSiteId = cc.CustomerSiteId)
             THEN 0 ELSE 1 END,
        cc.CustomerContactId ASC;

    SELECT @RecipientCount = COUNT(*)
    FROM dbo.CustomerContacts AS cc
    WHERE cc.IsDeleted = 0
      AND cc.CustomerId = @CustomerId
      AND NULLIF(LTRIM(RTRIM(cc.CustomerContactEmail)), N'') IS NOT NULL;

    SELECT
        wp.OrderWorkPlanId,
        wp.OrderNumber,
        wp.CustomerId,
        cust.CustomerName,
        cust.CustomerNameENG,
        COALESCE(st.StatusDescriptionENG, N'New')  AS ClientConfirmationStatus,
        wp.IsCancelled,

        (SELECT MIN(ctwp.AssigmentDate)
         FROM dbo.CalibratorsToWorkPlan AS ctwp
         WHERE ctwp.OrderWorkPlanId = wp.OrderWorkPlanId
           AND ctwp.IsDeleted = 0)                 AS PlacementDate,

        (SELECT TOP (1) NULLIF(LTRIM(RTRIM(cs.CustomerSiteAddress)), N'')
         FROM #OrderSites AS s
         JOIN dbo.CustomerSites AS cs ON cs.CustomerSiteId = s.CustomerSiteId
         WHERE NULLIF(LTRIM(RTRIM(cs.CustomerSiteAddress)), N'') IS NOT NULL
         ORDER BY cs.CustomerSiteId)                AS SiteAddress,

        (SELECT STRING_AGG(x.MainCategoryName, N', ')
         FROM (SELECT DISTINCT mc.MainCategoryName
               FROM dbo.OrderDetails AS od
               JOIN dbo.MainCategories AS mc ON mc.ID = od.MainCategoryId
               WHERE od.OrderWorkPlanId = wp.OrderWorkPlanId
                 AND od.IsDeleted = 0) AS x)        AS CalibrationRange,

        @ContactId                                  AS ContactId,
        @ContactName                                AS ContactName,
        @ContactEmail                               AS ContactEmail,
        @ContactPhone                               AS ContactPhone,
        @RecipientCount                             AS RecipientCount,

        ISNULL((SELECT LTRIM(RTRIM(CONCAT(u.FirstName, N' ', u.LastName))) AS [Name],
                       u.Phone                                            AS Phone
                FROM dbo.CalibratorsToWorkPlan AS ctwp
                JOIN dbo.Users AS u ON u.ID = ctwp.CalibratorId
                WHERE ctwp.OrderWorkPlanId = wp.OrderWorkPlanId
                  AND ctwp.IsDeleted = 0
                ORDER BY ctwp.CalibratorsToWorkPlanId
                FOR JSON PATH), N'[]')              AS CalibratorsJson,

        /*
            רשימת הכלים. Two sources, per order LINE, because OrderDetailsItems (the per-device
            rows carrying serial numbers) exist for only ~18% of scheduled orders on PROD, while
            every order has OrderDetails lines. Sourcing from the items alone left 82% of the
            coordination e-mails saying "אין כלים רשומים בהזמנה".

              * line HAS items  -> one entry per device, with its serial number (Quantity = 1)
              * line has NO items -> one entry for the line itself: the product-type description
                                     (OrdersProductTypeName, populated on 868/868 PROD lines) and
                                     the ordered quantity.

            The fallback is per line, not per order, so a partially-detailed order lists the
            devices it does have and summarises the rest instead of dropping them.
        */
        ISNULL((SELECT x.PartName,
                       x.ProductType,
                       x.Manufacturer,
                       x.Model,
                       x.SerialNumber,
                       x.AdditionalDeviceNumber,
                       x.Quantity
                FROM (
                        SELECT od.OrderDetailId,
                               itm.OrderDetailsItemId       AS SortKey,
                               od.PartName                  AS PartName,
                               opt.OrdersProductTypeName    AS ProductType,
                               itm.OrdersDeviceManufacturer AS Manufacturer,
                               itm.DeviceModel              AS Model,
                               itm.SerialNumber             AS SerialNumber,
                               itm.AdditionalDeviceNumber   AS AdditionalDeviceNumber,
                               1                            AS Quantity
                        FROM dbo.OrderDetails AS od
                        JOIN dbo.OrderDetailsItems AS itm ON itm.OrderDetailId = od.OrderDetailId
                        LEFT JOIN dbo.OrdersProductTypes AS opt
                               ON opt.OrdersProductTypeId = od.OrdersProductTypeId
                        WHERE od.OrderWorkPlanId = wp.OrderWorkPlanId
                          AND od.IsDeleted = 0
                          AND od.IsCancelled = 0
                          AND itm.IsDeleted = 0
                          AND itm.IsCancelled = 0

                        UNION ALL

                        SELECT od.OrderDetailId,
                               0                            AS SortKey,
                               od.PartName                  AS PartName,
                               opt.OrdersProductTypeName    AS ProductType,
                               CAST(NULL AS NVARCHAR(255))  AS Manufacturer,
                               CAST(NULL AS NVARCHAR(255))  AS Model,
                               CAST(NULL AS NVARCHAR(255))  AS SerialNumber,
                               CAST(NULL AS NVARCHAR(255))  AS AdditionalDeviceNumber,
                               ISNULL(od.OrderLineCnt, 1)   AS Quantity
                        FROM dbo.OrderDetails AS od
                        LEFT JOIN dbo.OrdersProductTypes AS opt
                               ON opt.OrdersProductTypeId = od.OrdersProductTypeId
                        WHERE od.OrderWorkPlanId = wp.OrderWorkPlanId
                          AND od.IsDeleted = 0
                          AND od.IsCancelled = 0
                          AND NOT EXISTS (SELECT 1
                                          FROM dbo.OrderDetailsItems AS itm
                                          WHERE itm.OrderDetailId = od.OrderDetailId
                                            AND itm.IsDeleted = 0
                                            AND itm.IsCancelled = 0)
                     ) AS x
                ORDER BY x.OrderDetailId, x.SortKey
                FOR JSON PATH), N'[]')              AS DevicesJson,

        ISNULL((SELECT CONCAT(N'["',
                              STRING_AGG(STRING_ESCAPE(x.PartName, 'json'), N'","'),
                              N'"]')
                FROM (SELECT DISTINCT od.PartName
                      FROM dbo.OrderDetails AS od
                      WHERE od.OrderWorkPlanId = wp.OrderWorkPlanId
                        AND od.IsDeleted = 0
                        AND od.IsCancelled = 0
                        AND NULLIF(LTRIM(RTRIM(od.PartName)), N'') IS NOT NULL) AS x),
               N'[]')                               AS SkusJson

    FROM dbo.OrderWorkPlans AS wp
    LEFT JOIN dbo.Customers AS cust ON cust.CustomerId = wp.CustomerId
    LEFT JOIN dbo.Statuses  AS st   ON st.StatusId     = wp.ClientConfirmationStatusId
    WHERE wp.OrderWorkPlanId = @OrderWorkPlanId;
END
GO

/* ================= dbo.GetOrderApprovalRequestByToken ================= */
/*
    dbo.GetOrderApprovalRequestByToken
    ----------------------------------
    Resolve an approve/reject link to its order, without consuming it. Backs the GET of the
    public approval page: the visitor sees the coordination details and the two buttons only
    when Status = 'Valid'; every other status renders an explanatory message instead.

    Parameters:
      @TokenHash VARBINARY(32) (required) HMAC-SHA256 of the token from the URL

    Returns exactly 0 or 1 rows (0 only when @TokenHash is NULL):
      Status ∈ { 'Valid', 'Expired', 'Answered', 'Invalidated', 'NotFound' }
      OrderApprovalRequestId, OrderWorkPlanId, OrderNumber, CustomerId, SentToEmail,
      CreatedAt, ExpiresAt, RespondedAt, Decision, ResponseNotes,
      PriorityDocumentNumber, PriorityError

    'Answered' carries Decision + ResponseNotes so a customer who clicks the link twice sees
    what they already replied instead of an error. 'Invalidated' means a newer link was issued
    for the same order.

    Read-only.
*/
CREATE OR ALTER PROCEDURE dbo.GetOrderApprovalRequestByToken
    @TokenHash VARBINARY(32)
AS
BEGIN
    SET NOCOUNT ON;

    IF @TokenHash IS NULL
        RETURN;

    IF NOT EXISTS (SELECT 1 FROM dbo.OrderApprovalRequest WHERE TokenHash = @TokenHash)
    BEGIN
        SELECT CAST(N'NotFound' AS NVARCHAR(20))  AS Status,
               CAST(NULL AS BIGINT)               AS OrderApprovalRequestId,
               CAST(NULL AS INT)                  AS OrderWorkPlanId,
               CAST(NULL AS NVARCHAR(20))         AS OrderNumber,
               CAST(NULL AS INT)                  AS CustomerId,
               CAST(NULL AS NVARCHAR(100))        AS SentToEmail,
               CAST(NULL AS DATETIME2(3))         AS CreatedAt,
               CAST(NULL AS DATETIME2(3))         AS ExpiresAt,
               CAST(NULL AS DATETIME2(3))         AS RespondedAt,
               CAST(NULL AS NVARCHAR(10))         AS Decision,
               CAST(NULL AS NVARCHAR(1000))       AS ResponseNotes,
               CAST(NULL AS NVARCHAR(50))         AS PriorityDocumentNumber,
               CAST(NULL AS NVARCHAR(1000))       AS PriorityError;
        RETURN;
    END

    SELECT
        CAST(CASE
                WHEN r.RespondedAt   IS NOT NULL THEN N'Answered'
                WHEN r.InvalidatedAt IS NOT NULL THEN N'Invalidated'
                WHEN r.ExpiresAt <= SYSUTCDATETIME() THEN N'Expired'
                ELSE N'Valid'
             END AS NVARCHAR(20))       AS Status,
        r.OrderApprovalRequestId,
        r.OrderWorkPlanId,
        r.OrderNumber,
        r.CustomerId,
        r.SentToEmail,
        r.CreatedAt,
        r.ExpiresAt,
        r.RespondedAt,
        r.Decision,
        r.ResponseNotes,
        r.PriorityDocumentNumber,
        r.PriorityError
    FROM dbo.OrderApprovalRequest AS r
    WHERE r.TokenHash = @TokenHash;
END
GO

/* ================= dbo.GetOrderNotes ================= */
/*
    dbo.GetOrderNotes                                                                   MBA-907
    ---------------------------------------------------------------------------------------------
    The notes written on an order, newest first, for the הערות popup on the coordinator and
    validator screens.

    Author name falls back to the e-mail: a note written by somebody who has since left, or by an
    address that never matched a Users row, still has to say who wrote it.

    camelCase output, the convention the other screen procedures use.
*/
CREATE OR ALTER PROCEDURE dbo.GetOrderNotes
    @OrderWorkPlanId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT n.OrderNoteId                                   AS id,
           n.OrderWorkPlanId                               AS orderId,
           n.NoteText                                      AS note,
           n.CreatedByEmail                                AS authorEmail,
           COALESCE(u.FirstName + N' ' + u.LastName, n.CreatedByEmail) AS authorName,
           CONVERT(VARCHAR(16), n.CreatedDate, 120)        AS createdAt
    FROM dbo.OrderNote AS n
    LEFT JOIN dbo.Users AS u ON u.ID = n.CreatedByUserId
    WHERE n.OrderWorkPlanId = @OrderWorkPlanId
      AND n.IsDeleted = 0
    ORDER BY n.CreatedDate DESC, n.OrderNoteId DESC;
END
GO

/* ================= dbo.GetSensorTableColumnPreferences ================= */
CREATE OR ALTER PROCEDURE dbo.GetSensorTableColumnPreferences
      @UserEmail NVARCHAR(50)
    AS
    BEGIN
      SET NOCOUNT ON;

      DECLARE @UserId INT;
      SELECT TOP 1 @UserId = ID
      FROM dbo.Users
      WHERE Email = @UserEmail AND IsActive = 1;

      SELECT
        ColumnVisibility,
        ColumnOrder
      FROM dbo.UserSensorTablePreferences
      WHERE UserId = @UserId;
    END
GO

/* ================= dbo.GetSensorTableLockedColumns ================= */
CREATE OR ALTER PROCEDURE dbo.GetSensorTableLockedColumns
    AS
    BEGIN
      SET NOCOUNT ON;

      SELECT LockedColumns
      FROM dbo.UserSensorTablePreferences
      WHERE UserId IS NULL;
    END
GO

/* ================= dbo.ImportMeasurementDeviceClassFromKyulan ================= */
/*
    dbo.ImportMeasurementDeviceClassFromKyulan                                          MBA-902
    ---------------------------------------------------------------------------------------------
    Takes MainClassId from the legacy instrument registry, kyulan.dbo.tblInstr, over the Priority
    linked server. kyulan is the authority; this procedure exists because nothing was carrying that
    column across.

    The class ids are the SAME in both systems - verified, not assumed. Of the devices classified in
    both, kyulan agrees with every logger (106/106) and every bath (17/17).

    That guess is why this procedure exists. Classifying by keyword got 33 devices wrong:
        20 read 'אוגר נתונים ... עם רגש' and were called loggers - kyulan says they are SENSORS
        14 read 'מד חום ... עם רגש'    and were called sensors - kyulan says they are THERMOMETERS
         3 were called sensors         - kyulan says CABLE
    A description that mentions a sensor is not a sensor, and no keyword rule can know that. Where
    kyulan has an opinion it overwrites the guess.

    Scope, and it is narrower than it looks: kyulan holds 1,791 active instruments and AWS holds
    2,032 active devices, but only 401 are in both. 1,631 AWS devices are not in the active registry
    at all and this procedure cannot say anything about them. The reverse gap is worse and is NOT
    addressed here - 1,421 active kyulan instruments have no AWS row whatsoever, which is why a
    device like 31-98 (registered 2026-05-26, calibrated, in date) cannot be found in any picker.
    That is an import, not a classification, and needs its own decision.

    Removed instruments are ignored: kyulan's Removed column marks retirement, and a retired
    instrument must not resurrect a class onto a device someone is still using.

    A DEVICE IN USE IS NEVER RECLASSIFIED. The registry's taxonomy and this system's operational
    reality disagree, and in a picker the operational one has to win. Three exclusions, each one
    learned the hard way on the first run:

      ConnectionPoints is set          -> it is a logger. kyulan calls 21-114 and 21-622 multimeters
                                          and 21-479 a display; here they are configured loggers
                                          with a connection and a channel count. Reclassifying them
                                          took the wizard's logger picker from 36 down to 25.
      wired into a logger              -> it is a sensor. 21-131 ('חוט TC-R + S') moved to Cable,
                                          which is what the registry calls it, while attached to
                                          logger 21-142 with ten channels assigned. It vanished
                                          from the sensor picker mid-use.
      used as a measurement point      -> it is a sensor. 31-77 moved to Thermometer while serving
                                          as the sensor on a live measurement point.

    Sixteen other devices did move out of the sensor class on that run and were left there,
    because nothing is using them: fourteen 'מד חום סיפרתי עם רגש' became Thermometer and two
    'חוט TC' became Cable. Whether the wizard's sensor picker should also offer thermometers is a
    domain question, not a data one - the picker currently asks for MainClassId = 2 only.

    Run with @Apply = 0 first: it reports what would change and touches nothing.
*/
CREATE OR ALTER PROCEDURE dbo.ImportMeasurementDeviceClassFromKyulan
    @Apply BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    CREATE TABLE #Kyulan
    (
        MabaID    NVARCHAR(100) COLLATE DATABASE_DEFAULT PRIMARY KEY,
        MainClass INT
    );

    /* OPENQUERY so the scan runs on the remote server rather than dragging tblInstr across. */
    INSERT INTO #Kyulan (MabaID, MainClass)
    SELECT MabaID COLLATE DATABASE_DEFAULT, MainClass
    FROM OPENQUERY([31.168.173.93], '
        SELECT MabaID, MIN(MainClass) AS MainClass
        FROM kyulan.dbo.tblInstr
        WHERE MabaID IS NOT NULL
          AND Removed IS NULL
          AND MainClass IS NOT NULL
        GROUP BY MabaID');

    /* A class kyulan names but this system does not have would be worse than no class at all. */
    DELETE k
    FROM #Kyulan AS k
    WHERE NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevicesMainClasses AS c WHERE c.Id = k.MainClass);

    SELECT m.ID AS MeasurementDeviceId, m.MabaID, m.Description,
           m.MainClassId AS CurrentClassId, k.MainClass AS KyulanClassId
    INTO #Apply
    FROM dbo.MeasurementDevices AS m
    INNER JOIN #Kyulan AS k ON k.MabaID = m.MabaID
    WHERE m.IsDeleted = 0
      AND (m.MainClassId IS NULL OR m.MainClassId <> k.MainClass)
      /* Never reclassify a device that is in use. See the header - the registry's taxonomy and
         this system's operational reality disagree, and in a picker the operational one wins. */
      AND m.ConnectionPoints IS NULL          /* a configured channel count means it is a logger */
      AND NOT EXISTS (SELECT 1 FROM dbo.SensorToLoggerRelation AS r
                      WHERE r.IsDeleted = 0
                        AND (r.SensorMeasurementDeviceId = m.ID
                          OR r.LoggerMeasurementDeviceId = m.ID))
      AND NOT EXISTS (SELECT 1 FROM dbo.MeasurmentPointsToOrderDetailsItems AS mp
                      WHERE mp.IsDeleted = 0
                        AND mp.SensorMeasurementDeviceId = m.ID);

    SELECT
        (SELECT COUNT(*) FROM #Kyulan)                                     AS KyulanActiveWithClass,
        (SELECT COUNT(*) FROM dbo.MeasurementDevices WHERE IsDeleted = 0)  AS AwsActiveDevices,
        (SELECT COUNT(*) FROM #Apply)                                      AS WouldChange,
        (SELECT COUNT(*) FROM #Apply WHERE CurrentClassId IS NULL)         AS FillingABlank,
        (SELECT COUNT(*) FROM #Apply WHERE CurrentClassId IS NOT NULL)     AS CorrectingAGuess,
        (SELECT COUNT(*) FROM dbo.MeasurementDevices m WHERE m.IsDeleted = 0
           AND NOT EXISTS (SELECT 1 FROM #Kyulan k WHERE k.MabaID = m.MabaID)) AS AwsRowsKyulanDoesNotKnow;

    IF @Apply = 1
    BEGIN
        UPDATE m
        SET MainClassId = a.KyulanClassId,
            UpdateDate  = GETDATE()
        FROM dbo.MeasurementDevices AS m
        INNER JOIN #Apply AS a ON a.MeasurementDeviceId = m.ID;

        SELECT @@ROWCOUNT AS RowsUpdated;
    END
    ELSE
        SELECT a.MabaID, a.Description,
               cc.NameHebrew AS CurrentClass, ck.NameHebrew AS KyulanClass
        FROM #Apply AS a
        LEFT JOIN dbo.MeasurementDevicesMainClasses AS cc ON cc.Id = a.CurrentClassId
        LEFT JOIN dbo.MeasurementDevicesMainClasses AS ck ON ck.Id = a.KyulanClassId
        ORDER BY a.CurrentClassId, a.KyulanClassId, a.MabaID;
END
GO

/* ================= dbo.ImportMissingDevicesFromKyulan ================= */
/*
    dbo.ImportMissingDevicesFromKyulan                                                  MBA-902
    ---------------------------------------------------------------------------------------------
    Creates a MeasurementDevices row for every active kyulan instrument that has none.

    1,421 instruments are registered, calibrated and in date in kyulan.dbo.tblInstr and simply do
    not exist in this database - 1,216 of them sensors, 769 of those still within calibration date,
    the newest registered 12.08.2026. A calibrator cannot select them anywhere, which is what
    "I cannot see sensor 31-98" actually means: 31-98 was registered 26.05.2026, calibrated the
    same day, valid until 2028, and has no row here at all.

    This is not a re-sync of the whole registry. It INSERTS only, never updates and never deletes,
    and skips any MabaID that already exists - a device that is already here, however stale, is not
    this procedure's business. Re-running it inserts nothing the second time.

    WHAT IS COPIED, and only what could be verified against devices present in both systems:
        MabaID, Description, Model, SerialNumber, Note
        Manufacturer      - resolved to its name through kyulan.tblInstrMnf
        MainClassId       - same ids in both systems; kyulan agrees with every logger and bath
                            already classified here
        WorkRangeMin/Max  - and WorkRangeUnitId through MeasurementDeviceUnits.
                            MeasurementDeviceUnitSourceId, the mapping the work-range import proved
        CalibrationDate, NextCalibration, CreateDate

    WHAT IS DELIBERATELY LEFT NULL, because the mapping does not hold:
        MainCategoryId  - kyulan's Department has 7 values against 15 categories here, and every
                          instrument sits in Department 4 while this system spreads the same
                          devices across six categories. Guessing would mis-file them.
        MeasurementId   - checked on the 186 devices present in both: 3 agree. Not a mapping.
        SubClassId, UnitId - never populated on this side, so there is nothing to verify against.
        Connection, ConnectionPoints, IP - kyulan does not know how a device attaches to THIS
                          system. An imported logger therefore has no connection and will NOT
                          appear in the wizard's logger picker until someone configures it, which
                          is correct: the picker offers loggers the system can actually talk to.

    DisplayToCoordinator is set so imported devices behave like the existing ones in the equipment
    screens, which filter on it.

    Run with @Apply = 0 first: it reports what would be created and touches nothing.
*/
CREATE OR ALTER PROCEDURE dbo.ImportMissingDevicesFromKyulan
    @Apply BIT = 0,
    @OnlyInCalibrationDate BIT = 0   /* 1 = skip instruments whose calibration has expired */
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    CREATE TABLE #K
    (
        MabaID          NVARCHAR(100) COLLATE DATABASE_DEFAULT PRIMARY KEY,
        Description     NVARCHAR(400) COLLATE DATABASE_DEFAULT,
        Manufacturer    NVARCHAR(200) COLLATE DATABASE_DEFAULT,
        Model           NVARCHAR(200) COLLATE DATABASE_DEFAULT,
        SerialNumber    NVARCHAR(200) COLLATE DATABASE_DEFAULT,
        Note            NVARCHAR(1000) COLLATE DATABASE_DEFAULT,
        MainClass       INT,
        WorkRangeUnit   INT,
        WorkRangeMin    DECIMAL(18,6),
        WorkRangeMax    DECIMAL(18,6),
        Added           DATETIME,
        Calibrated      DATETIME,
        NextCalibration DATETIME
    );

    /* OPENQUERY so the join to the manufacturer table runs on the remote server. */
    INSERT INTO #K
    SELECT MabaID, Description, Manufacturer, Model, SerialNumber, Note, MainClass,
           WorkRangeUnit, WorkRangeMin, WorkRangeMax, Added, Calibrated, NextCalibration
    FROM OPENQUERY([31.168.173.93], '
        SELECT i.MabaID,
               i.Description,
               mnf.Name AS Manufacturer,
               i.Model,
               i.SerialNumber,
               i.Note,
               i.MainClass,
               i.WorkRangeUnit,
               i.WorkRangeMin,
               i.WorkRangeMax,
               i.Added,
               i.Calibrated,
               i.NextCalibration
        FROM kyulan.dbo.tblInstr AS i
        LEFT JOIN kyulan.dbo.tblInstrMnf AS mnf ON mnf.ID = i.Manufacturer
        WHERE i.MabaID IS NOT NULL
          AND i.Removed IS NULL');

    SELECT k.*,
           u.MeasurementDeviceUnitId AS WorkRangeUnitId
    INTO #New
    FROM #K AS k
    LEFT JOIN dbo.MeasurementDeviceUnits AS u
           ON u.MeasurementDeviceUnitSourceId = k.WorkRangeUnit
          AND u.IsDeleted = 0
    WHERE NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevices AS m
                      WHERE m.MabaID = k.MabaID AND m.IsDeleted = 0)
      AND (k.MainClass IS NULL
           OR EXISTS (SELECT 1 FROM dbo.MeasurementDevicesMainClasses AS c WHERE c.Id = k.MainClass))
      AND (@OnlyInCalibrationDate = 0 OR k.NextCalibration > GETDATE());

    SELECT COUNT(*)                                                   AS WouldCreate,
           SUM(IIF(NextCalibration > GETDATE(), 1, 0))                AS StillInCalibrationDate,
           SUM(IIF(MainClass = 2, 1, 0))                              AS Sensors,
           SUM(IIF(MainClass = 7, 1, 0))                              AS DataLoggers,
           SUM(IIF(WorkRangeMin IS NOT NULL, 1, 0))                   AS WithWorkRange,
           SUM(IIF(WorkRangeUnit IS NOT NULL AND WorkRangeUnitId IS NULL, 1, 0)) AS UnitCouldNotBeMapped
    FROM #New;

    IF @Apply = 1
    BEGIN
        INSERT INTO dbo.MeasurementDevices
            (MabaID, Description, Manufacturer, Model, SerialNumber, Note,
             MainClassId, WorkRangeMin, WorkRangeMax, WorkRangeUnitId,
             CalibrationDate, NextCalibration, CreateDate, UpdateDate,
             DisplayToCoordinator, IsDeleted)
        SELECT n.MabaID, n.Description, n.Manufacturer, n.Model, n.SerialNumber, n.Note,
               n.MainClass, n.WorkRangeMin, n.WorkRangeMax, n.WorkRangeUnitId,
               n.Calibrated, n.NextCalibration, ISNULL(n.Added, GETDATE()), GETDATE(),
               1, 0
        FROM #New AS n;

        SELECT @@ROWCOUNT AS RowsCreated;
    END
    ELSE
        SELECT TOP (200) MabaID, Description, Manufacturer, Model, MainClass,
               WorkRangeMin, WorkRangeMax, WorkRangeUnitId,
               CONVERT(VARCHAR(10), Calibrated, 104)      AS Calibrated,
               CONVERT(VARCHAR(10), NextCalibration, 104) AS NextCalibration
        FROM #New ORDER BY MabaID;
END
GO

/* ================= dbo.MergeDuplicateLoggerDevices ================= */
/*
    dbo.MergeDuplicateLoggerDevices                                                     MBA-902
    ---------------------------------------------------------------------------------------------
    Collapses the duplicate MeasurementDevices rows that every data logger has.

    All 36 loggers exist twice - 72 rows for 36 MabaIDs - and no other device class is affected.
    21-142 is ID 619 (Connection COM, COM9) and ID 807 (Connection IP, 1.1.1.1:3); 31-83 is 641 and
    829, and so on. The logger picker therefore lists the same logger twice, and worse, a sensor
    configured against one row is invisible when the calibrator happens to pick the other: 619
    carries sensor 21-89 while 807 carries 21-131, and they are the same physical logger.

    A canonical row is chosen per MabaID: the one already carrying sensor assignments, and where
    both do (only 21-142 today) the lower ID, so the choice is repeatable. Assignments on the other
    row are repointed rather than dropped - after the merge that logger holds BOTH sensor sets,
    which is what a logger with several sensors should look like anyway.

    Repointed, in this order: SensorToLoggerRelation, then ChannelsToSensorRelation, which carries
    the logger id too. A repoint that would collide with an existing row for the same
    sensor + logger + channel is skipped rather than duplicated.

    The redundant row is then soft-deleted, never removed, so the merge can be traced and undone.

    Nothing outside the duplicate set is touched. Run with @Apply = 0 first: it reports what would
    move and changes nothing.
*/
CREATE OR ALTER PROCEDURE dbo.MergeDuplicateLoggerDevices
    @Apply BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* every logger MabaID that has more than one active device row */
    SELECT md.MabaID, md.ID,
           IIF(EXISTS (SELECT 1 FROM dbo.SensorToLoggerRelation r
                       WHERE r.LoggerMeasurementDeviceId = md.ID AND r.IsDeleted = 0), 1, 0) AS InUse
    INTO #Rows
    FROM dbo.MeasurementDevices AS md
    JOIN dbo.MeasurementDevicesMainClasses AS mc ON mc.Id = md.MainClassId
    WHERE md.IsDeleted = 0
      AND mc.NameEnglish = 'Data logger'
      AND md.MabaID IN (SELECT m2.MabaID
                        FROM dbo.MeasurementDevices AS m2
                        JOIN dbo.MeasurementDevicesMainClasses AS c2 ON c2.Id = m2.MainClassId
                        WHERE m2.IsDeleted = 0 AND c2.NameEnglish = 'Data logger'
                        GROUP BY m2.MabaID HAVING COUNT(*) > 1);

    /* in-use rows win; among equals the lower id, so re-running picks the same winner */
    SELECT MabaID, ID AS KeepId
    INTO #Keep
    FROM (SELECT MabaID, ID,
                 ROW_NUMBER() OVER (PARTITION BY MabaID ORDER BY InUse DESC, ID ASC) AS rn
          FROM #Rows) AS r
    WHERE rn = 1;

    SELECT r.MabaID, r.ID AS DropId, k.KeepId
    INTO #Move
    FROM #Rows AS r
    JOIN #Keep AS k ON k.MabaID = r.MabaID
    WHERE r.ID <> k.KeepId;

    SELECT (SELECT COUNT(*) FROM #Keep)  AS LoggersAffected,
           (SELECT COUNT(*) FROM #Move)  AS RowsToRetire,
           (SELECT COUNT(*) FROM dbo.SensorToLoggerRelation r
              JOIN #Move m ON m.DropId = r.LoggerMeasurementDeviceId WHERE r.IsDeleted = 0)   AS SensorLinksToMove,
           (SELECT COUNT(*) FROM dbo.ChannelsToSensorRelation c
              JOIN #Move m ON m.DropId = c.LoggerMeasurementDeviceId WHERE c.IsDeleted = 0)   AS ChannelLinksToMove;

    IF @Apply = 1
    BEGIN
        BEGIN TRAN;

            /* skip a move that would collide with a link the canonical row already has */
            UPDATE r
            SET LoggerMeasurementDeviceId = m.KeepId, UpdatedDate = GETDATE()
            FROM dbo.SensorToLoggerRelation AS r
            JOIN #Move AS m ON m.DropId = r.LoggerMeasurementDeviceId
            WHERE r.IsDeleted = 0
              AND NOT EXISTS (SELECT 1 FROM dbo.SensorToLoggerRelation AS x
                              WHERE x.LoggerMeasurementDeviceId = m.KeepId
                                AND x.SensorMeasurementDeviceId = r.SensorMeasurementDeviceId
                                AND x.IsDeleted = 0);

            UPDATE c
            SET LoggerMeasurementDeviceId = m.KeepId, UpdatedDate = GETDATE()
            FROM dbo.ChannelsToSensorRelation AS c
            JOIN #Move AS m ON m.DropId = c.LoggerMeasurementDeviceId
            WHERE c.IsDeleted = 0
              AND NOT EXISTS (SELECT 1 FROM dbo.ChannelsToSensorRelation AS x
                              WHERE x.LoggerMeasurementDeviceId = m.KeepId
                                AND x.SensorMeasurementDeviceId = c.SensorMeasurementDeviceId
                                AND x.ChannelNumber = c.ChannelNumber
                                AND x.IsDeleted = 0);

            /* anything that could not move would otherwise be orphaned on a retired row */
            UPDATE r SET IsDeleted = 1, UpdatedDate = GETDATE()
            FROM dbo.SensorToLoggerRelation AS r
            JOIN #Move AS m ON m.DropId = r.LoggerMeasurementDeviceId WHERE r.IsDeleted = 0;

            UPDATE c SET IsDeleted = 1, UpdatedDate = GETDATE()
            FROM dbo.ChannelsToSensorRelation AS c
            JOIN #Move AS m ON m.DropId = c.LoggerMeasurementDeviceId WHERE c.IsDeleted = 0;

            UPDATE md SET IsDeleted = 1, UpdateDate = GETDATE()
            FROM dbo.MeasurementDevices AS md
            JOIN #Move AS m ON m.DropId = md.ID;

        COMMIT;

        SELECT (SELECT COUNT(*) FROM #Move) AS RowsRetired;
    END
    ELSE
        SELECT m.MabaID, m.KeepId, m.DropId,
               keep.Connection AS KeepConnection, drop_.Connection AS DropConnection,
               (SELECT COUNT(*) FROM dbo.SensorToLoggerRelation r
                 WHERE r.LoggerMeasurementDeviceId = m.DropId AND r.IsDeleted = 0) AS SensorLinksOnDropped
        FROM #Move AS m
        JOIN dbo.MeasurementDevices AS keep  ON keep.ID  = m.KeepId
        JOIN dbo.MeasurementDevices AS drop_ ON drop_.ID = m.DropId
        ORDER BY SensorLinksOnDropped DESC, m.MabaID;
END
GO

/* ================= dbo.RefreshCustomerRemarksFromPriority ================= */
/*
    dbo.RefreshCustomerRemarksFromPriority                                              MBA-902
    ---------------------------------------------------------------------------------------------
    Rebuilds dbo.CustomerRemarks.CustomerRemark from Priority, with the word breaks intact.

    953 of the 1,012 active rows have their words glued together - "סעיףתקציבי", "מחיריםמיוחדים",
    "מיוחדותלשינוע", "המתנההמלאה". Priority stores this text one row per wrapped line in
    amaba.dbo.CUSTOMERSTEXT (CUST, TEXT, TEXTLINE, TEXTORD) and wraps at a word boundary WITHOUT
    keeping the space, so joining the lines with nothing welds the last word of each line to the
    first word of the next. Same defect, same cause, as the order instructions in
    dbo.RefreshCrmTextCache - this is the second pipeline carrying it.

    The text is also character-reversed in Priority, hence the REVERSE.

    IMPORTANT - this is a repair, not a cure. The gluing happens BEFORE SQL Server: stg_CustomerRemarks
    already arrives with CompresedText welded (727 of 1,012), so the join is done by the SSIS package
    that fills staging. Until that package uses a separator, every sync will undo this and the
    procedure has to be re-run. Raised separately.

    Only rows whose text actually differs are written, so a re-run after a clean sync is a no-op.
    Run with @Apply = 0 first: it reports what would change and touches nothing.
*/
CREATE OR ALTER PROCEDURE dbo.RefreshCustomerRemarksFromPriority
    @Apply BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    CREATE TABLE #Src (CUST INT PRIMARY KEY, Rebuilt NVARCHAR(MAX));

    /* OPENQUERY so the aggregation runs on the Priority side. */
    INSERT INTO #Src (CUST, Rebuilt)
    SELECT CUST, Rebuilt
    FROM OPENQUERY([31.168.173.93], '
        SELECT CUST,
               STRING_AGG(REVERSE(CAST(TEXT AS NVARCHAR(MAX))), '' '')
                   WITHIN GROUP (ORDER BY TEXTLINE, TEXTORD) AS Rebuilt
        FROM amaba.dbo.CUSTOMERSTEXT
        GROUP BY CUST');

    SELECT r.CustomerId, s.Rebuilt,
           CAST(DECOMPRESS(r.CustomerRemark) AS NVARCHAR(MAX)) AS Current_
    INTO #Diff
    FROM dbo.CustomerRemarks AS r
    INNER JOIN #Src AS s ON s.CUST = r.CustomerId
    WHERE r.IsDeleted = 0
      AND ISNULL(CAST(DECOMPRESS(r.CustomerRemark) AS NVARCHAR(MAX)), N'') <> ISNULL(s.Rebuilt, N'');

    SELECT (SELECT COUNT(*) FROM dbo.CustomerRemarks WHERE IsDeleted = 0) AS ActiveRows,
           (SELECT COUNT(*) FROM #Src)                                    AS FoundInPriority,
           (SELECT COUNT(*) FROM #Diff)                                   AS WouldRewrite;

    IF @Apply = 1
    BEGIN
        UPDATE r
        SET CustomerRemark = COMPRESS(d.Rebuilt),
            UpdatedDate    = GETDATE()
        FROM dbo.CustomerRemarks AS r
        INNER JOIN #Diff AS d ON d.CustomerId = r.CustomerId
        WHERE r.IsDeleted = 0;

        SELECT @@ROWCOUNT AS RowsRewritten;
    END
    ELSE
        SELECT TOP (20) CustomerId, LEFT(Current_, 90) AS before_, LEFT(Rebuilt, 90) AS after_
        FROM #Diff ORDER BY CustomerId;
END
GO

/* ================= dbo.RefreshPackingDataFromPriority ================= */
/*
    dbo.RefreshPackingDataFromPriority
    ---------------------------------------------------------------------------------------------
    Fills in the two packing-screen fields that Priority holds but our sync never brought across:
    "אריזת לקוח" (did the device arrive in the customer's own packaging) and the date we booked
    the device in at the lab.

    Why this procedure exists at all
    --------------------------------
    Both values live on the Priority GOODS-RECEIPT document, which is TYPE 'N'. Our orders point
    at a TYPE 'Q' document, and 'Q' never carries the packing flag:

        our 640 documents, all TYPE 'Q'   ->  0 carry MBA_CUSTPACK = 'Y'
        Priority TYPE 'N' documents       ->  7,272 carry MBA_CUSTPACK = 'Y'

    So stg.MergeOrdersData was reading the right column off the wrong document, and
    OrderDetails.CustomerPackingExists came out False (or NULL) for every order in the system.
    The same merge writes `NULL AS CustomerReceivingDate` outright, which is why that column is
    empty on all 3,842 items.

    The link we need is already in place: OrderDetailsItems.DOC_N points at the 'N' document
    (3,604 of 3,842 items carry one, 392 distinct documents). This procedure follows it.

    On the date column
    ------------------
    The value written to CustomerReceivingDate is the date of the goods-receipt document - i.e.
    when MBA booked the device in, not when the customer received anything. The column name is
    inherited and misleading; the screen labels it "תאריך קליטה", which is what it now holds.
    Renaming it is a separate change with front-end fallout, so the name is left alone here.

    Reading only
    ------------
    The Priority side is a plain OPENQUERY read - nothing is written back to the ERP. The pull is
    bounded to the document range we actually reference so it does not scan all 220,888 receipts.

    Idempotent: only rows whose value actually changes are touched, so re-running it is free and
    UpdatedDate does not churn. Pass @ReportOnly = 1 to see what it would do without writing.
*/
CREATE OR ALTER PROCEDURE dbo.RefreshPackingDataFromPriority
    @ReportOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MinDoc BIGINT, @MaxDoc BIGINT;

    SELECT @MinDoc = MIN(DOC_N), @MaxDoc = MAX(DOC_N)
    FROM dbo.OrderDetailsItems
    WHERE DOC_N IS NOT NULL;

    IF @MinDoc IS NULL
    BEGIN
        SELECT 0 AS ReceiptsRead, 0 AS ItemsDated, 0 AS DetailsFlagged,
               N'No item carries a DOC_N - nothing to look up.' AS Note;
        RETURN;
    END

    DROP TABLE IF EXISTS #Receipt;
    CREATE TABLE #Receipt
    (
        DOC        BIGINT   NOT NULL PRIMARY KEY,
        CustPack   BIT      NOT NULL,
        ReceivedAt DATETIME NULL
    );

    /* Bounded pull of the goods-receipt documents we reference. */
    DECLARE @sql NVARCHAR(MAX) = CONCAT(
        N'INSERT #Receipt (DOC, CustPack, ReceivedAt)
          SELECT q.DOC,
                 IIF(LTRIM(RTRIM(q.MBA_CUSTPACK)) = ''Y'', 1, 0),
                 DATEADD(MINUTE, q.CURDATE, ''1988-01-01'')
          FROM OPENQUERY([31.168.173.93], ''
                SELECT DOC, MBA_CUSTPACK, CURDATE
                FROM amaba.dbo.DOCUMENTS
                WHERE TYPE = ''''N'''' AND DOC BETWEEN ', @MinDoc, N' AND ', @MaxDoc, N'
          '') AS q');

    EXEC sp_executesql @sql;

    /* What the receipts say, before anything is written. */
    DECLARE @ReceiptsRead INT = (SELECT COUNT(*) FROM #Receipt);

    /* An order detail counts as customer-packed when ANY device on it arrived that way -
       the flag is per receipt, and one detail can span several receipts. */
    DROP TABLE IF EXISTS #DetailPack;
    SELECT od.OrderDetailId,
           CustomerPackingExists = CAST(MAX(CAST(r.CustPack AS TINYINT)) AS BIT)
    INTO #DetailPack
    FROM dbo.OrderDetails       AS od
    JOIN dbo.OrderDetailsItems  AS itm ON itm.OrderDetailId = od.OrderDetailId
    JOIN #Receipt               AS r   ON r.DOC = itm.DOC_N
    WHERE ISNULL(od.IsDeleted, 0) = 0
      AND ISNULL(itm.IsDeleted, 0) = 0
    GROUP BY od.OrderDetailId;

    IF @ReportOnly = 1
    BEGIN
        SELECT @ReceiptsRead                                              AS ReceiptsRead,
               (SELECT COUNT(*) FROM #Receipt WHERE CustPack = 1)         AS ReceiptsCustomerPacked,
               (SELECT COUNT(*)
                  FROM dbo.OrderDetailsItems AS itm
                  JOIN #Receipt AS r ON r.DOC = itm.DOC_N
                 WHERE ISNULL(itm.IsDeleted, 0) = 0
                   AND (itm.CustomerReceivingDate IS NULL
                        OR itm.CustomerReceivingDate <> r.ReceivedAt))    AS ItemsThatWouldBeDated,
               (SELECT COUNT(*)
                  FROM dbo.OrderDetails AS od
                  JOIN #DetailPack AS dp ON dp.OrderDetailId = od.OrderDetailId
                 WHERE ISNULL(od.CustomerPackingExists, 0)
                       <> dp.CustomerPackingExists)                       AS DetailsThatWouldChange;

        /* the orders that would light the packing icon */
        SELECT DISTINCT wp.OrderNumber, itm.DOC_N, r.ReceivedAt
        FROM dbo.OrderDetailsItems AS itm
        JOIN #Receipt              AS r  ON r.DOC = itm.DOC_N AND r.CustPack = 1
        JOIN dbo.OrderDetails      AS od ON od.OrderDetailId = itm.OrderDetailId
        JOIN dbo.OrderWorkPlans    AS wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
        WHERE ISNULL(itm.IsDeleted, 0) = 0
        ORDER BY wp.OrderNumber;
        RETURN;
    END

    DECLARE @ItemsDated INT = 0, @DetailsFlagged INT = 0;

    BEGIN TRANSACTION;

        UPDATE itm
        SET itm.CustomerReceivingDate = r.ReceivedAt
        FROM dbo.OrderDetailsItems AS itm
        JOIN #Receipt              AS r ON r.DOC = itm.DOC_N
        WHERE ISNULL(itm.IsDeleted, 0) = 0
          AND r.ReceivedAt IS NOT NULL
          AND (itm.CustomerReceivingDate IS NULL
               OR itm.CustomerReceivingDate <> r.ReceivedAt);

        SET @ItemsDated = @@ROWCOUNT;

        UPDATE od
        SET od.CustomerPackingExists = dp.CustomerPackingExists
        FROM dbo.OrderDetails AS od
        JOIN #DetailPack      AS dp ON dp.OrderDetailId = od.OrderDetailId
        WHERE ISNULL(od.CustomerPackingExists, 0) <> dp.CustomerPackingExists;

        SET @DetailsFlagged = @@ROWCOUNT;

    COMMIT TRANSACTION;

    SELECT @ReceiptsRead                                       AS ReceiptsRead,
           (SELECT COUNT(*) FROM #Receipt WHERE CustPack = 1)  AS ReceiptsCustomerPacked,
           @ItemsDated                                         AS ItemsDated,
           @DetailsFlagged                                     AS DetailsFlagged;
END
GO

/* ================= dbo.ResolveCustomerPortalRequest ================= */
/*
    dbo.ResolveCustomerPortalRequest                                                    MBA-903
    ---------------------------------------------------------------------------------------------
    Moves a portal request along - MBA answers it, or the customer withdraws it.

    Two callers, one procedure, and the difference matters:

      MBA staff (@LoggedInUserEmail matches dbo.Users) may set any status.
      The customer who filed it may only set Cancelled, and only while it is still New. Once MBA
      has started work, withdrawing it silently would leave somebody holding a device with no
      record of why.

    Anyone else is refused. The request id alone is not authority to change it - a customer cannot
    resolve another customer's request by guessing a number.

    Approved / Rejected / Done are terminal and stamp ResolvedDate. Re-resolving an already
    terminal request is refused rather than quietly overwriting who answered it and when.
*/
CREATE OR ALTER PROCEDURE dbo.ResolveCustomerPortalRequest
    @LoggedInUserEmail       NVARCHAR(100),
    @CustomerPortalRequestId BIGINT,
    @Status                  NVARCHAR(20),
    @ResolutionNotes         NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Status NOT IN (N'New', N'InProgress', N'Approved', N'Rejected', N'Cancelled', N'Done')
        THROW 52011, 'Unknown Status.', 1;

    DECLARE @Email NVARCHAR(100) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)));

    DECLARE @CurrentStatus NVARCHAR(20), @OwnerCustomerId INT;
    SELECT @CurrentStatus = r.Status, @OwnerCustomerId = r.CustomerId
    FROM dbo.CustomerPortalRequest AS r
    WHERE r.CustomerPortalRequestId = @CustomerPortalRequestId
      AND r.IsDeleted = 0;

    IF @CurrentStatus IS NULL
        THROW 52012, 'No such request.', 1;

    IF @CurrentStatus IN (N'Approved', N'Rejected', N'Cancelled', N'Done')
        THROW 52013, 'This request has already been resolved.', 1;

    DECLARE @MbaUserId INT;
    SELECT TOP (1) @MbaUserId = u.ID FROM dbo.Users AS u
    WHERE LOWER(LTRIM(RTRIM(u.Email))) = @Email;

    IF @MbaUserId IS NULL
    BEGIN
        /* Not MBA staff - then it must be the customer who filed it, cancelling it. */
        IF NOT EXISTS (SELECT 1 FROM dbo.CustomerContacts AS cc
                       WHERE cc.IsDeleted = 0
                         AND cc.CustomerId = @OwnerCustomerId
                         AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @Email)
            THROW 52014, 'This request does not belong to the caller.', 1;

        IF @Status <> N'Cancelled'
            THROW 52015, 'A customer may only cancel their own request.', 1;
    END

    UPDATE dbo.CustomerPortalRequest
    SET Status           = @Status,
        ResolutionNotes  = COALESCE(@ResolutionNotes, ResolutionNotes),
        ResolvedByUserId = @MbaUserId,
        ResolvedDate     = IIF(@Status IN (N'Approved', N'Rejected', N'Cancelled', N'Done'),
                               SYSUTCDATETIME(), NULL)
    WHERE CustomerPortalRequestId = @CustomerPortalRequestId;

    SELECT @CustomerPortalRequestId AS customerPortalRequestId, @Status AS status;
END
GO

/* ================= dbo.ResolveOrderApprovalRequest ================= */
/*
    dbo.ResolveOrderApprovalRequest
    -------------------------------
    Consume an approve/reject link: record the customer's answer and move the order to
    ClientConfirmationStatus 'Confirmed' (מאושר) or 'Rejected' (נדחה).

    This is the only place the two writes happen together, and they happen in one transaction —
    an answer that is stored without moving the order (or the other way round) would leave the
    coordinator screen lying about what the customer said.

    The link is consumed atomically: the UPDATE that stamps RespondedAt also filters on
    RespondedAt IS NULL, so two concurrent clicks (a double-click, or the customer forwarding the
    mail) produce exactly one decision — the second one comes back 'AlreadyAnswered'.

    Rejection notes are ALSO written to OrderWorkPlans.CustomerComment, because that is the column
    the coordinator screen already renders (see dbo.AssignOrderComment / the CustomerComment column
    in dbo.GetWorkPlanData) — otherwise the coordinator would have to open a second screen to learn
    why the customer said no.

    Parameters:
      @TokenHash VARBINARY(32)  (required)
      @Decision  NVARCHAR(10)   (required) 'Confirmed' | 'Rejected'
      @Notes     NVARCHAR(1000) = NULL   הערות הלקוח
      @Ip        NVARCHAR(45)   = NULL

    Returns one row:
      Status ∈ { 'Resolved', 'AlreadyAnswered', 'Expired', 'Invalidated', 'NotFound',
                 'BadDecision', 'StatusMissing' }
      OrderApprovalRequestId, OrderWorkPlanId, OrderNumber, Decision, ResponseNotes
*/
CREATE OR ALTER PROCEDURE dbo.ResolveOrderApprovalRequest
    @TokenHash VARBINARY(32),
    @Decision  NVARCHAR(10),
    @Notes     NVARCHAR(1000) = NULL,
    @Ip        NVARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status                 NVARCHAR(20),
            @OrderApprovalRequestId BIGINT,
            @OrderWorkPlanId        INT,
            @OrderNumber            NVARCHAR(20);

    IF @Decision NOT IN (N'Confirmed', N'Rejected')
    BEGIN
        SELECT CAST(N'BadDecision' AS NVARCHAR(20)) AS Status,
               CAST(NULL AS BIGINT)                 AS OrderApprovalRequestId,
               CAST(NULL AS INT)                    AS OrderWorkPlanId,
               CAST(NULL AS NVARCHAR(20))           AS OrderNumber,
               CAST(NULL AS NVARCHAR(10))           AS Decision,
               CAST(NULL AS NVARCHAR(1000))         AS ResponseNotes;
        RETURN;
    END

    /* The status id is looked up, never hard-coded — Statuses.StatusId is IDENTITY and differs
       between STG and PROD. */
    DECLARE @StatusId INT =
    (
        SELECT s.StatusId
        FROM dbo.Statuses AS s
        JOIN dbo.StatusesCategories AS c ON c.StatusCategoryId = s.StatusCategoryId
        WHERE c.StatusDescriptionENG = N'ClientConfirmationStatus'
          AND s.StatusDescriptionENG = @Decision
    );

    IF @StatusId IS NULL
    BEGIN
        SELECT CAST(N'StatusMissing' AS NVARCHAR(20)) AS Status,
               CAST(NULL AS BIGINT)                   AS OrderApprovalRequestId,
               CAST(NULL AS INT)                      AS OrderWorkPlanId,
               CAST(NULL AS NVARCHAR(20))             AS OrderNumber,
               CAST(NULL AS NVARCHAR(10))             AS Decision,
               CAST(NULL AS NVARCHAR(1000))           AS ResponseNotes;
        RETURN;
    END

    DECLARE @Now         DATETIME2(3)   = SYSUTCDATETIME();
    DECLARE @CleanNotes  NVARCHAR(1000) = NULLIF(LTRIM(RTRIM(@Notes)), N'');
    DECLARE @Answered    TABLE (OrderApprovalRequestId BIGINT,
                                OrderWorkPlanId        INT,
                                OrderNumber            NVARCHAR(20));

    BEGIN TRANSACTION;

        /* Consume the link. The RespondedAt IS NULL predicate is the concurrency guard. */
        UPDATE r
        SET r.RespondedAt   = @Now,
            r.Decision      = @Decision,
            r.ResponseNotes = @CleanNotes,
            r.ResponseIp    = @Ip
        OUTPUT inserted.OrderApprovalRequestId, inserted.OrderWorkPlanId, inserted.OrderNumber
        INTO @Answered
        FROM dbo.OrderApprovalRequest AS r
        WHERE r.TokenHash     = @TokenHash
          AND r.RespondedAt   IS NULL
          AND r.InvalidatedAt IS NULL
          AND r.ExpiresAt     > @Now;

        SELECT @OrderApprovalRequestId = a.OrderApprovalRequestId,
               @OrderWorkPlanId        = a.OrderWorkPlanId,
               @OrderNumber            = a.OrderNumber
        FROM @Answered AS a;

        IF @OrderApprovalRequestId IS NOT NULL
        BEGIN
            UPDATE dbo.OrderWorkPlans
            SET ClientConfirmationStatusId = @StatusId,
                UpdatedDate                = SYSDATETIME()
            WHERE OrderWorkPlanId = @OrderWorkPlanId;

            /* Surface the reason for a rejection where the coordinator already looks. */
            IF @Decision = N'Rejected' AND @CleanNotes IS NOT NULL
                UPDATE dbo.OrderWorkPlans
                SET CustomerComment = @CleanNotes
                WHERE OrderWorkPlanId = @OrderWorkPlanId;

            SET @Status = N'Resolved';
        END

    COMMIT TRANSACTION;

    /* Nothing was consumed — say precisely why, so the page can explain it to the customer. */
    IF @Status IS NULL
    BEGIN
        SELECT TOP (1)
            @Status                 = CASE
                                          WHEN r.RespondedAt   IS NOT NULL THEN N'AlreadyAnswered'
                                          WHEN r.InvalidatedAt IS NOT NULL THEN N'Invalidated'
                                          ELSE N'Expired'
                                      END,
            @OrderApprovalRequestId = r.OrderApprovalRequestId,
            @OrderWorkPlanId        = r.OrderWorkPlanId,
            @OrderNumber            = r.OrderNumber
        FROM dbo.OrderApprovalRequest AS r
        WHERE r.TokenHash = @TokenHash;

        IF @Status IS NULL
            SET @Status = N'NotFound';
    END

    /* Scalar sub-queries, not a join — this must return exactly one row even for 'NotFound'. */
    SELECT @Status                 AS Status,
           @OrderApprovalRequestId AS OrderApprovalRequestId,
           @OrderWorkPlanId        AS OrderWorkPlanId,
           @OrderNumber            AS OrderNumber,
           (SELECT TOP (1) r.Decision
            FROM dbo.OrderApprovalRequest AS r
            WHERE r.TokenHash = @TokenHash)      AS Decision,
           (SELECT TOP (1) r.ResponseNotes
            FROM dbo.OrderApprovalRequest AS r
            WHERE r.TokenHash = @TokenHash)      AS ResponseNotes;
END
GO

/* ================= dbo.SaveSensorTableColumnPreferences ================= */
CREATE OR ALTER PROCEDURE dbo.SaveSensorTableColumnPreferences
      @UserEmail        NVARCHAR(50),
      @ColumnVisibility NVARCHAR(MAX) = NULL,
      @ColumnOrder      NVARCHAR(MAX) = NULL
    AS
    BEGIN
      SET NOCOUNT ON;

      DECLARE @UserId INT;
      SELECT TOP 1 @UserId = ID
      FROM dbo.Users
      WHERE Email = @UserEmail AND IsActive = 1;

      IF @UserId IS NULL
      BEGIN
        RAISERROR('User not found: %s', 16, 1, @UserEmail);
        RETURN;
      END

      IF EXISTS (SELECT 1 FROM dbo.UserSensorTablePreferences WHERE UserId = @UserId)
      BEGIN
        UPDATE dbo.UserSensorTablePreferences
        SET
          ColumnVisibility = ISNULL(@ColumnVisibility, ColumnVisibility),
          ColumnOrder      = ISNULL(@ColumnOrder, ColumnOrder),
          UpdatedDate      = GETDATE(),
          UpdateUserID     = @UserId
        WHERE UserId = @UserId;
      END
      ELSE
      BEGIN
        INSERT INTO dbo.UserSensorTablePreferences
          (UserId, ColumnVisibility, ColumnOrder, UpdatedDate, UpdateUserID)
        VALUES
          (@UserId, @ColumnVisibility, @ColumnOrder, GETDATE(), @UserId);
      END
    END
GO

/* ================= dbo.SaveSensorTableLockedColumns ================= */
CREATE OR ALTER PROCEDURE dbo.SaveSensorTableLockedColumns
      @LockedColumns     NVARCHAR(MAX),
      @LoggedInUserEmail NVARCHAR(50)
    AS
    BEGIN
      SET NOCOUNT ON;

      DECLARE @UserRoleId INT;
      DECLARE @UserId     INT;

      SELECT TOP 1
        @UserId     = ID,
        @UserRoleId = UserRoleId
      FROM dbo.Users
      WHERE Email = @LoggedInUserEmail AND IsActive = 1;

      -- Enforce manager-only access
      IF @UserRoleId NOT IN (1, 2, 4)
      BEGIN
        RAISERROR('Access denied: only managers can lock sensor table columns', 16, 1);
        RETURN;
      END

      IF EXISTS (SELECT 1 FROM dbo.UserSensorTablePreferences WHERE UserId IS NULL)
      BEGIN
        UPDATE dbo.UserSensorTablePreferences
        SET
          LockedColumns = @LockedColumns,
          UpdatedDate   = GETDATE(),
          UpdateUserID  = @UserId
        WHERE UserId IS NULL;
      END
      ELSE
      BEGIN
        -- First time: create the global row
        INSERT INTO dbo.UserSensorTablePreferences
          (UserId, LockedColumns, UpdatedDate, UpdateUserID)
        VALUES
          (NULL, @LockedColumns, GETDATE(), @UserId);
      END
    END
GO

/* ================= dbo.SetOrderApprovalPriorityResult ================= */
/*
    dbo.SetOrderApprovalPriorityResult
    ----------------------------------
    Record what happened when the Priority external-calibration API ("פתיחת כיולי חוץ") was called
    after a customer approved an order.

    The Priority call is deliberately NOT part of dbo.ResolveOrderApprovalRequest: the customer's
    answer must be durable even when Priority is unreachable. The app calls Priority after the
    answer is committed and stamps the outcome here, so a failed call is visible and can be retried
    without asking the customer again.

    Parameters:
      @OrderApprovalRequestId BIGINT         (required)
      @DocumentNumber         NVARCHAR(50)   = NULL  Priority DOCNO on success
      @Error                  NVARCHAR(1000) = NULL  error text on failure

    Returns one row: Status ∈ { 'Updated', 'NotFound' }.
*/
CREATE OR ALTER PROCEDURE dbo.SetOrderApprovalPriorityResult
    @OrderApprovalRequestId BIGINT,
    @DocumentNumber         NVARCHAR(50)   = NULL,
    @Error                  NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.OrderApprovalRequest
    SET PriorityDocumentNumber = @DocumentNumber,
        PriorityError          = @Error,
        PriorityCompletedAt    = SYSUTCDATETIME()
    WHERE OrderApprovalRequestId = @OrderApprovalRequestId;

    SELECT CAST(CASE WHEN @@ROWCOUNT = 1 THEN N'Updated' ELSE N'NotFound' END AS NVARCHAR(20)) AS Status;
END
GO
