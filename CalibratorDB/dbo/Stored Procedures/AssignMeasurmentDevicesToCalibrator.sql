
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

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

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

	UPDATE [dbo].[MeasurementDevices]
	SET FlowRate = @FlowRate,
		Interval = @Interval,
		Connection = @CommunicationProtocol,
		IP = @CommunicationDetails,
		UpdateDate = GETDATE(),
		UpdateUserID = @LoggedInUserId
	WHERE ID = @LoggerMeasurementDeviceId
	
	INSERT [dbo].[SensorToLoggerRelation](
	[SensorMeasurementDeviceId],
	[LoggerMeasurementDeviceId])
	SELECT @SensorMeasurementDeviceId ,@LoggerMeasurementDeviceId 
	WHERE NOT EXISTS (SELECT 1 FROM [dbo].[SensorToLoggerRelation] 
					  WHERE [SensorMeasurementDeviceId] = @SensorMeasurementDeviceId
	                  AND [LoggerMeasurementDeviceId] = @LoggerMeasurementDeviceId
					  AND [IsDeleted] = 0)
	
--Insert new data
	INSERT [dbo].[ChannelsToSensorRelation]([SensorMeasurementDeviceId],[LoggerMeasurementDeviceId],[ChannelNumber])
	SELECT @SensorMeasurementDeviceId,@LoggerMeasurementDeviceId, c.ChannelNumber
	FROM #Channels as c
	LEFT JOIN [dbo].[ChannelsToSensorRelation] as cr ON cr.[SensorMeasurementDeviceId] = @SensorMeasurementDeviceId
	                                                AND cr.[LoggerMeasurementDeviceId] = @LoggerMeasurementDeviceId
													AND c.ChannelNumber = cr.ChannelNumber
							
	WHERE cr.[SensorMeasurementDeviceId] IS NULL

--In case if it was previously assigned revert deleted flag
    UPDATE cr
	SET IsDeleted = 0,
		UpdatedDate = GETDATE(),
		UpdateUserID = @LoggedInUserId
	FROM #Channels as c
	LEFT JOIN [dbo].[ChannelsToSensorRelation] as cr ON cr.[SensorMeasurementDeviceId] = @SensorMeasurementDeviceId
	                                                AND cr.[LoggerMeasurementDeviceId] = @LoggerMeasurementDeviceId
													AND c.ChannelNumber = cr.ChannelNumber
													AND cr.IsDeleted = 1

	COMMIT
END TRY

BEGIN CATCH
	SELECT ERROR_MESSAGE() as error
	ROLLBACK
END CATCH 
END