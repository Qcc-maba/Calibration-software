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

	SELECT DISTINCT
	       ltc.ID as LoggerMeasurementDeviceId,
	       ltc.FlowRate,	
		   ltc.Interval,	
		   ltc.Connection as CommunicationProtocol,	
		   ltc.IP AS CommunicationDetails,
		   SUM(1) OVER( PARTITION BY ltc.ID) as CountAssignedLoggers
	FROM dbo.MeasurementDevices as ltc
	JOIN dbo.MeasurementDevicesMainClasses as mc ON ltc.MainClassId = mc.Id
	JOIN dbo.SensorToLoggerRelation as srl ON ltc.ID = srl.LoggerMeasurementDeviceId AND srl.IsDeleted = 0
	WHERE mc.NameEnglish = 'Data logger' AND ltc.IsDeleted =0

END