CREATE   Procedure dbo.AssignSensorDetailsToOrderDetailsItems
@LoggedInUserEmail NVARCHAR(100),
@Data NVARCHAR(MAX)
AS
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 16/07/2025
-- Description:	Populate table SensorToOrderDetailsItems during calibration process setup
-- JiraLink: 
-- =============================================
--Example of json needs to be passed
--DECLARE @json NVARCHAR(MAX) = '
--[
--	{
--		"OrderDetailsItemId": "1",
--		"LoggerMeasurementDeviceId": "2",
--		"SensorMeasurementDeviceId": "1",
--		"PrimaryMeasurmentUnitId": "1",
--		"SecondaryMeasurmentUnitId": "5",
--		"Channels": [
--			{
--				"MeasurmentPointName": "T1",
--				"MeasurmentPointCoordX": "4.35",
--				"MeasurmentPointCoordY": "3.35",
--				"ChannelNumber": 1
--			},
--			{
--				"MeasurmentPointName": "T2",
--				"MeasurmentPointCoordX": "8.35",
--				"MeasurmentPointCoordY": "4.25",
--				"ChannelNumber": 15
--			},
--			{
--				"MeasurmentPointName": "T3",
--				"MeasurmentPointCoordX": "12.35",
--				"MeasurmentPointCoordY": "5.3",
--				"ChannelNumber": 17
--			}
--		]
--	}
--]';
BEGIN 

SET NOCOUNT ON;

DECLARE @Userid INT
SELECT @Userid = ID FROM dbo.Users WHERE Email = @LoggedInUserEmail

DROP TABLE IF EXISTS #parsedData

CREATE TABLE #parsedData
(
	OrderDetailsItemId INT,
	LoggerMeasurementDeviceId INT,
	SensorMeasurementDeviceId INT,
	PrimaryMeasurmentUnitId INT,
	SecondaryMeasurmentUnitId INT,
	MeasurmentPointName NVARCHAR(100) COLLATE Hebrew_BIN,
	MeasurmentPointCoordX DECIMAL(10,4),
	MeasurmentPointCoordY DECIMAL(10,4),
	ChannelNumber INT
)

INSERT #parsedData
(
	OrderDetailsItemId,
	LoggerMeasurementDeviceId,
	SensorMeasurementDeviceId,
	PrimaryMeasurmentUnitId,
	SecondaryMeasurmentUnitId,
	MeasurmentPointName,
	MeasurmentPointCoordX,
	MeasurmentPointCoordY,
	ChannelNumber
)
SELECT 
			d.OrderDetailsItemId,
			d.LoggerMeasurementDeviceId,
			d.SensorMeasurementDeviceId,
			d.PrimaryMeasurmentUnitId,
			d.SecondaryMeasurmentUnitId,
			c.MeasurmentPointName,
			c.MeasurmentPointCoordX,
			c.MeasurmentPointCoordY,
			c.ChannelNumber
		FROM OPENJSON(@Data) 
		WITH (
			OrderDetailsItemId INT,
			LoggerMeasurementDeviceId INT,
			SensorMeasurementDeviceId INT,
			PrimaryMeasurmentUnitId INT,
			SecondaryMeasurmentUnitId INT,
			Channels NVARCHAR(MAX) AS JSON
		) AS d
		OUTER APPLY OPENJSON(d.Channels)
		WITH (
			MeasurmentPointName NVARCHAR(100),
			MeasurmentPointCoordX DECIMAL(10,4),
			MeasurmentPointCoordY DECIMAL(10,4),
			ChannelNumber INT
		) AS c
--Check: sensor with specified channel can be only assigned once for same order detail
	IF EXISTS 
	(
		SELECT TOP 1 1
		FROM [dbo].[SensorToOrderDetailsItems] as d
		JOIN [dbo].[OrderDetailsItems] as odi ON d.OrderDetailsItemId = odi.OrderDetailsItemId
		JOIN 
		(
			SELECT 
				pd.OrderDetailsItemId,
				pd.LoggerMeasurementDeviceId,
				pd.SensorMeasurementDeviceId,
				pd.ChannelNumber,
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

MERGE INTO [dbo].[SensorToOrderDetailsItems] AS dest
USING (
	SELECT
		d.OrderDetailsItemId,
		d.LoggerMeasurementDeviceId,
		d.SensorMeasurementDeviceId,
		d.PrimaryMeasurmentUnitId,
		d.SecondaryMeasurmentUnitId,
		d.MeasurmentPointName,
		d.MeasurmentPointCoordX,
		d.MeasurmentPointCoordY,
		d.ChannelNumber
	FROM #parsedData as d
	) AS source
	ON   dest.[OrderDetailsItemId] = source.[OrderDetailsItemId]
		 AND dest.[LoggerMeasurementDeviceId] = source.[LoggerMeasurementDeviceId]
		 AND dest.[SensorMeasurementDeviceId] = source.[SensorMeasurementDeviceId]
		 AND dest.[ChannelNumber] = source.[ChannelNumber]
		 AND dest.[IsDeleted] = 0
WHEN MATCHED AND ( 
	           dest.[MeasurmentPointName] <> source.[MeasurmentPointName]
			OR dest.[MeasurmentPointCoordX] <> source.[MeasurmentPointCoordX]
			OR dest.[MeasurmentPointCoordY] <> source.[MeasurmentPointCoordY]
			OR dest.[PrimaryMeasurmentUnitId] <> source.[PrimaryMeasurmentUnitId]
			OR dest.[SecondaryMeasurmentUnitId] <> source.[SecondaryMeasurmentUnitId])
	THEN
		UPDATE
		SET  dest.[MeasurmentPointName] = source.[MeasurmentPointName]
			,dest.[MeasurmentPointCoordX] = source.[MeasurmentPointCoordX]
			,dest.[MeasurmentPointCoordY] = source.[MeasurmentPointCoordY]
			,dest.[PrimaryMeasurmentUnitId] = source.[PrimaryMeasurmentUnitId]
			,dest.[SecondaryMeasurmentUnitId] = source.[SecondaryMeasurmentUnitId]
			,dest.[UpdatedDate] = GETDATE()
			,dest.[UpdateUserID] = @Userid
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [OrderDetailsItemId]
			,[LoggerMeasurementDeviceId]
			,[SensorMeasurementDeviceId]
			,[MeasurmentPointName]
			,[MeasurmentPointCoordX]
			,[MeasurmentPointCoordY]
			,[ChannelNumber]
			,[PrimaryMeasurmentUnitId]
			,[SecondaryMeasurmentUnitId]
			,[UpdateUserID]
			)
		VALUES (
             source.[OrderDetailsItemId]
			,source.[LoggerMeasurementDeviceId]
			,source.[SensorMeasurementDeviceId]
			,source.[MeasurmentPointName]
			,source.[MeasurmentPointCoordX]
			,source.[MeasurmentPointCoordY]
			,source.[ChannelNumber]
			,source.[PrimaryMeasurmentUnitId]
			,source.[SecondaryMeasurmentUnitId]
			,@Userid
			)
WHEN NOT MATCHED BY SOURCE
	THEN
		UPDATE
			SET  dest.[UpdatedDate] = GETDATE()
			    ,dest.[UpdateUserID] = @Userid
				,dest.[IsDeleted] = 1
		;
	

END