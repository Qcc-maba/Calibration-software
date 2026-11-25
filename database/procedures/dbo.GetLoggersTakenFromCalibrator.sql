/*
    dbo.GetLoggersTakenFromCalibrator                                                   MBA-1056
    ---------------------------------------------------------------------------------------------
    The loggers another calibrator's save took away from the caller, for the note on page 2
    ("שיוך רגשים לכיול"): "21-337 was moved to <name> on <date>".

    Since MBA-1056 a save takes the whole logger (one owner, the last save wins), and the logger
    simply drops out of the previous owner's list. This is what tells them why.

    One row per logger: the latest open dbo.LoggerOwnershipTransfer from the caller. A row stops
    showing when the caller dismisses it (dbo.DismissLoggerOwnershipTransfers) or saves the logger
    again (dbo.AssignMeasurmentDevicesToCalibrator closes it). The NOT EXISTS is a guard for the
    same case reached some other way: a logger the caller owns again is not "taken".
*/
CREATE OR ALTER PROCEDURE [dbo].[GetLoggersTakenFromCalibrator]
@LoggedInUserEmail NVARCHAR(100)
AS
BEGIN
SET NOCOUNT ON;

DECLARE @LoggedInUserId INT

SELECT @LoggedInUserId = d.UserId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) AS d

IF @LoggedInUserId IS NULL RETURN;

SELECT
       t.LoggerMeasurementDeviceId,
       md.MabaID,
       t.ToUserId AS TakenByUserId,
       LTRIM(RTRIM(CONCAT(u.FirstName, N' ', u.LastName))) AS TakenByName,
       t.TransferredDate
FROM (
    SELECT lot.LoggerMeasurementDeviceId, lot.ToUserId, lot.TransferredDate,
           ROW_NUMBER() OVER (PARTITION BY lot.LoggerMeasurementDeviceId
                              ORDER BY lot.TransferredDate DESC, lot.LoggerOwnershipTransferId DESC) AS rn
    FROM dbo.LoggerOwnershipTransfer AS lot
    WHERE lot.FromUserId = @LoggedInUserId
      AND lot.DismissedDate IS NULL
) AS t
JOIN dbo.MeasurementDevices AS md ON md.ID = t.LoggerMeasurementDeviceId
JOIN dbo.Users AS u ON u.ID = t.ToUserId
WHERE t.rn = 1
  AND md.IsDeleted = 0
  AND NOT EXISTS (SELECT 1 FROM dbo.SensorToLoggerRelation AS srl
                  WHERE srl.LoggerMeasurementDeviceId = t.LoggerMeasurementDeviceId
                    AND srl.IsDeleted = 0
                    AND srl.UpdateUserID = @LoggedInUserId)
ORDER BY t.TransferredDate DESC

END
GO
