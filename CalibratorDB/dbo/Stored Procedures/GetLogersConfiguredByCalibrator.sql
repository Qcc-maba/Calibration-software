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
SET NOCOUNT ON;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

	SELECT ltc.LoggerMeasurementDeviceId,
	       ltc.FlowRate,	
		   ltc.Interval,	
		   ltc.CommunicationProtocol,	
		   ltc.CommunicationDetails,
		   SUM(1) OVER( PARTITION BY ltc.AssignedCalibratorId) as CountAssignedLoggers
	FROM dbo.LoggerToCalibrator as ltc
	WHERE ltc.AssignedCalibratorId = @LoggedInUserId AND IsDeleted =0

END