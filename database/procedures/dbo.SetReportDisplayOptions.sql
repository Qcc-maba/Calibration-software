/*
    dbo.SetReportDisplayOptions                                                            MBA-1004
    ---------------------------------------------------------------------------------------------
    Saves the Report screen's display choices for one order line, so the second calibrator opens
    the report the way the first calibrator left it (Nofar, MBA-1004, 16/11). Read back through
    dbo.GetOrderDetailsDevices.

    Today it carries one option, "% of Spec" (dbo.OrderDetailsItems.ShouldShowPercentOfSpec). The
    other Report-screen toggles (Drawing, Colors) are still browser-only; they can join here as
    further NULL-means-keep parameters without breaking an existing caller.

    @ShouldShowPercentOfSpec  1 / 0 sets it; NULL leaves the stored value as it is.
    Who may change it (the second calibrator may not) is the app's decision, as with
    dbo.SetCalibrationRemarksLock; this procedure only records it.

    Idempotent. One row: OrderDetailsItemId, ShouldShowPercentOfSpec, Outcome (Updated | NoChange).
*/
CREATE OR ALTER PROCEDURE dbo.SetReportDisplayOptions
    @LoggedInUserEmail       NVARCHAR(255),
    @OrderDetailsItemId      INT,
    @ShouldShowPercentOfSpec BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = @LoggedInUserEmail)
        THROW 51000, 'Unknown user.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @OrderDetailsItemId)
        THROW 51000, 'Unknown OrderDetailsItemId.', 1;

    /* UpdatedDate / UpdateUserID are left alone: DBA/sql/02_usp_SyncHealthCheck.sql reads
       MAX(UpdatedDate) on this table as the last sync time, and a report option is not a sync */
    UPDATE dbo.OrderDetailsItems
    SET ShouldShowPercentOfSpec = @ShouldShowPercentOfSpec
    WHERE OrderDetailsItemId = @OrderDetailsItemId
      AND @ShouldShowPercentOfSpec IS NOT NULL
      AND ShouldShowPercentOfSpec <> @ShouldShowPercentOfSpec;

    DECLARE @Changed INT = @@ROWCOUNT;

    SELECT OrderDetailsItemId      = @OrderDetailsItemId,
           ShouldShowPercentOfSpec = CAST(MAX(CAST(ShouldShowPercentOfSpec AS TINYINT)) AS BIT),
           Outcome                 = CASE WHEN @Changed = 0 THEN N'NoChange' ELSE N'Updated' END
    FROM dbo.OrderDetailsItems
    WHERE OrderDetailsItemId = @OrderDetailsItemId;
END;
GO
