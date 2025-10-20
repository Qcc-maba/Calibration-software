CREATE   PROCEDURE [dbo].[AssignMeasurmentDeviceToOrderDetailsItems]
@LoggedInUserEmail NVARCHAR(100),
@Data NVARCHAR(MAX)
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 30/07/2025
-- Description:	Populate table MeasurmentDeviceToOrderDetailsItems during calibration process setup
-- JiraLink: 
-- =============================================
--Example of json needs to be passed
--DECLARE @json NVARCHAR(MAX) = '
--{
--	"OrderDetailsItemId": "1",
--	"Loggers": [
--		{
--			"LoggerMeasurementDeviceId": "2",
--			"Sensors": [
--				{
--					"SensorMeasurementDeviceId": "1",
--					"PrimaryMeasurmentUnitId": "1",
--					"SecondaryMeasurmentUnitId": "5"
--				},
--				{
--					"SensorMeasurementDeviceId": "2",
--					"PrimaryMeasurmentUnitId": "1",
--					"SecondaryMeasurmentUnitId": "4"
--				}
--			]
--		},
--		{
--			"LoggerMeasurementDeviceId": "3",
--			"Sensors": [
--				{
--					"SensorMeasurementDeviceId": "3",
--					"PrimaryMeasurmentUnitId": "2",
--					"SecondaryMeasurmentUnitId": "7"
--				}
--			]
--		}
--	]
--}'
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
	LoggerMeasurementDeviceId INT,
	SensorMeasurementDeviceId INT,
	PrimaryMeasurmentUnitId INT,
	SecondaryMeasurmentUnitId INT
)

INSERT #parsedData
(
	OrderDetailsItemId,
	LoggerMeasurementDeviceId,
	SensorMeasurementDeviceId,
	PrimaryMeasurmentUnitId,
	SecondaryMeasurmentUnitId
)

SELECT 
d.OrderDetailsItemId,
c.LoggerMeasurementDeviceId,
s.SensorMeasurementDeviceId,
s.PrimaryMeasurmentUnitId,
s.SecondaryMeasurmentUnitId
		FROM OPENJSON(@Data) 
		WITH (
			OrderDetailsItemId INT,
			Loggers NVARCHAR(MAX) AS JSON
		) AS d
		OUTER APPLY OPENJSON(d.Loggers)
		WITH (
			LoggerMeasurementDeviceId INT,
			Sensors NVARCHAR(MAX) AS JSON
		) AS c
        OUTER APPLY OPENJSON(c.Sensors)
		WITH (
			SensorMeasurementDeviceId INT,
            PrimaryMeasurmentUnitId INT,
            SecondaryMeasurmentUnitId INT
		) AS s

--Check: sensor with specified channel can be only assigned once for same order detail
	IF EXISTS 
	(
		SELECT TOP 1 1
		FROM [dbo].[MeasurmentDeviceToOrderDetailsItems] as d
		JOIN [dbo].[OrderDetailsItems] as odi ON d.OrderDetailsItemId = odi.OrderDetailsItemId
		JOIN 
		(
			SELECT 
				pd.OrderDetailsItemId,
				pd.LoggerMeasurementDeviceId,
				pd.SensorMeasurementDeviceId,
				odi.OrderDetailId
			FROM #parsedData as pd
			JOIN [dbo].[OrderDetailsItems] as odi ON pd.OrderDetailsItemId = odi.OrderDetailsItemId
		)
		as c ON c.OrderDetailId = odi.OrderDetailId
						 AND c.LoggerMeasurementDeviceId = d.LoggerMeasurementDeviceId
						 AND c.SensorMeasurementDeviceId = d.SensorMeasurementDeviceId
		WHERE d.IsDeleted = 0 AND d.OrderDetailsItemId <> c.OrderDetailsItemId
	)
	THROW 51000, 'Sensor with specified channel(s) already assigned to other device.', 1;

/*Apply soft delete to data which no longer valid*/
UPDATE dest
SET IsDeleted = 1,
    UpdatedDate = GETDATE()
FROM [dbo].[MeasurmentDeviceToOrderDetailsItems] as dest 
LEFT JOIN #parsedData as pd
	ON pd.OrderDetailsItemId = dest.OrderDetailsItemId
	   AND pd.LoggerMeasurementDeviceId = dest.LoggerMeasurementDeviceId
	   AND pd.SensorMeasurementDeviceId = dest.SensorMeasurementDeviceId
WHERE dest.IsDeleted = 0 AND pd.LoggerMeasurementDeviceId IS NULL
AND dest.OrderDetailsItemId IN (SELECT OrderDetailsItemId FROM #parsedData)

/*Insert new data or updating existing*/
MERGE INTO [dbo].[MeasurmentDeviceToOrderDetailsItems] AS dest
USING (
	SELECT
		d.OrderDetailsItemId,
		d.LoggerMeasurementDeviceId,
		d.SensorMeasurementDeviceId,
		d.PrimaryMeasurmentUnitId,
		d.SecondaryMeasurmentUnitId
	FROM #parsedData as d
	WHERE d.OrderDetailsItemId IS NOT NULL AND d.LoggerMeasurementDeviceId IS NOT NULL AND d.SensorMeasurementDeviceId IS NOT NULL
	) AS source
	ON   dest.[OrderDetailsItemId] = source.[OrderDetailsItemId]
		 AND dest.[LoggerMeasurementDeviceId] = source.[LoggerMeasurementDeviceId]
		 AND dest.[SensorMeasurementDeviceId] = source.[SensorMeasurementDeviceId]
		 AND dest.[IsDeleted] = 0
WHEN MATCHED AND ( 
	           dest.[PrimaryMeasurmentUnitId] <> source.[PrimaryMeasurmentUnitId]
			OR dest.[SecondaryMeasurmentUnitId] <> source.[SecondaryMeasurmentUnitId])
	THEN
		UPDATE
		SET  dest.[PrimaryMeasurmentUnitId] = source.[PrimaryMeasurmentUnitId]
			,dest.[SecondaryMeasurmentUnitId] = source.[SecondaryMeasurmentUnitId]
			,dest.[UpdatedDate] = GETDATE()
			,dest.[UpdateUserID] = @LoggedInUserId
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [OrderDetailsItemId]
			,[LoggerMeasurementDeviceId]
			,[SensorMeasurementDeviceId]
			,[PrimaryMeasurmentUnitId]
			,[SecondaryMeasurmentUnitId]
			,[UpdateUserID]
			)
		VALUES (
             source.[OrderDetailsItemId]
			,source.[LoggerMeasurementDeviceId]
			,source.[SensorMeasurementDeviceId]
			,source.[PrimaryMeasurmentUnitId]
			,source.[SecondaryMeasurmentUnitId]
			,@LoggedInUserId
			);

END