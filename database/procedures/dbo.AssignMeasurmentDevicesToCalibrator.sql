/*
    dbo.AssignMeasurmentDevicesToCalibrator
    ---------------------------------------------------------------------------------------------
    Original author: Eduard Kudlaiev, 02/07/2025
    Assigns a logger + sensor + channel combination to a calibrator.

    MBA-902 (2026-08-24): pressing refresh in the logger popup wiped the sensor's channel
    assignments. Two defects, both in how @ChannelNumbers was turned into #Channels.

      1. STRING_SPLIT('', ',') returns ONE row holding an empty string, and CAST('' AS INT) is 0.
         An empty parameter therefore inserted a phantom assignment to channel 0. Five such rows
         were found on STAGE.

      2. The final UPDATE marks every already-assigned channel that is not in #Channels as deleted.
         That is right when the calibrator genuinely removed a channel, but an empty list made it
         delete all of them at once - 11 rows in the same second on 2026-07-15.

    Fixed by ignoring blank and non-numeric entries when building #Channels, and by treating an
    empty list as "I have nothing to say about the channels" rather than "remove them all".
    Deliberate removal has its own procedure, DeleteCalibratorSensorChannelAssignment.

    MBA-1056 (2026-11-25): saving a sensor+logger pair that another calibrator already owned kept it
    theirs. The take-over UPDATE ran only WHERE UpdateUserID IS NULL, and
    dbo.GetLogersConfiguredByCalibrator shows a calibrator only their own and unowned relations - so
    the logger vanished from page 2 of the user who had just configured it, and the save said 200.
    Found on STAGE with 21-337 / 21-675 (devices 625 / 801), owned by user 14, saved by 2063.

    Decision (MBA-1056): a logger has one owner and the last save wins. One person uses a logger at
    a time, and its settings are stored once, on its MeasurementDevices row, which this procedure
    already overwrote on every save. So the save now takes the WHOLE logger: every live relation
    of it, not only this sensor's, so the previous owner's station stops picking up a COM port that
    was just changed under it. Each previous owner gets a dbo.LoggerOwnershipTransfer row, which
    page 2 shows them; the saver's own open rows for this logger are closed, since they have it back.

    Also: errors now reach the caller. The CATCH used to SELECT ERROR_MESSAGE() and roll back, which
    the app ignored, so a failed save reported success. And an e-mail that resolves to no user is
    refused instead of saving a relation that belongs to nobody (and so shows to everybody).
*/
CREATE OR ALTER PROCEDURE [dbo].[AssignMeasurmentDevicesToCalibrator]
@LoggedInUserEmail NVARCHAR(100),
@LoggerMeasurementDeviceId INT,
@FlowRate NVARCHAR(20),
@Interval INT,
@CommunicationProtocol NVARCHAR(100),
@CommunicationDetails NVARCHAR(100),
@SensorMeasurementDeviceId INT,
@UnitId INT NULL,
@WorkRangeUnitId INT NULL,
@ChannelNumbers NVARCHAR(MAX)

AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @LoggedInUserId INT
DECLARE @SourceId TINYINT

SELECT
 @LoggedInUserId  = d.UserId
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

/* MBA-1056: a NULL owner is "nobody's", which every calibrator sees. */
IF @LoggedInUserId IS NULL
THROW 51002, 'Incorrect @LoggedInUserEmail passed. No such user.', 1;

if NOT EXISTS (
SELECT 1 FROM dbo.MeasurementDevices as md
JOIN dbo.MeasurementDevicesMainClasses as mc ON md.MainClassId = mc.Id
WHERE mc.NameEnglish = 'Data logger' AND md.ID = @LoggerMeasurementDeviceId AND md.IsDeleted = 0
)
THROW 51000, 'Incorrect @LoggerMeasurementDeviceId passed. Device is not data logger or inactive.', 1;

if NOT EXISTS (
SELECT 1 FROM dbo.MeasurementDevices as md
JOIN dbo.MeasurementDevicesMainClasses as mc ON md.MainClassId = mc.Id
WHERE mc.NameEnglish = 'Sensor' AND md.ID = @SensorMeasurementDeviceId AND md.IsDeleted = 0
)
THROW 51000, 'Incorrect @SensorMeasurementDeviceId passed. Device is not sensor or inactive.', 1;

DROP TABLE IF EXISTS #Channels

CREATE TABLE #Channels
(
ChannelNumber INT
)

/* MBA-902: blanks and stray separators must not become channel 0. */
INSERT #Channels(ChannelNumber)
SELECT DISTINCT CAST(LTRIM(RTRIM(value)) AS INT)
FROM STRING_SPLIT(@ChannelNumbers,',')
WHERE LTRIM(RTRIM(value)) <> ''
      AND LTRIM(RTRIM(value)) NOT LIKE '%[^0-9]%'

DECLARE @HasChannels BIT = IIF(EXISTS (SELECT 1 FROM #Channels), 1, 0)

BEGIN TRY
	
	BEGIN TRAN

	UPDATE [dbo].[MeasurementDevices]
	SET FlowRate = @FlowRate,
		Interval = @Interval,
		Connection = @CommunicationProtocol,
		IP = @CommunicationDetails,
		UpdateDate = GETDATE(),
		UpdateUserID = @LoggedInUserId
	WHERE ID = @LoggerMeasurementDeviceId
	
	/* MBA-902: record WHO configured this. The insert named only the two device ids, so
	   UpdateUserID stayed NULL on every relation ever created - which is why the logger popup
	   could not tell one calibrator's configuration from another's and showed everybody
	   everything. */
	INSERT [dbo].[SensorToLoggerRelation](
	[SensorMeasurementDeviceId],
	[LoggerMeasurementDeviceId],
	[UpdateUserID])
	SELECT @SensorMeasurementDeviceId ,@LoggerMeasurementDeviceId ,@LoggedInUserId
	WHERE NOT EXISTS (SELECT 1 FROM [dbo].[SensorToLoggerRelation] 
					  WHERE [SensorMeasurementDeviceId] = @SensorMeasurementDeviceId
	                  AND [LoggerMeasurementDeviceId] = @LoggerMeasurementDeviceId
					  AND [IsDeleted] = 0)

	/* MBA-1056: the last save takes the whole logger. First tell each previous owner... */
	INSERT [dbo].[LoggerOwnershipTransfer]([LoggerMeasurementDeviceId],[FromUserId],[ToUserId])
	SELECT DISTINCT @LoggerMeasurementDeviceId, srl.UpdateUserID, @LoggedInUserId
	FROM [dbo].[SensorToLoggerRelation] AS srl
	WHERE srl.[LoggerMeasurementDeviceId] = @LoggerMeasurementDeviceId
	  AND srl.[IsDeleted] = 0
	  AND srl.UpdateUserID IS NOT NULL
	  AND srl.UpdateUserID <> @LoggedInUserId

	/* ...then take every live relation of the logger, not only this sensor's. */
	UPDATE [dbo].[SensorToLoggerRelation]
	SET UpdateUserID = @LoggedInUserId, UpdatedDate = GETDATE()
	WHERE [LoggerMeasurementDeviceId] = @LoggerMeasurementDeviceId
	  AND [IsDeleted] = 0
	  AND (UpdateUserID IS NULL OR UpdateUserID <> @LoggedInUserId)

	/* The saver has this logger now: whatever told them it was taken from them is over. */
	UPDATE [dbo].[LoggerOwnershipTransfer]
	SET DismissedDate = SYSUTCDATETIME()
	WHERE [FromUserId] = @LoggedInUserId
	  AND [LoggerMeasurementDeviceId] = @LoggerMeasurementDeviceId
	  AND DismissedDate IS NULL

	/* MBA-1056: never report success for a save the caller cannot see on page 2. */
	IF NOT EXISTS (SELECT 1 FROM [dbo].[SensorToLoggerRelation]
	               WHERE [SensorMeasurementDeviceId] = @SensorMeasurementDeviceId
	                 AND [LoggerMeasurementDeviceId] = @LoggerMeasurementDeviceId
	                 AND [IsDeleted] = 0
	                 AND UpdateUserID = @LoggedInUserId)
		THROW 51003, 'The sensor-logger relation was saved but is not owned by the caller.', 1;

--Insert new data
	INSERT [dbo].[ChannelsToSensorRelation]([SensorMeasurementDeviceId],[LoggerMeasurementDeviceId],[ChannelNumber])
	SELECT @SensorMeasurementDeviceId,@LoggerMeasurementDeviceId, c.ChannelNumber
	FROM #Channels as c
	LEFT JOIN [dbo].[ChannelsToSensorRelation] as cr ON cr.[SensorMeasurementDeviceId] = @SensorMeasurementDeviceId
	                                                AND cr.[LoggerMeasurementDeviceId] = @LoggerMeasurementDeviceId
													AND c.ChannelNumber = cr.ChannelNumber
							
	WHERE cr.[SensorMeasurementDeviceId] IS NULL

--In case if it was previously assigned revert deleted flag
--MBA-902: only when a list was actually supplied. An empty list is not a request to unassign
--         everything - that is what pressing refresh was doing.
    IF @HasChannels = 1
    BEGIN
        UPDATE cr
	    SET IsDeleted = IIF(c.ChannelNumber IS NULL,1,0),
		    UpdatedDate = GETDATE(),
		    UpdateUserID = @LoggedInUserId
	    FROM [dbo].[ChannelsToSensorRelation] as cr
	    LEFT JOIN #Channels as c ON cr.ChannelNumber = c.ChannelNumber
	    WHERE cr.[SensorMeasurementDeviceId] = @SensorMeasurementDeviceId
	          AND cr.[LoggerMeasurementDeviceId] = @LoggerMeasurementDeviceId
    END

	COMMIT
END TRY

BEGIN CATCH
	/* MBA-1056: re-raise. SELECT ERROR_MESSAGE() returned a result set nobody read, so a failed save
	   reached the app as success. */
	IF @@TRANCOUNT > 0 ROLLBACK;
	THROW;
END CATCH
END
GO
