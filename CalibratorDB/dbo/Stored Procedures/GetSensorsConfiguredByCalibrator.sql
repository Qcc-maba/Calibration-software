CREATE   PROCEDURE [dbo].[GetSensorsConfiguredByCalibrator]
@LoggedInUserEmail NVARCHAR(100),
@SensorMeasurementDeviceId INT = NULL
AS
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/07/2025
-- Description:	
-- JiraLink: 
-- =============================================
BEGIN

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

	SELECT ltc.LoggerMeasurementDeviceId,
	       ltc.CommunicationDetails,
		   ltc.CommunicationProtocol,
	       stc.SensorMeasurementDeviceId,	
	       stc.UnitId,
		   stc.WorkRangeUnitId,
           STRING_AGG(cts.ChannelNumber,',') as ChannelList
	FROM dbo.LoggerToCalibrator as ltc
	JOIN dbo.SensorToLoggerToCalibrator as stc ON stc.LoggerToCalibratorId = ltc.LoggerToCalibratorId AND stc.IsDeleted =0
	LEFT JOIN dbo.ChannelsToSensorForCalibratoration as cts ON cts.SensorToLoggerToCalibratorId = stc.SensorToLoggerToCalibratorId AND cts.IsDeleted =0
	WHERE ltc.AssignedCalibratorId = @LoggedInUserId AND ltc.IsDeleted =0 AND stc.IsDeleted =0 AND  cts.IsDeleted =0
		  AND (stc.SensorMeasurementDeviceId = @SensorMeasurementDeviceId OR @SensorMeasurementDeviceId IS NULL)
	GROUP BY
		   ltc.LoggerMeasurementDeviceId,
	       ltc.CommunicationDetails,
		   ltc.CommunicationProtocol,
		   stc.SensorMeasurementDeviceId,	
	       stc.UnitId,
		   stc.WorkRangeUnitId
END