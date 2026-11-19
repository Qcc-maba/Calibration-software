CREATE OR ALTER PROCEDURE [dbo].[AssignMeasurmentPointsToOrderDetailsItems]
@LoggedInUserEmail NVARCHAR(100),
@Data NVARCHAR(MAX),
@ReturnSummary BIT = 0,
@SummaryAsJson BIT = 0
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 31/07/2025
-- Description:	Populate table MeasurmentPointsToOrderDetailsItems during calibration process setup
-- 2026-08-13 hardening: the calibration wizard was getting a bare 500 from this proc whenever the
-- payload was slightly off. Reproduced on STAGE: an empty MeasurmentPointCoordX -> 8114 (nvarchar
-- to decimal), a comma decimal "4,35" -> 8114, a coordinate >= 1,000,000 -> 8115 (overflow), and an
-- empty SensorMeasurementDeviceId -> 547 (FK violation). The FE types all of these as z.string()
-- with no numeric validation, so an empty string passes zod and explodes here.
-- Now: every decimal is read out of the JSON as text and coerced with TRY_CONVERT (a comma decimal
-- is accepted, anything unparseable becomes NULL), and a point whose sensor id does not exist in
-- dbo.MeasurementDevices is skipped instead of breaking the whole save.
-- TRADE-OFF, deliberate: this turns a total failure into a partial save, so a malformed point is
-- dropped quietly. The proper fix is on the FE (send numbers, not strings) — see the Jira ticket.
-- 2026-08-24 (MBA-902) two follow-ups to that hardening, both visible on the chamber diagram.
--   THE EMPTY CIRCLE. 220 of the 366 saved points carry MeasurmentPointName = ''. The column is
--   NOT NULL, so a blank name is stored rather than refused, and the diagram draws a circle with
--   nothing in it. The 146 points that do have a name all follow one convention, T1..T11 - and T1
--   appears once against sixteen each for T2..T10, so it is the FIRST point that arrives unnamed.
--   A blank name is now filled in as T<n>, numbered per order item and skipping every T number
--   that item already uses, so a placed point always has something to draw.
--   THE POINT THAT VANISHES. The partial-save trade-off below is right - one bad point must not
--   take the whole save down - but it was silent. An item declaring two points on the first page
--   and showing one on the diagram looks like a rendering bug rather than a dropped record. Pass
--   @ReturnSummary = 1 to get back what was received, saved and skipped, and why. Off by default:
--   the caller uses $executeRaw, which cannot take a result set.
-- ON ChannelNumber, because it is easy to confuse with the point count on the first page - they
--   are different things and there are three of them in the chain:
--     OrderDetailsItems.MeasurementPoints  how many points the calibration requires
--     ChannelsToSensorRelation             which of the logger's channels that sensor occupies
--     this table's ChannelNumber           which ONE of those channels this point is wired to
--   Measured on STAGE: of the 366 saved points, 128 carry a channel that really is one of the
--   sensor's assigned channels, which is what confirms the column means a logger channel and not a
--   point index. The other 238 do not, and they split cleanly: 167 carry ChannelNumber = 99 on a
--   sensor that has NO channels assigned at all. 99 is not an arbitrary placeholder - it is what
--   gets written when the sensor-to-logger step was never completed and there was nothing to pick.
--   A further 12 points name a channel their sensor does not have, which is a genuine mis-wiring.
--   The procedure reports all of this through @ReturnSummary but does NOT refuse the point: a
--   calibrator has physically placed it in the chamber, and dropping that is worse than storing it
--   with a channel that still needs fixing.
-- 2026-08-24, same round: OrderDetailsItemId, SensorMeasurementDeviceId and ChannelNumber were
--   still typed INT in the OPENJSON WITH clauses. A non-numeric value in any of them raised error
--   245 and the caller saw a bare Internal Server Error - exactly the failure mode the 2026-08-13
--   hardening removed for the coordinates but never applied to the ids. Reproduced on STAGE with
--   OrderDetailsItemId = 'abc' and SensorMeasurementDeviceId = 'abc'. All three are now read as
--   text and coerced with TRY_CONVERT, so a bad id skips its point and is reported instead of
--   taking the whole save down.
-- 2026-10-15 (MBA-904) THE SUMMARY ARRIVES AS ONE RESULT SET. @ReturnSummary = 1 returns three
--   result sets (totals, skipped points, channel warnings), and the only caller reads it through
--   Prisma, which hands back just one of them: measured on STAGE, it returns the LAST NON-EMPTY set.
--   Run against this procedure in a rolled-back transaction: one point without a channel came back
--   correctly as the skipped row, but as soon as any point also drew a channel warning, the caller
--   received only the warnings - it toasted the warned points as "not saved" (they were saved) and
--   the point that really was skipped was never mentioned. The totals set is never seen at all.
--   Pass @SummaryAsJson = 1 instead: exactly ONE row with ONE column, `summary`, holding
--     { pointsReceived, pointsSaved, pointsSkipped, pointsWithAnInvalidChannel,
--       skipped:  [ { orderDetailsItemId, measurementPointName, sensorMeasurementDeviceId,
--                     channelNumber, reason } ],
--       warnings: [ { ...same keys..., warning } ] }
--   Both arrays are always present, empty when there is nothing to report, so the caller parses one
--   value and never has to guess which set it was given. It takes precedence over @ReturnSummary,
--   which keeps its three sets unchanged so the caller deployed today keeps working until it
--   switches; retire it once nothing passes it.
--   Same round, from review: a point is now listed in `warnings` only when the save keeps it - an
--   unknown sensor or an unreadable coordinate used to put the same point in both lists. And an
--   empty-string id ('' for the order item, sensor or channel) now counts as missing: TRY_CONVERT
--   turned '' into 0, which saved the point against order item 0, or on channel 0, and reported it
--   as saved. Never seen on STAGE (no item-0 rows); the app sends numbers, but the guard is cheap.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MBA-904
-- 2026-11-19 (MBA-800) TEMPERATURE + RH POSITIONS. A chamber calibrated for temperature and RH has
--   positions that measure temperature only and positions that also measure RH ("9 temperature
--   sensors and only 1 that also measures RH", Nofar, Jira 38328). A T/RH sensor reports the two
--   readings on two channels, so such a position is two points of the same sensor. Each point may
--   now carry:
--     "ValueRole": 1 = temperature, 2 = RH (the chamber's second value). Omitted = not stated,
--                  which is every point the app sent before this change.
--     "PairId":    a GUID shared by the temperature and the RH point of one position.
--   Both are written exactly as sent, NULL included, so turning a position back to temperature
--   only (the app stops sending the RH point and the PairId) leaves no stale pair behind. The only
--   caller is the chamber's logger setup (LoggerConfigScreen); the sensors flow saves through
--   dbo.AssignMeasurmentPointsToOrderDetailsItemsV2.
--   The RH point always takes the name of its temperature point: they are one position on the
--   diagram. It is left out of the blank-name numbering for the same reason.
--   A pair that does not hold together is skipped and reported like any other bad point (reason
--   in `skipped`), not refused: a role that is not 1 or 2, a PairId that is not a GUID, an RH point
--   without a PairId, or a PairId that does not carry exactly one temperature and one RH point of
--   one sensor on two different channels.
--   When one point of a sound pair is skipped for another reason (say an unknown sensor), its
--   partner is skipped too ("its pair partner was skipped"), so no PairId is ever stored on one row
--   (review of PR #62; the same rule ...V2 has).
-- =============================================
--Example of json needs to be passed
--'
--{
--  "OrderDetailsItemId": "1",
--  "Points": [
--    {
--      "MeasurmentPointName": "T1",
--      "MeasurmentPointCoordX": "4.35",
--      "MeasurmentPointCoordY": "3.35",
--      "SensorMeasurementDeviceId": "1",
--      "ChannelNumber": 1,
--      "UncertancyValue": 2,
--		"MasterValue": 36.44,
--		"MasterValueUnitId": 1,
--		"MeasuredValue": 35,
--		"MeasuredValueUnitId": 1,
--		"StabilityValue": 2,
--		"AdditionalValue": 33,
--		"AdditionalValueUnitId": 3
--    },
--    {
--      "MeasurmentPointName": "T2",
--      "MeasurmentPointCoordX": "8.35",
--      "MeasurmentPointCoordY": "4.25",
--      "SensorMeasurementDeviceId": "1",
--      "ChannelNumber": 15,
--      "UncertancyValue": 2,
--		"MasterValue": 39.44,
--		"MasterValueUnitId": 1,
--		"MeasuredValue": 35,
--		"MeasuredValueUnitId": 1,
--		"StabilityValue": 2,
--		"AdditionalValue": 33,
--		"AdditionalValueUnitId":3
--    },
--    {
--      "MeasurmentPointName": "T3",
--      "MeasurmentPointCoordX": "12.35",
--      "MeasurmentPointCoordY": "5.3",
--      "SensorMeasurementDeviceId": "2",
--      "ChannelNumber": 17,
--      "UncertancyValue": 2,
--		"MasterValue": 38.44,
--		"MasterValueUnitId": 1,
--		"MeasuredValue": 35,
--		"MeasuredValueUnitId": 1,
--		"StabilityValue": 2,
--		"AdditionalValue": 33,
--		"AdditionalValueUnitId":3
--    }
--  ]
--}
--'


AS

BEGIN 

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

DROP TABLE IF EXISTS #parsedData

CREATE TABLE #parsedData
(
    RowId INT IDENTITY(1,1),   /* MBA-800: tells the two rows of a pair apart */
	OrderDetailsItemId INT,
    MeasurmentPointName NVARCHAR(100) COLLATE Latin1_General_100_CI_AI_SC,
    SensorMeasurementDeviceId INT,
    MeasurmentPointCoordX DECIMAL(10,4),
    MeasurmentPointCoordY DECIMAL(10,4),
	ChannelNumber INT,
	MasterValue DECIMAL(18,6)   /* MBA-811: the column is (18,6) */,
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
    PairProblem NVARCHAR(200)
)

INSERT #parsedData
(
	OrderDetailsItemId,
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
    /* MBA-904: NULLIF first - TRY_CONVERT(INT, N'') is 0, not NULL, so an empty id was saved as
       order item 0 / channel 0 instead of being skipped. */
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(d.OrderDetailsItemId)), N''))        AS OrderDetailsItemId,
    c.MeasurmentPointName,
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(c.SensorMeasurementDeviceId)), N'')) AS SensorMeasurementDeviceId,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.MeasurmentPointCoordX, ',', '.')) AS MeasurmentPointCoordX,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.MeasurmentPointCoordY, ',', '.')) AS MeasurmentPointCoordY,
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(c.ChannelNumber)), N''))             AS ChannelNumber,
    TRY_CONVERT(DECIMAL(18,6), REPLACE(c.MasterValue, ',', '.')) AS MasterValue,
    c.MasterValueUnitId,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.AdditionalValue, ',', '.')) AS AdditionalValue,
    c.AdditionalValueUnitId,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.StabilityValue, ',', '.')) AS StabilityValue,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.UncertancyValue, ',', '.')) AS UncertancyValue,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.MeasuredValue, ',', '.')) AS MeasuredValue,
    c.MeasuredValueUnitId,
    /* MBA-800: read as text, so a malformed value is reported instead of failing the save */
    NULLIF(LTRIM(RTRIM(c.PairId)), N'')                                       AS PairIdText,
    TRY_CONVERT(UNIQUEIDENTIFIER, NULLIF(LTRIM(RTRIM(c.PairId)), N''))        AS PairId,
    NULLIF(LTRIM(RTRIM(c.ValueRole)), N'')                                    AS ValueRoleText,
    TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(c.ValueRole)), N''))              AS ValueRole
FROM OPENJSON(@Data)
WITH (
    /* MBA-902: read as text and coerce. Typed INT here, a non-numeric id raised error 245 and the
       caller got a bare Internal Server Error - the same failure the 2026-08-13 hardening fixed for
       the coordinates but did not apply to the three id columns. */
    OrderDetailsItemId NVARCHAR(50),
    Points NVARCHAR(MAX) AS JSON
) AS d
OUTER APPLY OPENJSON(d.Points)
WITH (
    MeasurmentPointName NVARCHAR(100),
    MeasurmentPointCoordX NVARCHAR(50),
    MeasurmentPointCoordY NVARCHAR(50),
    SensorMeasurementDeviceId NVARCHAR(50),   /* MBA-902: was INT - see the outer WITH above */
    ChannelNumber NVARCHAR(50),               /* MBA-902: was INT */
	MasterValue NVARCHAR(50),
    MasterValueUnitId INT,
    AdditionalValue NVARCHAR(50),
    AdditionalValueUnitId INT,
    StabilityValue NVARCHAR(50),
    UncertancyValue NVARCHAR(50),
    MeasuredValue NVARCHAR(50),
    MeasuredValueUnitId INT,
    PairId NVARCHAR(50),                      /* MBA-800 */
    ValueRole NVARCHAR(50)                    /* MBA-800 */
) AS c

/* MBA-800: a Temperature + RH pair that does not hold together is skipped (see the header). */
UPDATE pd
SET PairProblem = CASE
        WHEN pd.ValueRoleText IS NOT NULL AND (pd.ValueRole IS NULL OR pd.ValueRole NOT IN (1, 2))
            THEN 'ValueRole must be 1 (temperature) or 2 (RH)'
        WHEN pd.PairIdText IS NOT NULL AND pd.PairId IS NULL
            THEN 'PairId is not a GUID'
        WHEN pd.ValueRole = 2 AND pd.PairId IS NULL
            THEN 'an RH point needs the PairId of the temperature point at the same position'
    END
FROM #parsedData AS pd;

/* A pair is one sensor on two different channels (review of PR #62): two rows on the same sensor
   and channel would both match one row in the MERGE below (error 8672, failing the whole save), and
   a T/RH reading pair always comes from one sensor. */
UPDATE pd
SET PairProblem = 'a Temperature + RH position needs exactly one temperature point (ValueRole 1) and one RH point (ValueRole 2) under its PairId, on one sensor and two different channels'
FROM #parsedData AS pd
JOIN (SELECT OrderDetailsItemId, PairId
      FROM #parsedData
      WHERE PairId IS NOT NULL
      GROUP BY OrderDetailsItemId, PairId
      HAVING COUNT(*) <> 2
          OR SUM(CASE WHEN ValueRole = 1 THEN 1 ELSE 0 END) <> 1
          OR SUM(CASE WHEN ValueRole = 2 THEN 1 ELSE 0 END) <> 1
          OR COUNT(DISTINCT SensorMeasurementDeviceId) <> 1
          OR COUNT(DISTINCT ChannelNumber) <> 2) AS bad
  ON bad.OrderDetailsItemId = pd.OrderDetailsItemId AND bad.PairId = pd.PairId
WHERE pd.PairProblem IS NULL;

/* Never half a pair (review of PR #62): when one row of a sound pair is skipped for another reason
   (no channel, unknown sensor, unreadable coordinate), its partner is skipped with it, so the table
   never holds a PairId with only one row - the state ...V2 refuses on purpose (PR #43). */
UPDATE pd
SET PairProblem = 'its pair partner was skipped'
FROM #parsedData AS pd
WHERE pd.PairId IS NOT NULL
  AND pd.PairProblem IS NULL
  AND EXISTS (SELECT 1 FROM #parsedData AS partner
              WHERE partner.OrderDetailsItemId = pd.OrderDetailsItemId
                AND partner.PairId = pd.PairId
                AND partner.RowId <> pd.RowId
                AND (   partner.ChannelNumber IS NULL
                     OR partner.SensorMeasurementDeviceId IS NULL
                     OR partner.MeasurmentPointCoordX IS NULL
                     OR partner.MeasurmentPointCoordY IS NULL
                     OR NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevices AS md
                                    WHERE md.ID = partner.SensorMeasurementDeviceId)));

/* MBA-902: a point with no name draws an empty circle. Give it the next free T number for its
   order item, counting the names already stored and the named points in this same payload.
   MBA-800: an RH point is not numbered - it takes its temperature point's name just below. */
;WITH Used AS
(
    SELECT OrderDetailsItemId, TRY_CAST(SUBSTRING(MeasurmentPointName, 2, 10) AS INT) AS Num
    FROM dbo.MeasurmentPointsToOrderDetailsItems
    WHERE IsDeleted = 0 AND MeasurmentPointName LIKE 'T[0-9]%'
    UNION ALL
    SELECT OrderDetailsItemId, TRY_CAST(SUBSTRING(MeasurmentPointName, 2, 10) AS INT)
    FROM #parsedData
    WHERE MeasurmentPointName LIKE 'T[0-9]%'
),
Base AS
(
    SELECT pd.OrderDetailsItemId, ISNULL(MAX(u.Num), 0) AS MaxUsed
    FROM #parsedData AS pd
    LEFT JOIN Used AS u ON u.OrderDetailsItemId = pd.OrderDetailsItemId
    GROUP BY pd.OrderDetailsItemId
),
Blanks AS
(
    SELECT pd.MeasurmentPointName, pd.OrderDetailsItemId,
           ROW_NUMBER() OVER (PARTITION BY pd.OrderDetailsItemId
                              ORDER BY pd.ChannelNumber, pd.MeasurmentPointCoordX,
                                       pd.MeasurmentPointCoordY) AS rn
    FROM #parsedData AS pd
    WHERE LTRIM(RTRIM(ISNULL(pd.MeasurmentPointName, ''))) = ''
      /* MBA-800. ISNULL: without it a row with no role compares unknown and is never numbered */
      AND NOT (ISNULL(pd.ValueRole, 0) = 2 AND pd.PairProblem IS NULL)
)
UPDATE b
SET MeasurmentPointName = 'T' + CAST(bs.MaxUsed + b.rn AS NVARCHAR(10))
FROM Blanks AS b
INNER JOIN Base AS bs ON bs.OrderDetailsItemId = b.OrderDetailsItemId;

/* MBA-800: the RH point of a position carries the temperature point's name - one position. */
UPDATE rh
SET MeasurmentPointName = t.MeasurmentPointName
FROM #parsedData AS rh
JOIN #parsedData AS t
  ON t.OrderDetailsItemId = rh.OrderDetailsItemId AND t.PairId = rh.PairId AND t.ValueRole = 1
WHERE rh.ValueRole = 2 AND rh.PairProblem IS NULL;

/* MBA-902: a point is wired to ONE of the channels its sensor occupies on the logger. Flag the
   ones that are not - reported, never refused; the point has been physically placed. */
DROP TABLE IF EXISTS #channelWarnings;
SELECT pd.OrderDetailsItemId, pd.MeasurmentPointName, pd.SensorMeasurementDeviceId, pd.ChannelNumber,
       CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.ChannelsToSensorRelation AS c
                             WHERE c.SensorMeasurementDeviceId = pd.SensorMeasurementDeviceId
                               AND c.IsDeleted = 0)
                 THEN 'this sensor has no channels assigned to any logger yet'
            ELSE 'channel is not one of the channels this sensor occupies'
       END AS Warning
INTO #channelWarnings
FROM #parsedData AS pd
/* MBA-904: only points the save keeps. A point that is also skipped (no order item, unreadable
   coordinate, unknown sensor) was listed in both, so the caller said "not saved" and "saved" for it. */
WHERE pd.OrderDetailsItemId IS NOT NULL
  AND pd.SensorMeasurementDeviceId IS NOT NULL
  AND pd.ChannelNumber IS NOT NULL
  AND pd.MeasurmentPointCoordX IS NOT NULL
  AND pd.MeasurmentPointCoordY IS NOT NULL
  AND pd.PairProblem IS NULL   /* MBA-800 */
  AND EXISTS (SELECT 1 FROM dbo.MeasurementDevices AS md WHERE md.ID = pd.SensorMeasurementDeviceId)
  AND NOT EXISTS (SELECT 1 FROM dbo.ChannelsToSensorRelation AS c
                  WHERE c.SensorMeasurementDeviceId = pd.SensorMeasurementDeviceId
                    AND c.ChannelNumber = pd.ChannelNumber
                    AND c.IsDeleted = 0);

/* MBA-902: what this save is about to drop, captured before the MERGE filters it away. */
DECLARE @Received INT = (SELECT COUNT(*) FROM #parsedData);

DROP TABLE IF EXISTS #skipped;
SELECT pd.OrderDetailsItemId, pd.MeasurmentPointName, pd.SensorMeasurementDeviceId, pd.ChannelNumber,
       CASE
           WHEN pd.OrderDetailsItemId IS NULL         THEN 'no order item supplied'
           WHEN pd.SensorMeasurementDeviceId IS NULL  THEN 'no sensor supplied'
           WHEN pd.ChannelNumber IS NULL              THEN 'no channel supplied'
           WHEN pd.MeasurmentPointCoordX IS NULL
             OR pd.MeasurmentPointCoordY IS NULL      THEN 'coordinate could not be read as a number'
           WHEN pd.PairProblem IS NOT NULL            THEN pd.PairProblem   /* MBA-800 */
           ELSE 'sensor does not exist'
       END AS Reason
INTO #skipped
FROM #parsedData AS pd
WHERE pd.OrderDetailsItemId IS NULL
   OR pd.ChannelNumber IS NULL
   OR pd.SensorMeasurementDeviceId IS NULL
   OR pd.MeasurmentPointCoordX IS NULL
   OR pd.MeasurmentPointCoordY IS NULL
   OR pd.PairProblem IS NOT NULL   /* MBA-800 */
   OR NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevices md WHERE md.ID = pd.SensorMeasurementDeviceId);

/*Apply soft delete to data which no longer valid*/
UPDATE dest
SET IsDeleted = 1,
    UpdatedDate = GETDATE()
FROM [dbo].[MeasurmentPointsToOrderDetailsItems] as dest 
LEFT JOIN #parsedData as pd
	ON pd.OrderDetailsItemId = dest.OrderDetailsItemId
	   AND pd.SensorMeasurementDeviceId = dest.SensorMeasurementDeviceId
	   AND pd.ChannelNumber = dest.ChannelNumber
WHERE dest.IsDeleted = 0 AND pd.SensorMeasurementDeviceId IS NULL
AND dest.OrderDetailsItemId IN (SELECT OrderDetailsItemId FROM #parsedData)
/*Insert new data or updating existing*/
MERGE INTO [dbo].[MeasurmentPointsToOrderDetailsItems] AS dest
USING (
	SELECT
		d.OrderDetailsItemId,
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
        d.ValueRole
	FROM #parsedData as d
	WHERE d.OrderDetailsItemId IS NOT NULL AND d.ChannelNumber IS NOT NULL AND d.SensorMeasurementDeviceId IS NOT NULL
	  AND d.PairProblem IS NULL   /* MBA-800 */
	  AND EXISTS (SELECT 1 FROM dbo.MeasurementDevices md WHERE md.ID = d.SensorMeasurementDeviceId)
	  /* Both coordinates are NOT NULL on the target table, so an unparseable one cannot be written.
	     Skip that point rather than defaulting to 0 — a point silently placed at (0,0) would show up
	     in the wrong spot on the chamber diagram, which is worse than a point that is missing. */
	  AND d.MeasurmentPointCoordX IS NOT NULL AND d.MeasurmentPointCoordY IS NOT NULL
	) AS source
	ON   dest.[OrderDetailsItemId] = source.[OrderDetailsItemId]
		 AND dest.[SensorMeasurementDeviceId] = source.[SensorMeasurementDeviceId]
		 AND dest.[ChannelNumber] = source.[ChannelNumber]
		 AND dest.[IsDeleted] = 0
    WHEN MATCHED AND ( 
	           COALESCE(dest.[MeasurmentPointName],'') <> COALESCE(source.[MeasurmentPointName],'')
			OR COALESCE(dest.[MeasurmentPointCoordX],0) <> COALESCE(source.[MeasurmentPointCoordX],1)
			OR COALESCE(dest.[MeasurmentPointCoordY],0) <> COALESCE(source.[MeasurmentPointCoordY],1)
            OR COALESCE(dest.[MasterValue],0) <> COALESCE(source.[MasterValue],0)
            OR COALESCE(dest.[MasterValueUnitId],0) <> COALESCE(source.[MasterValueUnitId],0)
            OR COALESCE(dest.[AdditionalValue],0) <> COALESCE(source.[AdditionalValue],0)
            OR COALESCE(dest.[AdditionalValueUnitId],0) <> COALESCE(source.[AdditionalValueUnitId],0)
            OR COALESCE(dest.[StabilityValue],0) <> COALESCE(source.[StabilityValue],0)
            OR COALESCE(dest.[UncertancyValue],0) <> COALESCE(source.[UncertancyValue],0)
            OR COALESCE(dest.[MeasuredValue],0) <> COALESCE(source.[MeasuredValue],0)
            OR COALESCE(dest.[MeasuredValueUnitId],0) <> COALESCE(source.[MeasuredValueUnitId],0)
            /* MBA-800: NULL-safe; a pair added or removed is a change */
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


/* MBA-904: the whole summary as one JSON value in one row - see the 2026-10-15 header note. */
IF @SummaryAsJson = 1
BEGIN
    SELECT
    (
        SELECT @Received                                     AS pointsReceived,
               @Received - (SELECT COUNT(*) FROM #skipped)   AS pointsSaved,
               (SELECT COUNT(*) FROM #skipped)               AS pointsSkipped,
               (SELECT COUNT(*) FROM #channelWarnings)       AS pointsWithAnInvalidChannel,
               JSON_QUERY(ISNULL((
                   SELECT OrderDetailsItemId        AS orderDetailsItemId,
                          MeasurmentPointName       AS measurementPointName,
                          SensorMeasurementDeviceId AS sensorMeasurementDeviceId,
                          ChannelNumber             AS channelNumber,
                          Reason                    AS reason
                   FROM #skipped
                   FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]')) AS skipped,
               /* saved, but the channel does not belong to the sensor - the calibration will read nothing */
               JSON_QUERY(ISNULL((
                   SELECT OrderDetailsItemId        AS orderDetailsItemId,
                          MeasurmentPointName       AS measurementPointName,
                          SensorMeasurementDeviceId AS sensorMeasurementDeviceId,
                          ChannelNumber             AS channelNumber,
                          Warning                   AS warning
                   FROM #channelWarnings
                   FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]')) AS warnings
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
    ) AS summary;
END
/* MBA-902: three result sets, opt-in. The caller reads them through Prisma $queryRaw, which keeps
   only the last non-empty set. Superseded by @SummaryAsJson (MBA-904); kept until the caller switches. */
ELSE IF @ReturnSummary = 1
BEGIN
    SELECT @Received                                     AS pointsReceived,
           @Received - (SELECT COUNT(*) FROM #skipped)   AS pointsSaved,
           (SELECT COUNT(*) FROM #skipped)               AS pointsSkipped,
           (SELECT COUNT(*) FROM #channelWarnings)       AS pointsWithAnInvalidChannel;

    SELECT OrderDetailsItemId        AS orderDetailsItemId,
           MeasurmentPointName       AS measurementPointName,
           SensorMeasurementDeviceId AS sensorMeasurementDeviceId,
           ChannelNumber             AS channelNumber,
           Reason                    AS reason
    FROM #skipped;

    /* saved, but the channel does not belong to the sensor - the calibration will read nothing */
    SELECT OrderDetailsItemId        AS orderDetailsItemId,
           MeasurmentPointName       AS measurementPointName,
           SensorMeasurementDeviceId AS sensorMeasurementDeviceId,
           ChannelNumber             AS channelNumber,
           Warning                   AS warning
    FROM #channelWarnings;
END

END
