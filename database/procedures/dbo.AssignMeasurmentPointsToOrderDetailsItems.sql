-- Mirrors the definition deployed on STAGE (Calibrator) as of 2026-08-23.
-- Regenerated from the live object; see the in-body comments for what each change does
-- and why. Do not hand-edit without redeploying — this file is a mirror, not the source.
CREATE   PROCEDURE [dbo].[AssignMeasurmentPointsToOrderDetailsItems]
@LoggedInUserEmail NVARCHAR(100),
@Data NVARCHAR(MAX)
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
    c.MeasurmentPointName,
    c.SensorMeasurementDeviceId,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.MeasurmentPointCoordX, ',', '.')) AS MeasurmentPointCoordX,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.MeasurmentPointCoordY, ',', '.')) AS MeasurmentPointCoordY,
    c.ChannelNumber,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.MasterValue, ',', '.')) AS MasterValue,
    c.MasterValueUnitId,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.AdditionalValue, ',', '.')) AS AdditionalValue,
    c.AdditionalValueUnitId,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.StabilityValue, ',', '.')) AS StabilityValue,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.UncertancyValue, ',', '.')) AS UncertancyValue,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.MeasuredValue, ',', '.')) AS MeasuredValue,
    c.MeasuredValueUnitId
FROM OPENJSON(@Data) 
WITH (
    OrderDetailsItemId INT,
    Points NVARCHAR(MAX) AS JSON
) AS d
OUTER APPLY OPENJSON(d.Points)
WITH (
    MeasurmentPointName NVARCHAR(100),
    MeasurmentPointCoordX NVARCHAR(50),
    MeasurmentPointCoordY NVARCHAR(50),
    SensorMeasurementDeviceId INT,
    ChannelNumber INT,
	MasterValue NVARCHAR(50),
    MasterValueUnitId INT,
    AdditionalValue NVARCHAR(50),
    AdditionalValueUnitId INT,
    StabilityValue NVARCHAR(50),
    UncertancyValue NVARCHAR(50),
    MeasuredValue NVARCHAR(50),
    MeasuredValueUnitId INT
) AS c
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

END
