/*
    dbo.GetLoggerOtherOwners                                                            MBA-1056
    ---------------------------------------------------------------------------------------------
    Who, other than the caller, owns a live configuration of this logger right now.

    The logger setup dialog asks this before Confirm. A save takes the whole logger
    (dbo.AssignMeasurmentDevicesToCalibrator, MBA-1056: one owner, the last save wins), so a
    calibrator about to take a logger from a colleague is asked first: "21-337 is set up by <name>.
    Saving moves it to you."

    No rows = nobody else has it (free, unowned, or already the caller's). Relations with a NULL
    owner predate MBA-902's owner tracking and belong to nobody, so they are not listed.
    Usually one row; a logger whose sensors were saved by different people before MBA-1056 can
    return more (619 on STAGE on 25.11.2026: users 19 and 14).
*/
CREATE OR ALTER PROCEDURE [dbo].[GetLoggerOtherOwners]
@LoggedInUserEmail NVARCHAR(100),
@LoggerMeasurementDeviceId INT
AS
BEGIN
SET NOCOUNT ON;

DECLARE @LoggedInUserId INT

SELECT @LoggedInUserId = d.UserId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) AS d

SELECT
       u.ID AS UserId,
       LTRIM(RTRIM(CONCAT(u.FirstName, N' ', u.LastName))) AS FullName,
       MAX(COALESCE(srl.UpdatedDate, srl.CreateDate)) AS OwnedSince
FROM dbo.SensorToLoggerRelation AS srl
JOIN dbo.Users AS u ON u.ID = srl.UpdateUserID
WHERE srl.LoggerMeasurementDeviceId = @LoggerMeasurementDeviceId
  AND srl.IsDeleted = 0
  AND (@LoggedInUserId IS NULL OR srl.UpdateUserID <> @LoggedInUserId)
GROUP BY u.ID, u.FirstName, u.LastName
ORDER BY OwnedSince DESC

END
GO
