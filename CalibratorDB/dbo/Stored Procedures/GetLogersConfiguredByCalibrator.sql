CREATE   PROCEDURE [dbo].[GetLogersConfiguredByCalibrator]
@LoggedInUserEmail NVARCHAR(100)
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
	       ltc.FlowRate,	
		   ltc.Interval,	
		   ltc.CommunicationProtocol,	
		   ltc.CommunicationDetails,
		   SUM(1) OVER( PARTITION BY ltc.AssignedCalibratorId) as CountAssignedLoggers
	FROM dbo.LoggerToCalibrator as ltc
	WHERE ltc.AssignedCalibratorId = @Userid AND IsDeleted =0

END