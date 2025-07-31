CREATE   PROCEDURE [dbo].[AssignMeasurmentPointsToOrderDetailsItems]
@LoggedInUserEmail NVARCHAR(100),
@Data NVARCHAR(MAX)
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 31/07/2025
-- Description:	Populate table MeasurmentPointsToOrderDetailsItems during calibration process setup
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
--      "ChannelNumber": 1
--    },
--    {
--      "MeasurmentPointName": "T2",
--      "MeasurmentPointCoordX": "8.35",
--      "MeasurmentPointCoordY": "4.25",
--      "SensorMeasurementDeviceId": "1",
--      "ChannelNumber": 15
--    },
--    {
--      "MeasurmentPointName": "T3",
--      "MeasurmentPointCoordX": "12.35",
--      "MeasurmentPointCoordY": "5.3",
--      "SensorMeasurementDeviceId": "2",
--      "ChannelNumber": 17
--    }
--  ]
--}
--'

AS

BEGIN 

SET NOCOUNT ON;

DECLARE @Userid INT
SELECT @Userid = ID FROM dbo.Users WHERE Email = @LoggedInUserEmail

DROP TABLE IF EXISTS #parsedData

CREATE TABLE #parsedData
(
	OrderDetailsItemId INT,
    MeasurmentPointName NVARCHAR(100) COLLATE Hebrew_BIN,
    SensorMeasurementDeviceId INT,
    MeasurmentPointCoordX DECIMAL(10,4),
    MeasurmentPointCoordY DECIMAL(10,4),
	ChannelNumber INT
)

INSERT #parsedData
(
	OrderDetailsItemId,
    MeasurmentPointName,
    SensorMeasurementDeviceId,
    MeasurmentPointCoordX,
    MeasurmentPointCoordY,
	ChannelNumber
)

SELECT 
    d.OrderDetailsItemId,
    c.MeasurmentPointName COLLATE Hebrew_BIN,
    c.SensorMeasurementDeviceId,
    c.MeasurmentPointCoordX,
    c.MeasurmentPointCoordY,
    c.ChannelNumber
FROM OPENJSON(@Data) 
WITH (
    OrderDetailsItemId INT,
    Points NVARCHAR(MAX) AS JSON
) AS d
OUTER APPLY OPENJSON(d.Points)
WITH (
    MeasurmentPointName NVARCHAR(100),
    MeasurmentPointCoordX DECIMAL(10,4),
    MeasurmentPointCoordY DECIMAL(10,4),
    SensorMeasurementDeviceId INT,
    ChannelNumber INT
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
		d.ChannelNumber
	FROM #parsedData as d
	) AS source
	ON   dest.[OrderDetailsItemId] = source.[OrderDetailsItemId]
		 AND dest.[SensorMeasurementDeviceId] = source.[SensorMeasurementDeviceId]
		 AND dest.[ChannelNumber] = source.[ChannelNumber]
		 AND dest.[IsDeleted] = 0
WHEN MATCHED AND ( 
	           dest.[MeasurmentPointName] <> source.[MeasurmentPointName] COLLATE Hebrew_BIN
			OR dest.[MeasurmentPointCoordX] <> source.[MeasurmentPointCoordX]
			OR dest.[MeasurmentPointCoordY] <> source.[MeasurmentPointCoordY])
	THEN
		UPDATE
		SET  dest.[MeasurmentPointName] = source.[MeasurmentPointName] COLLATE Hebrew_BIN
			,dest.[MeasurmentPointCoordX] = source.[MeasurmentPointCoordX]
			,dest.[MeasurmentPointCoordY] = source.[MeasurmentPointCoordY]
			,dest.[UpdatedDate] = GETDATE()
			,dest.[UpdateUserID] = @Userid
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			  [OrderDetailsItemId],
			  [SensorMeasurementDeviceId],
			  [MeasurmentPointName],
			  [MeasurmentPointCoordX],
			  [MeasurmentPointCoordY],
			  [ChannelNumber],
			  [UpdateUserID]
			)
		VALUES (
             source.[OrderDetailsItemId]
			,source.[SensorMeasurementDeviceId]
			,source.[MeasurmentPointName]
			,source.[MeasurmentPointCoordX]
			,source.[MeasurmentPointCoordY]
			,source.[ChannelNumber]
			,@Userid
			);

END