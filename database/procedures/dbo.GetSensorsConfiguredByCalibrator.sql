-- =============================================
-- Proc:        dbo.GetSensorsConfiguredByCalibrator   (original author: Eduard Kudlaiev, 02/07/2025)
-- Jira:        MBA-476 "Connecting multiple sensors" / MBA-475 "Disconnect Detection"
--
-- 2026-08-13 change (STAGE only): the proc identified a sensor only by its internal
-- SensorMeasurementDeviceId and returned WorkRangeUnitId without the range itself, so the sensor
-- table could not show "ID, type, range" per connected sensor (MBA-476) and had no bounds to
-- compare a reading against (MBA-475). Added, all straight off the sensor's MeasurementDevices row:
--     MabaID, Model, SerialNumber, Manufacturer   - identity for the table
--     DeviceRange                                  - the range AS TEXT, which is how it is stored
--     WorkRangeMin, WorkRangeMax                   - the numeric bounds, when they exist
-- No rows/filters changed; this is additive.
--
-- 2026-08-24 (MBA-902): dual ranges, plus two ordering fixes - all three visible in the popup.
--     ChannelList came out of STRING_AGG in whatever order the join produced, so a sensor holding
--     channels 0,1,2,3,6,7 could render as "3,0,7,1,6,2". Now sorted numerically.
--     The result set itself had no ORDER BY, so the sensor list reshuffled between calls. Now
--     sorted by MabaID on its numeric segments, so 21-9 comes before 21-86.
--
-- On the work range: as of 2026-08-24, 85 of 152 sensors on STAGE have numeric WorkRangeMin/Max
-- (imported from kyulan.dbo.tblInstr by dbo.ImportInstrumentWorkRangeFromKyulan - it was 0 before).
-- The remaining 67 cannot be filled from kyulan: it holds no numeric range for any of them, and
-- only a lone minimum for 31-83. 37 of the 67 carry a free-text DeviceRange instead, and that text
-- is not machine-readable: '0-150', '-80c%1100c', '196-', '0-100%RH;-40-60C', '(-120)-100C',
-- '0-1300'. Some rows carry TWO ranges (temperature plus humidity), some are typos. Auto-parsing
-- would silently produce wrong limits on a feature whose whole job is to flag out-of-range
-- readings, so it is deliberately NOT done here. Those 37 need a human pass - a data task.
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
           -- MBA-475: the range. DeviceRange is the original text, kept so a calibrator can
           -- always see what the numbers were read from.
           ltc.DeviceRange,
           ltc.WorkRangeMin,
           ltc.WorkRangeMax,
           u1.ShortNameEn AS WorkRangeUnit,
           -- MBA-902: a sensor that measures two things at once carries both. Slot 1 is the
           -- temperature range where there is one; slot 2 is the humidity range.
           ltc.WorkRangeMin2,
           ltc.WorkRangeMax2,
           ltc.WorkRangeUnitId2,
           u2.ShortNameEn AS WorkRangeUnit2,
           -- The outer bounds across both ranges, for a caller with only one pair of fields to
           -- fill. Do NOT compare a reading against these when the two ranges are in different
           -- units - use the matching pair above.
           CASE WHEN ltc.WorkRangeMin2 IS NULL THEN ltc.WorkRangeMin
                ELSE IIF(ltc.WorkRangeMin2 < ltc.WorkRangeMin, ltc.WorkRangeMin2, ltc.WorkRangeMin)
           END AS WorkRangeMinOverall,
           CASE WHEN ltc.WorkRangeMax2 IS NULL THEN ltc.WorkRangeMax
                ELSE IIF(ltc.WorkRangeMax2 > ltc.WorkRangeMax, ltc.WorkRangeMax2, ltc.WorkRangeMax)
           END AS WorkRangeMaxOverall,
           IIF(ltc.WorkRangeMin2 IS NOT NULL, CAST(1 AS BIT), CAST(0 AS BIT)) AS HasSecondRange,
           -- MBA-902: numeric order, not join order
           STRING_AGG(csr.ChannelNumber,',') WITHIN GROUP (ORDER BY csr.ChannelNumber) as ChannelList
    FROM dbo.MeasurementDevices as ltc
    JOIN dbo.MeasurementDevicesMainClasses as mc ON ltc.MainClassId = mc.Id
    JOIN dbo.SensorToLoggerRelation as srl ON ltc.ID = srl.SensorMeasurementDeviceId AND srl.IsDeleted = 0
    JOIN dbo.ChannelsToSensorRelation as csr ON csr.SensorMeasurementDeviceId = srl.SensorMeasurementDeviceId AND csr.LoggerMeasurementDeviceId = srl.LoggerMeasurementDeviceId AND csr.IsDeleted = 0
    LEFT JOIN dbo.MeasurementDeviceUnits as u1 ON u1.MeasurementDeviceUnitId = ltc.WorkRangeUnitId
    LEFT JOIN dbo.MeasurementDeviceUnits as u2 ON u2.MeasurementDeviceUnitId = ltc.WorkRangeUnitId2
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
    ltc.WorkRangeMax,
    u1.ShortNameEn,
    ltc.WorkRangeMin2,
    ltc.WorkRangeMax2,
    ltc.WorkRangeUnitId2,
    u2.ShortNameEn
    -- MBA-902: stable order, so the list does not reshuffle between calls
    ORDER BY
        TRY_CAST(LEFT(ltc.MabaID, CHARINDEX('-', ltc.MabaID + '-') - 1) AS INT),
        TRY_CAST(LEFT(STUFF(ltc.MabaID, 1, CHARINDEX('-', ltc.MabaID + '-'), ''),
                      CHARINDEX('/', STUFF(ltc.MabaID, 1, CHARINDEX('-', ltc.MabaID + '-'), '') + '/') - 1) AS INT),
        ltc.MabaID

END
