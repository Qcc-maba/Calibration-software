CREATE OR ALTER PROCEDURE [dbo].[AssignMeasurmentPointsToOrderDetailsItems]
@LoggedInUserEmail NVARCHAR(100),
@Data NVARCHAR(MAX),
@ReturnSummary BIT = 0
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
-- JiraLink:
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
    MeasuredValueUnitId INT
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
    MeasuredValueUnitId
)

SELECT 
    TRY_CONVERT(INT, d.OrderDetailsItemId)        AS OrderDetailsItemId,
    c.MeasurmentPointName,
    TRY_CONVERT(INT, c.SensorMeasurementDeviceId) AS SensorMeasurementDeviceId,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.MeasurmentPointCoordX, ',', '.')) AS MeasurmentPointCoordX,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.MeasurmentPointCoordY, ',', '.')) AS MeasurmentPointCoordY,
    TRY_CONVERT(INT, c.ChannelNumber)             AS ChannelNumber,
    TRY_CONVERT(DECIMAL(18,6), REPLACE(c.MasterValue, ',', '.')) AS MasterValue,
    c.MasterValueUnitId,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.AdditionalValue, ',', '.')) AS AdditionalValue,
    c.AdditionalValueUnitId,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.StabilityValue, ',', '.')) AS StabilityValue,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.UncertancyValue, ',', '.')) AS UncertancyValue,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.MeasuredValue, ',', '.')) AS MeasuredValue,
    c.MeasuredValueUnitId
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
    MeasuredValueUnitId INT
) AS c
/* MBA-902: a point with no name draws an empty circle. Give it the next free T number for its
   order item, counting the names already stored and the named points in this same payload. */
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
)
UPDATE b
SET MeasurmentPointName = 'T' + CAST(bs.MaxUsed + b.rn AS NVARCHAR(10))
FROM Blanks AS b
INNER JOIN Base AS bs ON bs.OrderDetailsItemId = b.OrderDetailsItemId;

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
WHERE pd.SensorMeasurementDeviceId IS NOT NULL
  AND pd.ChannelNumber IS NOT NULL
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
           ELSE 'sensor does not exist'
       END AS Reason
INTO #skipped
FROM #parsedData AS pd
WHERE pd.OrderDetailsItemId IS NULL
   OR pd.ChannelNumber IS NULL
   OR pd.SensorMeasurementDeviceId IS NULL
   OR pd.MeasurmentPointCoordX IS NULL
   OR pd.MeasurmentPointCoordY IS NULL
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
        d.MeasuredValueUnitId
	FROM #parsedData as d
	WHERE d.OrderDetailsItemId IS NOT NULL AND d.ChannelNumber IS NOT NULL AND d.SensorMeasurementDeviceId IS NOT NULL
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


/* MBA-902: opt-in only - the caller uses $executeRaw, which cannot take a result set. */
IF @ReturnSummary = 1
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
