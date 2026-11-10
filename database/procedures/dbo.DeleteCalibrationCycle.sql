/*
    dbo.DeleteCalibrationCycle                                                 (Kate, 31/07/2025)
    ---------------------------------------------------------------------------------------------
    Soft-deletes a calibration cycle and everything hanging off it: its measurement points and,
    since MBA-848, its remarks.

    Brought into git on 2026-11-01 for MBA-848, from the STAGE definition (kept in
    database/_rollback/STAGE.dbo.DeleteCalibrationCycle.before-MBA-848.sql). The only change is the
    remarks step.

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

    DECLARE @LoggedInUserId INT 
    SELECT @LoggedInUserId = d.UserId FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

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
END
GO
