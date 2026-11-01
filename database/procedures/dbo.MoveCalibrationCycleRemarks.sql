/*
    dbo.MoveCalibrationCycleRemarks                                                        MBA-848
    ---------------------------------------------------------------------------------------------
    Carries a cycle's remarks to its new start time when the calibrator changes it.

    dbo.CalibrationCycles has no id: its key is (OrderDetailsItemId, CalibrationCycleStartDate), and
    the app's updateCalibrationCycle changes a start time by inserting a new cycle row and
    soft-deleting the old one. Without this call the remarks stay on the deleted row and drop out of
    dbo.GetCalibrationRemarks. The app calls it inside that same transaction, AFTER the new cycle
    row exists (the foreign key needs it) - the same place it moves the measurement points.

    Live remarks already sitting on the new start time belong to a cycle deleted earlier at that
    time (updateCalibrationCycle revives such a row rather than inserting); they are soft-deleted
    first, so the revived cycle shows only the remarks being moved.

    No @Apply: this is one step of the app's cycle update, not a standalone change, and a default
    dry run there would drop the remarks silently. Moving does not change a remark's text, so it
    runs on a locked (signed) report too.

    Nothing to move, or the same time on both sides, writes nothing. One row: Moved, Replaced.
*/
CREATE OR ALTER PROCEDURE dbo.MoveCalibrationCycleRemarks
    @LoggedInUserEmail  NVARCHAR(255),
    @OrderDetailsItemId INT,
    @OriginalStartDate  DATETIME2(0),
    @NewStartDate       DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @UserId INT = (SELECT ID FROM dbo.Users WHERE Email = @LoggedInUserEmail);
    DECLARE @Moved INT = 0, @Replaced INT = 0;

    IF @UserId IS NULL
        THROW 51000, 'Unknown user.', 1;
    IF @OriginalStartDate IS NULL OR @NewStartDate IS NULL
        THROW 51000, 'Both the original and the new start time are needed.', 1;

    IF @OriginalStartDate <> @NewStartDate
       AND EXISTS (SELECT 1 FROM dbo.CalibrationRemarks
                   WHERE OrderDetailsItemId = @OrderDetailsItemId
                     AND Scope = N'Cycle'
                     AND CalibrationCycleStartDate = @OriginalStartDate
                     AND IsDeleted = 0)
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.CalibrationCycles
                       WHERE OrderDetailsItemId = @OrderDetailsItemId
                         AND CalibrationCycleStartDate = @NewStartDate)
            THROW 51000, 'No calibration cycle at the new start time yet - insert it before moving its remarks.', 1;

        BEGIN TRANSACTION;

        UPDATE dbo.CalibrationRemarks
        SET IsDeleted = 1, UpdatedDate = GETDATE(), UpdateUserID = @UserId
        WHERE OrderDetailsItemId = @OrderDetailsItemId
          AND Scope = N'Cycle'
          AND CalibrationCycleStartDate = @NewStartDate
          AND IsDeleted = 0;
        SET @Replaced = @@ROWCOUNT;

        UPDATE dbo.CalibrationRemarks
        SET CalibrationCycleStartDate = @NewStartDate, UpdatedDate = GETDATE(), UpdateUserID = @UserId
        WHERE OrderDetailsItemId = @OrderDetailsItemId
          AND Scope = N'Cycle'
          AND CalibrationCycleStartDate = @OriginalStartDate
          AND IsDeleted = 0;
        SET @Moved = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END;

    SELECT Moved = @Moved, Replaced = @Replaced;
END;
GO
