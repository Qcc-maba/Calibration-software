/* QUOTED_IDENTIFIER / ANSI_NULLS ON, whatever client deploys this (sqlcmd defaults QUOTED_IDENTIFIER
   to OFF): the filtered unique index on dbo.CalibrationCycleMarkers needs them, and so does every
   procedure that writes the table, which keeps the settings it was created with. */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
    dbo.DeleteCalibrationCycle                                                 (Kate, 31/07/2025)
    ---------------------------------------------------------------------------------------------
    Soft-deletes a calibration cycle and everything hanging off it: its measurement points and,
    since MBA-848, its remarks.

    Brought into git on 2026-11-01 for MBA-848, from the STAGE definition (kept in
    database/_rollback/STAGE.dbo.DeleteCalibrationCycle.before-MBA-848.sql). The only change is the
    remarks step; MBA-983 added the markers step (deploy dbo.CalibrationCycleMarkers first) and
    put the four steps in one transaction with XACT_ABORT ON, so a failing step leaves the cycle
    and everything on it as it was instead of half deleted.

    Why the remarks must go too: dbo.AddCalibrationCycle does not insert when a row already exists at
    the same (OrderDetailsItemId, CalibrationCycleStartDate) - it revives the deleted one. Remarks
    left live on a deleted cycle would therefore reappear, and be printed, on a new cycle added at
    the same start time.
*/
CREATE OR ALTER PROCEDURE [dbo].[DeleteCalibrationCycle]
    @LoggedInUserEmail NVARCHAR(200),
    @OrderDetailsItemId INT,
    @CalibrationCycleStartDate DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LoggedInUserId INT 
    SELECT @LoggedInUserId = d.UserId FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

    BEGIN TRANSACTION;

    -- Soft delete the cycle
    UPDATE [dbo].[CalibrationCycles]
    SET IsDeleted = 1,
        UpdatedDate = GETDATE(),
        UpdateUserID = @LoggedInUserId
    WHERE OrderDetailsItemId = @OrderDetailsItemId
      AND CalibrationCycleStartDate = @CalibrationCycleStartDate
      AND IsDeleted = 0;

    -- Soft delete associated points
    UPDATE [dbo].[MeasurmentPointsToCalibrationCycles]
    SET IsDeleted = 1,
        UpdatedDate = GETDATE(),
        UpdateUserID = @LoggedInUserId
    WHERE OrderDetailsItemId = @OrderDetailsItemId
      AND CalibrationCycleStartDate = @CalibrationCycleStartDate
      AND IsDeleted = 0;

    -- Soft delete its remarks (MBA-848)
    UPDATE [dbo].[CalibrationRemarks]
    SET IsDeleted = 1,
        UpdatedDate = GETDATE(),
        UpdateUserID = @LoggedInUserId
    WHERE OrderDetailsItemId = @OrderDetailsItemId
      AND Scope = N'Cycle'
      AND CalibrationCycleStartDate = @CalibrationCycleStartDate
      AND IsDeleted = 0;

    -- Soft delete its markers (MBA-983), for the same reason as the remarks
    UPDATE [dbo].[CalibrationCycleMarkers]
    SET IsDeleted = 1,
        UpdatedDate = GETDATE(),
        UpdateUserID = @LoggedInUserId
    WHERE OrderDetailsItemId = @OrderDetailsItemId
      AND CalibrationCycleStartDate = @CalibrationCycleStartDate
      AND IsDeleted = 0;

    COMMIT TRANSACTION;
END
GO
