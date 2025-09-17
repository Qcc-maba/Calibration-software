CREATE     PROCEDURE [dbo].[RemoveSensorFromLogger]
@LoggedInUserEmail NVARCHAR(100),
@CalibratorEmail  NVARCHAR(100),
@LoggerIds NVARCHAR(300),
@SensorIds NVARCHAR(300)
AS
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 09/10/2025
-- Description:	
-- JiraLink: 
-- =============================================
BEGIN

SET NOCOUNT ON;

	DECLARE @Userid INT
	SELECT @Userid = ID FROM dbo.Users WHERE Email = @LoggedInUserEmail

	DECLARE @CalibratorId INT
	SELECT @CalibratorId = ID FROM dbo.Users WHERE Email = @CalibratorEmail

	DROP TABLE IF EXISTS #Loggers
	CREATE TABLE #Loggers
	(
	LoggerId INT
	)
	INSERT #Loggers(LoggerId)
	SELECT DISTINCT value FROM STRING_SPLIT(@LoggerIds,',')

	DROP TABLE IF EXISTS #Sensors
	CREATE TABLE #Sensors
	(
	SensorId INT
	)
	INSERT #Sensors(SensorId)
	SELECT DISTINCT value FROM STRING_SPLIT(@SensorIds,',')

	DECLARE @Changed TABLE
	(
	LoggerToCalibratorId INT
	);

	INSERT @Changed(LoggerToCalibratorId)
	SELECT cal.LoggerToCalibratorId
	FROM dbo.LoggerToCalibrator as cal
	JOIN #Loggers as l ON cal.LoggerMeasurementDeviceId = l.LoggerId
	WHERE cal.AssignedCalibratorId = @CalibratorId

	UPDATE sl
	SET IsDeleted = 1, UpdateUserID = @Userid
	FROM dbo.SensorToLoggerToCalibrator as sl
	JOIN #Sensors as s ON sl.SensorMeasurementDeviceId = s.SensorId
	JOIN @Changed as c ON sl.LoggerToCalibratorId = c.LoggerToCalibratorId


END