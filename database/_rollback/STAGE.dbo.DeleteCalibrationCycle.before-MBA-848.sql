/* STAGE definition of dbo.DeleteCalibrationCycle, captured 2026-11-01 before MBA-848 added the
   remarks soft-delete. Re-run to roll STAGE back. PROD was not read (PROD reads are refused from
   this machine): capture PROD's own body before deploying there. */
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
END
GO
