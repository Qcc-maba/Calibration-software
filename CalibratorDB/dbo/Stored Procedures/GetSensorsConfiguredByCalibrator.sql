CREATE   PROCEDURE [dbo].[GetSensorsConfiguredByCalibrator] 
@LoggedInUserEmail NVARCHAR(100),
@LoggerMeasurementDeviceId INT = NULL,
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

	SELECT srl.LoggerMeasurementDeviceId as  LoggerMeasurementDeviceId,
	       ltc.IP AS CommunicationDetails,
		   ltc.Connection as CommunicationProtocol,
	       srl.SensorMeasurementDeviceId as SensorMeasurementDeviceId,	
	       ltc.UnitId,
		   ltc.WorkRangeUnitId,
           STRING_AGG(csr.ChannelNumber,',') as ChannelList
	FROM dbo.MeasurementDevices as ltc
	JOIN dbo.MeasurementDevicesMainClasses as mc ON ltc.MainClassId = mc.Id
	JOIN dbo.SensorToLoggerRelation as srl ON ltc.ID = srl.SensorMeasurementDeviceId AND srl.IsDeleted = 0
	JOIN dbo.ChannelsToSensorRelation as csr ON csr.SensorMeasurementDeviceId = srl.SensorMeasurementDeviceId AND csr.LoggerMeasurementDeviceId = srl.LoggerMeasurementDeviceId AND csr.IsDeleted = 0
    WHERE  mc.NameEnglish = 'Sensor' AND ltc.IsDeleted =0 
	AND (@SensorMeasurementDeviceId IS NULL OR srl.SensorMeasurementDeviceId = @SensorMeasurementDeviceId)
	AND (@LoggerMeasurementDeviceId IS NULL OR srl.LoggerMeasurementDeviceId = @LoggerMeasurementDeviceId)
	GROUP BY 
	srl.LoggerMeasurementDeviceId,
	ltc.IP,
	ltc.Connection,
	srl.SensorMeasurementDeviceId,
	ltc.UnitId,
	ltc.WorkRangeUnitId

END