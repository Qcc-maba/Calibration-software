/*
    dbo.DismissLoggerOwnershipTransfers                                                 MBA-1056
    ---------------------------------------------------------------------------------------------
    The X on page 2's "21-337 was moved to <name>" note. Closes every open
    dbo.LoggerOwnershipTransfer row FROM the caller for that logger, so the note goes away and
    stays away until the logger is taken from them again.

    Only the caller's own rows: a calibrator can dismiss what was taken from them, never what they
    took from somebody else. Idempotent - a second click finds nothing open and changes nothing.
    Returns the number of rows closed.
*/
CREATE OR ALTER PROCEDURE [dbo].[DismissLoggerOwnershipTransfers]
@LoggedInUserEmail NVARCHAR(100),
@LoggerMeasurementDeviceId INT
AS
BEGIN
SET NOCOUNT ON;

DECLARE @LoggedInUserId INT

SELECT @LoggedInUserId = d.UserId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) AS d

IF @LoggedInUserId IS NULL
THROW 51002, 'Incorrect @LoggedInUserEmail passed. No such user.', 1;

UPDATE dbo.LoggerOwnershipTransfer
SET DismissedDate = SYSUTCDATETIME()
WHERE FromUserId = @LoggedInUserId
  AND LoggerMeasurementDeviceId = @LoggerMeasurementDeviceId
  AND DismissedDate IS NULL

SELECT @@ROWCOUNT AS Dismissed

END
GO
