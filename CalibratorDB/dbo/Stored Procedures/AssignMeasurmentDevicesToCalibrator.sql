
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/07/2025
-- Description:	This SP assing combination of logger sensor and channeles to calibrator
-- JiraLink: 
-- =============================================
CREATE    PROCEDURE [dbo].[AssignMeasurmentDevicesToCalibrator]
@LoggedInUserEmail NVARCHAR(100),
@LoggerMeasurementDeviceId INT,
@FlowRate NVARCHAR(20),
@Interval INT,
@CommunicationProtocol NVARCHAR(100),
@CommunicationDetails NVARCHAR(100),
@SensorMeasurementDeviceId INT,
@UnitId INT NULL,
@WorkRangeUnitId INT NULL,
@ChannelNumbers NVARCHAR(MAX)

AS
BEGIN

DECLARE @Userid INT
SELECT @Userid = ID FROM dbo.Users WHERE Email = @LoggedInUserEmail


if NOT EXISTS (
SELECT 1 FROM dbo.Users as u
JOIN dbo.UserRoles as ur ON u.UserRoleId = ur.UserRoleId
WHERE u.ID = @Userid AND ur.UserRoleDescriptionENG LIKE '%Calibrator%'
)
THROW 51000, 'Incorrect user email passed. User is not a calibrator.', 1;

if NOT EXISTS (
SELECT 1 FROM dbo.MeasurementDevices as md
JOIN dbo.MeasurementDevicesMainClasses as mc ON md.MainClassId = mc.Id
WHERE mc.NameEnglish = 'Data logger' AND md.ID = @LoggerMeasurementDeviceId AND md.IsDeleted = 0
)
THROW 51000, 'Incorrect @LoggerMeasurementDeviceId passed. Device is not data logger or inactive.', 1;

if NOT EXISTS (
SELECT 1 FROM dbo.MeasurementDevices as md
JOIN dbo.MeasurementDevicesMainClasses as mc ON md.MainClassId = mc.Id
WHERE mc.NameEnglish = 'Sensor' AND md.ID = @SensorMeasurementDeviceId AND md.IsDeleted = 0
)
THROW 51000, 'Incorrect @SensorMeasurementDeviceId passed. Device is not sensor or inactive.', 1;

DROP TABLE IF EXISTS #Channels

CREATE TABLE #Channels
(
ChannelNumber INT
)

INSERT #Channels(ChannelNumber)
SELECT CAST(value AS INT)
FROM STRING_SPLIT(@ChannelNumbers,',')
WHERE value >= 0

BEGIN TRY
	
	BEGIN TRAN

	MERGE INTO [dbo].[LoggerToCalibrator] AS dest
	USING (
		SELECT 
			 @Userid as [AssignedCalibratorId]
			,@FlowRate as [FlowRate]
			,@Interval as [Interval]
			,@LoggerMeasurementDeviceId as [LoggerMeasurementDeviceId]
			,@CommunicationProtocol as [CommunicationProtocol]
			,@CommunicationDetails as [CommunicationDetails]
			,@Userid as [UpdateUserID]
		) AS source
		ON 
			dest.[AssignedCalibratorId] = source.[AssignedCalibratorId] 
			AND dest.[LoggerMeasurementDeviceId] = source.[LoggerMeasurementDeviceId]
			AND dest.IsDeleted = 0
	WHEN MATCHED AND (
	       dest.[FlowRate] <> source.[FlowRate]
		   OR dest.[Interval] <> source.[Interval]
		   OR dest.[CommunicationProtocol] <> source.[CommunicationProtocol]
		   OR dest.[CommunicationDetails] <> source.[CommunicationDetails])
		THEN
			UPDATE
			SET 
				 dest.[FlowRate] = source.[FlowRate]
				,dest.[Interval] = source.[Interval]
				,dest.[CommunicationProtocol] = source.[CommunicationProtocol]
				,dest.[CommunicationDetails] = source.[CommunicationDetails]
				,dest.[UpdatedDate] = GETDATE()
				,dest.[UpdateUserID] = source.[UpdateUserID]
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [AssignedCalibratorId]
				,[FlowRate]
				,[Interval]
				,[LoggerMeasurementDeviceId]
				,[CommunicationProtocol]
				,[CommunicationDetails]
				,[UpdateUserID]
				)
			VALUES (
				 source.[AssignedCalibratorId]
				,source.[FlowRate]
				,source.[Interval]
				,source.[LoggerMeasurementDeviceId]
				,source.[CommunicationProtocol]
				,source.[CommunicationDetails]
				,source.[UpdateUserID]
				);

	DECLARE @LoggerToCalibratorId INT = 0
	SELECT @LoggerToCalibratorId = l.LoggerToCalibratorId FROM [dbo].[LoggerToCalibrator] as l 
		WHERE l.[AssignedCalibratorId] = @Userid AND l.[LoggerMeasurementDeviceId] = @LoggerMeasurementDeviceId


	MERGE INTO [dbo].[SensorToLoggerToCalibrator] AS dest
	USING (
		SELECT 
			 @LoggerToCalibratorId as [LoggerToCalibratorId]
			,@SensorMeasurementDeviceId AS [SensorMeasurementDeviceId]
			,@UnitId AS [UnitId]
			,@WorkRangeUnitId as [WorkRangeUnitId]
			,@Userid as [UpdateUserID]
		) AS source
		ON dest.[LoggerToCalibratorId] = source.[LoggerToCalibratorId] 
		   AND dest.[SensorMeasurementDeviceId] = source.[SensorMeasurementDeviceId]
		   AND dest.IsDeleted = 0
	WHEN MATCHED AND (
			COALESCE(dest.[UnitId],0) <> COALESCE(source.[UnitId],0)
			OR COALESCE(dest.[WorkRangeUnitId],0) <> COALESCE(source.[WorkRangeUnitId],0))
		THEN
			UPDATE
			SET 	     
				 dest.[UnitId] = source.[UnitId]
				,dest.[WorkRangeUnitId] = source.[WorkRangeUnitId]
				,dest.[UpdatedDate] = GETDATE()
				,dest.[UpdateUserID] = source.[UpdateUserID]
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [LoggerToCalibratorId]
				,[SensorMeasurementDeviceId]
				,[UnitId]
				,[WorkRangeUnitId]
				,[UpdateUserID]
				)
			VALUES (
				 source.[LoggerToCalibratorId]
				,source.[SensorMeasurementDeviceId]
				,source.[UnitId]
				,source.[WorkRangeUnitId]
				,source.[UpdateUserID]
				);

	DECLARE @SensorToLoggerToCalibratorId INT = 0
	SELECT @SensorToLoggerToCalibratorId = sl.SensorToLoggerToCalibratorId FROM [dbo].[SensorToLoggerToCalibrator] as sl
	WHERE sl.LoggerToCalibratorId = @LoggerToCalibratorId AND sl.SensorMeasurementDeviceId = @SensorMeasurementDeviceId AND sl.IsDeleted = 0

	UPDATE dest
	SET  dest.[UpdatedDate] = GETDATE()
		,dest.[UpdateUserID] = @Userid
		,dest.[IsDeleted] = 1
	FROM [dbo].[ChannelsToSensorForCalibratoration] as dest
	LEFT JOIN #Channels as c ON dest.[SensorToLoggerToCalibratorId] = @SensorToLoggerToCalibratorId
	                            AND dest.[ChannelNumber] = c.ChannelNumber
								AND dest.IsDeleted = 0
	WHERE c.ChannelNumber IS NULL AND dest.[SensorToLoggerToCalibratorId] = @SensorToLoggerToCalibratorId
  
	
	MERGE INTO [dbo].[ChannelsToSensorForCalibratoration] AS dest
	USING (
		SELECT 
		     @SensorToLoggerToCalibratorId as [SensorToLoggerToCalibratorId]
			,ch.[ChannelNumber]
			,@Userid as [UpdateUserID]
		FROM #Channels as ch
		) AS source
		ON dest.[SensorToLoggerToCalibratorId] = source.[SensorToLoggerToCalibratorId]
		   AND dest.[ChannelNumber] = source.[ChannelNumber]
		   AND dest.IsDeleted = 0
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				[SensorToLoggerToCalibratorId]
				,[ChannelNumber]
				,[UpdateUserID]
				)
			VALUES (
				source.[SensorToLoggerToCalibratorId]
				,source.[ChannelNumber]
				,source.[UpdateUserID]
				);


	COMMIT
END TRY

BEGIN CATCH
	SELECT ERROR_MESSAGE() as error
	ROLLBACK
END CATCH 
END

/*
--Select calibrators
SELECT * FROM Users
WHERE UserRoleId =3


--Select logger
SELECT * FROM [dbo].[MeasurementDevices]
WHERE MainClassId = 7 AND IsDeleted = 0

--Select sensor
SELECT * FROM [dbo].[MeasurementDevices]
WHERE MainClassId = 2 AND IsDeleted = 0

--test
SELECT * FROM [dbo].[LoggerToCalibrator]
SELECT * FROM [dbo].[SensorToLoggerToCalibrator]
SELECT * FROM [dbo].[ChannelsToSensorForCalibratoration] 
*/