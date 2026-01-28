CREATE     PROCEDURE [dbo].[RemoveSensorFromLogger]
@LoggedInUserEmail NVARCHAR(100),
@LoggerId INT,
@SensorIds NVARCHAR(MAX)
AS
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 09/10/2025
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

	DROP TABLE IF EXISTS #Sensors
	CREATE TABLE #Sensors
	(
	SensorId INT
	)
	INSERT #Sensors(SensorId)
	SELECT DISTINCT value FROM STRING_SPLIT(@SensorIds,',')

	UPDATE sl
	SET IsDeleted = 1, UpdateUserID = @LoggedInUserId
	FROM [dbo].[SensorToLoggerRelation] as sl
	JOIN #Sensors as s ON sl.SensorMeasurementDeviceId = s.SensorId
	AND sl.LoggerMeasurementDeviceId = @LoggerId


END