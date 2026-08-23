-- =============================================
-- Proc:        dbo.GetSensorsConfiguredByCalibrator   (original author: Eduard Kudlaiev, 02/07/2025)
-- Jira:        MBA-476 "Connecting multiple sensors" · MBA-475 "Disconnect Detection"
--
-- 2026-08-13 change (STAGE only): the proc identified a sensor only by its internal
-- SensorMeasurementDeviceId and returned WorkRangeUnitId without the range itself, so the sensor
-- table could not show "ID, type, range" per connected sensor (MBA-476) and had no bounds to
-- compare a reading against (MBA-475). Added, all straight off the sensor's MeasurementDevices row:
--     MabaID, Model, SerialNumber, Manufacturer   — identity for the table
--     DeviceRange                                  — the range AS TEXT, which is how it is stored
--     WorkRangeMin, WorkRangeMax                   — the numeric bounds, when they exist
-- No rows/filters changed; this is additive.
--
-- READ THIS BEFORE BUILDING THE MBA-475 HIGHLIGHT RULE — the numbers are not there.
-- Measured on STAGE 2026-08-13 across 152 sensors:
--     0   have numeric WorkRangeMin/WorkRangeMax        <-- zero, not "a few"
--     85  have only the free-text DeviceRange
--     67  have no range at all
-- And DeviceRange is not machine-readable: '0-150', '-80c%1100c', '196-', '0÷100%RH;-40÷60°C',
-- '(-120)-100°C', '-40÷60°C/0÷100%RH', '0-1300°'. Some rows carry TWO ranges (temperature plus
-- humidity), some are typos. Auto-parsing that into thresholds would silently produce wrong
-- limits on a feature whose whole job is to flag out-of-range readings, so it is deliberately NOT
-- done here. The rule needs WorkRangeMin/WorkRangeMax populated first — a data task, not an SP one.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetSensorsConfiguredByCalibrator]
    @LoggedInUserEmail NVARCHAR(100),
    @LoggerMeasurementDeviceId INT = NULL,
    @SensorMeasurementDeviceId INT = NULL
AS
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
           -- MBA-476: identify each connected sensor in its own row
           ltc.MabaID,
           ltc.Model,
           ltc.SerialNumber,
           ltc.Manufacturer,
           -- MBA-475: the range. DeviceRange is text and is the only one populated today.
           ltc.DeviceRange,
           ltc.WorkRangeMin,
           ltc.WorkRangeMax,
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
    ltc.WorkRangeUnitId,
    ltc.MabaID,
    ltc.Model,
    ltc.SerialNumber,
    ltc.Manufacturer,
    ltc.DeviceRange,
    ltc.WorkRangeMin,
    ltc.WorkRangeMax

END
GO
