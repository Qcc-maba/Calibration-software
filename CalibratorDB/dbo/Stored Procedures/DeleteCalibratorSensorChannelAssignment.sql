
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 22/01/2026
-- Description:	Delete channel assigned to sensor for specific calibrator
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-548
-- =============================================
CREATE       Procedure [dbo].[DeleteCalibratorSensorChannelAssignment]
@SensorMeasurementDeviceId INT,
@LoggerMeasurementDeviceId INT,
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
	FROM [dbo].[ChannelsToSensorRelation] as cts
	WHERE cts.LoggerMeasurementDeviceId = @LoggerMeasurementDeviceId
	      AND cts.SensorMeasurementDeviceId = @SensorMeasurementDeviceId
		  AND cts.ChannelNumber = @ChannelNumber
		  AND cts.IsDeleted = 0

END