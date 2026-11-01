/*
    dbo.SetCalibrationRemarksLock                                                          MBA-848
    ---------------------------------------------------------------------------------------------
    Locks a report's remarks when the report is signed, and unlocks them when a signed report is
    opened again for changes (rejected by the approver, or reopened for update). Remarks are editable
    until the signature and read-only after it (Nofar, MBA-848, 01/11).

    Nothing on the server records the signature today - see dbo.OrderDetailsItems.RemarksLockedDate -
    so the app calls this from the step that signs. Which signature locks, the first calibrator's or
    the second's, is the app's decision; this procedure only records it.

    @IsLocked  1 locks (keeps the first lock time if already locked), 0 unlocks.
    Idempotent. One row: OrderDetailsItemId, IsLocked, RemarksLockedDate, Outcome (Locked |
    Unlocked | NoChange).
*/
CREATE OR ALTER PROCEDURE dbo.SetCalibrationRemarksLock
    @LoggedInUserEmail  NVARCHAR(255),
    @OrderDetailsItemId INT,
    @IsLocked           BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @UserId INT = (SELECT ID FROM dbo.Users WHERE Email = @LoggedInUserEmail);

    IF @UserId IS NULL
        THROW 51000, 'Unknown user.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @OrderDetailsItemId)
        THROW 51000, 'Unknown OrderDetailsItemId.', 1;

    DECLARE @Changed INT;

    UPDATE dbo.OrderDetailsItems
    SET RemarksLockedDate = CASE WHEN @IsLocked = 1 THEN GETDATE() ELSE NULL END,
        UpdatedDate       = GETDATE(),
        UpdateUserID      = @UserId
    WHERE OrderDetailsItemId = @OrderDetailsItemId
      AND (   (@IsLocked = 1 AND RemarksLockedDate IS NULL)
           OR (@IsLocked = 0 AND RemarksLockedDate IS NOT NULL));

    SET @Changed = @@ROWCOUNT;

    SELECT OrderDetailsItemId = @OrderDetailsItemId,
           IsLocked           = CAST(CASE WHEN MAX(RemarksLockedDate) IS NOT NULL THEN 1 ELSE 0 END AS BIT),
           RemarksLockedDate  = MAX(RemarksLockedDate),
           Outcome            = CASE WHEN @Changed = 0 THEN N'NoChange'
                                     WHEN @IsLocked = 1 THEN N'Locked'
                                     ELSE N'Unlocked' END
    FROM dbo.OrderDetailsItems
    WHERE OrderDetailsItemId = @OrderDetailsItemId;
END;
GO
