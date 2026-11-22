/*
    dbo.AssignMeasurmentPointsToCalibrationCycle - saves the measurement points (and their manually
    entered values) of one or more calibration cycles. Called only by the app route
    devices.assignMeasurmentPointsToCalibrationCycle.

    MBA-522 (2026-11-16): a saved point used to be identified by cycle + sensor + channel. That key
    is not unique for PLACEHOLDER points - points with no channel assigned (ChannelNumber 99, shown
    blank in the sensors table) or on the NO_SENSOR placeholder sensor. Several of those can sit on
    one sensor, and they carry real values: on STAGE, line 3019 (cycle 2026-11-08 09:25:02) has T1
    and an unnamed point on sensor 152 / channel 99, both with master 21, measured 21, uncertainty
    5. The first save inserted both rows; every later save failed with "The MERGE statement
    attempted to UPDATE or DELETE the same row more than once".

    Placeholder points are now identified by cycle + sensor + channel + point name (trimmed, blank
    = unnamed). Real points keep cycle + sensor + channel. A request that names the same point twice
    under that key is refused with 51000 before anything is written, so the caller gets a message
    naming the clash instead of the MERGE error.

    NO_SENSOR is looked up by MabaID, never by id: identity ids differ between STAGE and PROD.

    Consequences of the placeholder key, accepted on purpose:
    - Renaming a placeholder point soft-deletes its row and inserts a new one (new id). Nothing
      reads MeasurmentPointsToCalibrationCycleId or the deleted rows (checked 2026-11-16: the app
      reads live rows only, DeleteCalibrationCycle works per cycle). A real point keeps its row.
    - The key compares names case- and accent-insensitively (column collation CI_AI), so T1 and t1
      on one placeholder sensor are one point. The change test compares names in BIN2, so a re-
      spelling (t1 -> T1) is still written.
    - A cycle that already holds two live rows under one key (written by the old body's first save)
      is refused on every save until the user removes or renames one of the points; before this
      change those saves failed with the MERGE error. Counted 2026-11-16: PROD 0 (28 live cycle
      points, none on channel 99). STAGE had two, both test data (line 155: three unnamed NO_SENSOR
      points; line 591: two T9 on channel 10); the extra copies were soft-deleted the same day
      (backup dbo._bak_MBA522_DupCyclePoints_20261116). The order-line side is MBA-1039.
    - NO_SENSOR does not exist on PROD (2026-11-16). There, only channel 99 marks a placeholder.

    The soft delete is scoped per (line, cycle) pair from the request, not per line x per date.

    MBA-800 (2026-11-19): a point may carry "ValueRole" (1 = temperature, 2 = the chamber's second
    value, RH) and "PairId" (the GUID its order-line point carries; the temperature and RH points of
    one position share it). database/schema/dbo.MeasurmentPointsToCalibrationCycles.PairIdValueRole.sql
    has the why. Both are written exactly as sent, NULL included; omitted = not stated, which is
    every point sent before this change. A role other than 1 or 2, or a PairId that is not a GUID,
    is refused with 51000 before anything is written, like the clash check. So is a pair that does
    not hold together, checked the same way as dbo.AssignMeasurmentPointsToOrderDetailsItems does
    (review of PR #62: the payload comes from the app, not from the order line): an RH point without
    a PairId, or a PairId without exactly one temperature and one RH point of one sensor on two
    different channels in its line and cycle. Refused rather than skipped, like everything here.
*/
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

        /* Placeholder sensor(s): no physical sensor behind the point */
        DECLARE @NoSensor TABLE (Id INT PRIMARY KEY);
        INSERT @NoSensor (Id)
        SELECT md.ID FROM dbo.MeasurementDevices AS md WHERE md.MabaID = N'NO_SENSOR';

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
            MeasuredValueUnitId INT,
            /* MBA-800 */
            PairIdText NVARCHAR(50),
            PairId UNIQUEIDENTIFIER,
            ValueRoleText NVARCHAR(50),
            ValueRole TINYINT,
            IsPlaceholder BIT NOT NULL DEFAULT 0,
            /* the point name as part of the key: trimmed, '' = unnamed; '' for real points */
            PointKeyName NVARCHAR(100) COLLATE Latin1_General_100_CI_AI_SC NOT NULL DEFAULT N''
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
            MeasuredValueUnitId,
            PairIdText,
            PairId,
            ValueRoleText,
            ValueRole
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
            c.MeasuredValueUnitId,
            NULLIF(LTRIM(RTRIM(c.PairId)), N''),
            TRY_CONVERT(UNIQUEIDENTIFIER, NULLIF(LTRIM(RTRIM(c.PairId)), N'')),
            NULLIF(LTRIM(RTRIM(c.ValueRole)), N''),
            TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(c.ValueRole)), N''))
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
            MeasuredValueUnitId INT,
            PairId NVARCHAR(50),        /* MBA-800: text, so a bad value gets a message, not error 8169 */
            ValueRole NVARCHAR(50)      /* MBA-800 */
        ) AS c

        /* MBA-800: refuse a malformed role or pair before writing anything */
        DECLARE @BadPair NVARCHAR(400);
        SELECT TOP (1) @BadPair =
              N'Order line ' + CAST(pd.OrderDetailsItemId AS NVARCHAR(20))
            /* COLLATE: the name column is Latin1 (see #parsedData), the two text columns are not */
            + N', point "' + COALESCE(NULLIF(LTRIM(RTRIM(pd.MeasurmentPointName)), N''), N'(unnamed)') COLLATE DATABASE_DEFAULT + N'": '
            + CASE WHEN pd.ValueRoleText IS NOT NULL AND (pd.ValueRole IS NULL OR pd.ValueRole NOT IN (1, 2))
                   THEN N'ValueRole must be 1 (temperature) or 2 (RH), got "' + pd.ValueRoleText + N'".'
                   ELSE N'PairId is not a GUID: "' + pd.PairIdText + N'".' END
        FROM #parsedData AS pd
        WHERE (pd.ValueRoleText IS NOT NULL AND (pd.ValueRole IS NULL OR pd.ValueRole NOT IN (1, 2)))
           OR (pd.PairIdText IS NOT NULL AND pd.PairId IS NULL);

        /* The message quotes the caller's text; THROW reads a lone % as a format code and returns
           an empty message (seen on STAGE), so double it. */
        IF @BadPair IS NOT NULL
        BEGIN
            SET @BadPair = REPLACE(@BadPair, N'%', N'%%');
            THROW 51000, @BadPair, 1;
        END

        /* The pair's makeup, as the order-line save checks it (review of PR #62): the payload comes
           from the app, so nothing guarantees it is a copy of the order line's points. An RH point
           needs its PairId; a PairId carries one temperature and one RH point of one sensor on two
           different channels, per line and cycle. */
        SELECT TOP (1) @BadPair =
              N'Order line ' + CAST(pd.OrderDetailsItemId AS NVARCHAR(20))
            + N', point "' + COALESCE(NULLIF(LTRIM(RTRIM(pd.MeasurmentPointName)), N''), N'(unnamed)') COLLATE DATABASE_DEFAULT
            + N'": an RH point (ValueRole 2) needs the PairId of the temperature point at the same position.'
        FROM #parsedData AS pd
        WHERE pd.ValueRole = 2 AND pd.PairId IS NULL;

        IF @BadPair IS NULL
            SELECT TOP (1) @BadPair =
                  N'Order line ' + CAST(g.OrderDetailsItemId AS NVARCHAR(20))
                + N', cycle ' + CONVERT(NVARCHAR(19), g.CalibrationCycleStartDate, 120)
                + N': PairId ' + CONVERT(NVARCHAR(36), g.PairId)
                + N' needs exactly one temperature point (ValueRole 1) and one RH point (ValueRole 2), on one sensor and two different channels.'
            FROM (SELECT OrderDetailsItemId, CalibrationCycleStartDate, PairId
                  FROM #parsedData
                  WHERE PairId IS NOT NULL
                  GROUP BY OrderDetailsItemId, CalibrationCycleStartDate, PairId
                  HAVING COUNT(*) <> 2
                      OR SUM(CASE WHEN ValueRole = 1 THEN 1 ELSE 0 END) <> 1
                      OR SUM(CASE WHEN ValueRole = 2 THEN 1 ELSE 0 END) <> 1
                      OR COUNT(DISTINCT SensorMeasurementDeviceId) <> 1
                      OR COUNT(DISTINCT ChannelNumber) <> 2) AS g
            ORDER BY g.OrderDetailsItemId, g.CalibrationCycleStartDate;

        IF @BadPair IS NOT NULL
        BEGIN
            SET @BadPair = REPLACE(@BadPair, N'%', N'%%');
            THROW 51000, @BadPair, 1;
        END

        UPDATE pd
        SET IsPlaceholder = 1,
            PointKeyName = LTRIM(RTRIM(COALESCE(pd.MeasurmentPointName, N'')))
        FROM #parsedData AS pd
        WHERE pd.ChannelNumber = 99
           OR pd.SensorMeasurementDeviceId IN (SELECT Id FROM @NoSensor)

        /* The same point twice in one request: refuse before writing anything */
        DECLARE @Clash NVARCHAR(400);
        SELECT TOP (1) @Clash =
              N'Order line ' + CAST(pd.OrderDetailsItemId AS NVARCHAR(20))
            + N', cycle ' + CONVERT(NVARCHAR(19), pd.CalibrationCycleStartDate, 120)
            + N': two points share sensor ' + CAST(pd.SensorMeasurementDeviceId AS NVARCHAR(20))
            + N', channel ' + CAST(pd.ChannelNumber AS NVARCHAR(20))
            + CASE WHEN MAX(CAST(pd.IsPlaceholder AS INT)) = 1
                   THEN N' and point name "' + pd.PointKeyName + N'"' ELSE N'' END
            + N' (' + STRING_AGG(COALESCE(NULLIF(LTRIM(RTRIM(pd.MeasurmentPointName)), N''), N'(unnamed)'), N', ') + N').'
        FROM #parsedData AS pd
        WHERE pd.OrderDetailsItemId IS NOT NULL
          AND pd.CalibrationCycleStartDate IS NOT NULL
          AND pd.ChannelNumber IS NOT NULL
          AND pd.SensorMeasurementDeviceId IS NOT NULL
        GROUP BY pd.OrderDetailsItemId, pd.CalibrationCycleStartDate, pd.SensorMeasurementDeviceId,
                 pd.ChannelNumber, pd.PointKeyName
        HAVING COUNT(*) > 1
        ORDER BY pd.OrderDetailsItemId, pd.CalibrationCycleStartDate, pd.SensorMeasurementDeviceId,
                 pd.ChannelNumber, pd.PointKeyName;

        IF @Clash IS NOT NULL
            THROW 51000, @Clash, 1;

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
               AND (pd.IsPlaceholder = 0
                    OR pd.PointKeyName = LTRIM(RTRIM(COALESCE(dest.MeasurmentPointName, N''))))
        WHERE dest.IsDeleted = 0
          AND pd.SensorMeasurementDeviceId IS NULL
          AND EXISTS (SELECT 1 FROM #parsedData AS s
                      WHERE s.OrderDetailsItemId = dest.OrderDetailsItemId
                        AND s.CalibrationCycleStartDate = dest.CalibrationCycleStartDate)

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
                d.MeasuredValueUnitId,
                d.PairId,
                d.ValueRole,
                d.IsPlaceholder,
                d.PointKeyName
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
             AND (source.[IsPlaceholder] = 0
                  OR source.[PointKeyName] = LTRIM(RTRIM(COALESCE(dest.[MeasurmentPointName], N''))))
        WHEN MATCHED AND (
                   COALESCE(dest.[MeasurmentPointName],'') COLLATE Latin1_General_100_BIN2
                       <> COALESCE(source.[MeasurmentPointName],'') COLLATE Latin1_General_100_BIN2
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
                /* MBA-800: NULL-safe */
                OR NOT EXISTS (SELECT dest.[PairId], dest.[ValueRole] INTERSECT SELECT source.[PairId], source.[ValueRole])
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
                ,dest.[PairId] = source.[PairId]          /* MBA-800 */
                ,dest.[ValueRole] = source.[ValueRole]    /* MBA-800 */
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
                  [MeasuredValueUnitId],
                  [PairId],
                  [ValueRole]
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
                ,source.[PairId]
                ,source.[ValueRole]
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
