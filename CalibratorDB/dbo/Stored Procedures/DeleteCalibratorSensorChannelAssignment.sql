
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 22/01/2026
-- Description:	Delete channel assigned to sensor for specific calibrator
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-548
-- =============================================
CREATE       Procedure [dbo].[DeleteCalibratorSensorChannelAssignment]
@SensorMeasurementDeviceId INT,
--@CalibratorId INT,
@ChannelNumber INT,
@LoggedInUserEmail NVARCHAR(100) 
AS
BEGIN
SET NOCOUNT ON;

DECLARE @UserId INT = NULL

SELECT @UserId = u.ID 
FROM [dbo].[Users] as u
JOIN [dbo].[UserRoles] as ur ON u.UserRoleId = ur.UserRoleId
WHERE u.Email=@LoggedInUserEmail 

	UPDATE cts
	SET IsDeleted = 1,
		UpdateUserID = @UserId,
		UpdatedDate = GETDATE()
	FROM dbo.LoggerToCalibrator as ltc
	JOIN dbo.SensorToLoggerToCalibrator as stc ON stc.LoggerToCalibratorId = ltc.LoggerToCalibratorId AND stc.IsDeleted =0
	LEFT JOIN dbo.ChannelsToSensorForCalibratoration as cts ON cts.SensorToLoggerToCalibratorId = stc.SensorToLoggerToCalibratorId AND cts.IsDeleted =0
	WHERE stc.SensorMeasurementDeviceId=@SensorMeasurementDeviceId AND AssignedCalibratorId = @UserId AND ChannelNumber = @ChannelNumber
END