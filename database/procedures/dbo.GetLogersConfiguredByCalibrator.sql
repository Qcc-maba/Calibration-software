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

    2026-08-25 (MBA-902): the popup showed every logger anyone had ever configured. This procedure
    resolved @LoggedInUserId and @SourceId at the top and then never used them, so a calibrator saw
    other people's work and could not find their own.

    It now returns the loggers THIS caller configured. Relations with no owner recorded are still
    returned: SensorToLoggerRelation.UpdateUserID was NULL on every row because the insert in
    dbo.AssignMeasurmentDevicesToCalibrator named only the two device ids and never the user. That
    is fixed on the write side as of the same date, so the unowned set is historical and shrinks;
    dropping it instead would have emptied the popup for everyone on the day of the change.

    Pass @OnlyMine = 0 to see every configured logger, which is what this did before.
*/
CREATE OR ALTER PROCEDURE [dbo].[GetLogersConfiguredByCalibrator] 
@LoggedInUserEmail NVARCHAR(100),
@OnlyMine BIT = 1
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
		  -- MBA-902: this caller's own configurations, plus the ones that predate owner tracking
		  AND (@OnlyMine = 0
		       OR srl.UpdateUserID = @LoggedInUserId
		       OR srl.UpdateUserID IS NULL)
	) AS l
	ORDER BY
		 TRY_CAST(LEFT(l.MabaID, CHARINDEX('-', l.MabaID + '-') - 1) AS INT),
		 TRY_CAST(LEFT(STUFF(l.MabaID, 1, CHARINDEX('-', l.MabaID + '-'), ''),
		               CHARINDEX('/', STUFF(l.MabaID, 1, CHARINDEX('-', l.MabaID + '-'), '') + '/') - 1) AS INT),
		 l.MabaID

END
