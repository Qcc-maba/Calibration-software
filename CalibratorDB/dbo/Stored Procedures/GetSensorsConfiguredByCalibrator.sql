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
	DECLARE @Userid INT
	SELECT @Userid = ID FROM dbo.Users WHERE Email = @LoggedInUserEmail

	SELECT ltc.LoggerMeasurementDeviceId,
	       stc.SensorMeasurementDeviceId,	
	       stc.UnitId,
		   stc.WorkRangeUnitId,
           STRING_AGG(cts.ChannelNumber,',') as ChannelList
	FROM dbo.LoggerToCalibrator as ltc
	JOIN dbo.SensorToLoggerToCalibrator as stc ON stc.LoggerToCalibratorId = ltc.LoggerToCalibratorId AND stc.IsDeleted =0
	LEFT JOIN dbo.ChannelsToSensorForCalibratoration as cts ON cts.SensorToLoggerToCalibratorId = stc.SensorToLoggerToCalibratorId AND cts.IsDeleted =0
	WHERE ltc.AssignedCalibratorId = @Userid AND ltc.IsDeleted =0
		  AND (stc.SensorMeasurementDeviceId = @SensorMeasurementDeviceId OR @SensorMeasurementDeviceId IS NULL)
	GROUP BY
		   ltc.LoggerMeasurementDeviceId,
		   stc.SensorMeasurementDeviceId,	
	       stc.UnitId,
		   stc.WorkRangeUnitId
END