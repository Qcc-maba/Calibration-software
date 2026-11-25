/* QUOTED_IDENTIFIER / ANSI_NULLS ON, whatever client deploys this (sqlcmd defaults QUOTED_IDENTIFIER
   to OFF): the filtered unique index on dbo.CalibrationCycleMarkers needs them, and so does every
   procedure that writes the table, which keeps the settings it was created with. */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
    dbo.MoveCalibrationCycleMarkers                                                        MBA-983
    ---------------------------------------------------------------------------------------------
    Carries a cycle's markers to its new start time when the calibrator changes it - the markers'
    copy of dbo.MoveCalibrationCycleRemarks, and called in the same place.

    dbo.CalibrationCycles has no id: the app's updateCalibrationCycle changes a start time by
    inserting a new cycle row and soft-deleting the old one. Without this call the markers stay on
    the deleted row and drop out of dbo.GetCalibrationCycleMarkers. The app calls it inside that
    same transaction, AFTER the new cycle row exists (the foreign key needs it).

    Only the key moves: the marker times are absolute, so a new cycle start does not move the lines
    on the graph. Markers left live on the target cycle (it was revived from a deleted row that
    still had some) are retired first, so the one-of-each-type rule holds.

    No @Apply: this is one step of the app's cycle update, not a standalone change, and a default
    dry run there would drop the markers silently.

    Nothing to move, or the same time on both sides, writes nothing. One row: Moved.
*/
CREATE OR ALTER PROCEDURE dbo.MoveCalibrationCycleMarkers
    @LoggedInUserEmail  NVARCHAR(255),
    @OrderDetailsItemId INT,
    @OriginalStartDate  DATETIME2(0),
    @NewStartDate       DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @UserId INT = (SELECT TOP (1) ID FROM dbo.Users WHERE Email = @LoggedInUserEmail ORDER BY ID);
    DECLARE @Moved INT = 0;

    IF @UserId IS NULL
        THROW 51000, 'Unknown user.', 1;
    IF @OriginalStartDate IS NULL OR @NewStartDate IS NULL
        THROW 51000, 'Both the original and the new start time are needed.', 1;

    IF @OriginalStartDate <> @NewStartDate
       AND EXISTS (SELECT 1 FROM dbo.CalibrationCycleMarkers
                   WHERE OrderDetailsItemId = @OrderDetailsItemId
                     AND CalibrationCycleStartDate = @OriginalStartDate
                     AND IsDeleted = 0)
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.CalibrationCycles
                       WHERE OrderDetailsItemId = @OrderDetailsItemId
                         AND CalibrationCycleStartDate = @NewStartDate)
            THROW 51000, 'No calibration cycle at the new start time yet - insert it before moving its markers.', 1;

        BEGIN TRANSACTION;

        UPDATE dbo.CalibrationCycleMarkers
        SET IsDeleted = 1, UpdatedDate = GETDATE(), UpdateUserID = @UserId
        WHERE OrderDetailsItemId = @OrderDetailsItemId
          AND CalibrationCycleStartDate = @NewStartDate
          AND IsDeleted = 0;

        UPDATE dbo.CalibrationCycleMarkers
        SET CalibrationCycleStartDate = @NewStartDate, UpdatedDate = GETDATE(), UpdateUserID = @UserId
        WHERE OrderDetailsItemId = @OrderDetailsItemId
          AND CalibrationCycleStartDate = @OriginalStartDate
          AND IsDeleted = 0;
        SET @Moved = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END;

    SELECT Moved = @Moved;
END;
GO
