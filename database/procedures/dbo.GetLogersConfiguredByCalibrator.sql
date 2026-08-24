/*
    dbo.GetLogersConfiguredByCalibrator
    ---------------------------------------------------------------------------------------------
    Original author: Eduard Kudlaiev, 02/07/2025
    The loggers a calibrator has configured, for the logger-connection popup.

    2026-08-24 (MBA-902): the popup showed "0" under מס' נקודות for every logger, and the channel
    picker had nothing to size itself from. The reason was simply that this proc never returned the
    number - MeasurementDevices.ConnectionPoints holds it (21-142 = 21, 31-80 = 61) but no
    procedure exposed it. Channel count is a property of the LOGGER, not of the sensor, so it
    belongs here.

    Added, all straight off the logger's own row, no filter or row changes:
        MabaID, Model, Manufacturer   - identity, so the caller need not look it up separately
        ConnectionPoints              - how many channels this logger has
    Plus a deterministic ORDER BY: the list came back in whatever order the join produced, which
    made the dropdown reshuffle between calls.

    MabaID sorts on its two numeric segments rather than as text, so 21-9 comes before 21-86.
    The DISTINCT is kept in a derived table because ORDER BY cannot reference expressions that are
    not in a DISTINCT select list, and the sort keys are not worth returning to the caller.
*/
CREATE OR ALTER PROCEDURE [dbo].[GetLogersConfiguredByCalibrator] 
@LoggedInUserEmail NVARCHAR(100)
AS
BEGIN
SET NOCOUNT ON;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

	SELECT
	       l.LoggerMeasurementDeviceId,
	       l.FlowRate,
	       l.Interval,
	       l.CommunicationProtocol,
	       l.CommunicationDetails,
	       l.MabaID,
	       l.Model,
	       l.Manufacturer,
	       l.ConnectionPoints,
	       l.CountAssignedLoggers
	FROM (
		SELECT DISTINCT
		       ltc.ID as LoggerMeasurementDeviceId,
		       ltc.FlowRate,	
			   ltc.Interval,	
			   ltc.Connection as CommunicationProtocol,	
			   ltc.IP AS CommunicationDetails,
			   -- MBA-902: identity + channel count, which the popup had no way to get
			   ltc.MabaID,
			   ltc.Model,
			   ltc.Manufacturer,
			   ltc.ConnectionPoints,
			   SUM(1) OVER( PARTITION BY ltc.ID) as CountAssignedLoggers
		FROM dbo.MeasurementDevices as ltc
		JOIN dbo.MeasurementDevicesMainClasses as mc ON ltc.MainClassId = mc.Id
		JOIN dbo.SensorToLoggerRelation as srl ON ltc.ID = srl.LoggerMeasurementDeviceId AND srl.IsDeleted = 0
		WHERE mc.NameEnglish = 'Data logger' AND ltc.IsDeleted = 0
	) AS l
	ORDER BY
		 TRY_CAST(LEFT(l.MabaID, CHARINDEX('-', l.MabaID + '-') - 1) AS INT),
		 TRY_CAST(LEFT(STUFF(l.MabaID, 1, CHARINDEX('-', l.MabaID + '-'), ''),
		               CHARINDEX('/', STUFF(l.MabaID, 1, CHARINDEX('-', l.MabaID + '-'), '') + '/') - 1) AS INT),
		 l.MabaID

END
