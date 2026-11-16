/*
    dbo.SetReportDisplayOptions                                                            MBA-1004
    ---------------------------------------------------------------------------------------------
    Saves the Report screen's display choices for one order line, so the second calibrator opens
    the report the way the first calibrator left it (Nofar, MBA-1004, 16/11). Read back through
    dbo.GetOrderDetailsDevices.

    Today it carries one option, "% of Spec" (dbo.OrderDetailsItems.ShouldShowPercentOfSpec). The
    other Report-screen toggles (Drawing, Colors) are still browser-only; they can join here as
    further NULL-means-keep parameters without breaking an existing caller. Graph is chosen on the
    Identification screen and stays with dbo.AssignProductIdentificationData.

    The line is addressed by its primary key (@OrderDetailId, @OrderDetailsItemId):
    OrderDetailsItemId alone is not unique (STAGE item 112 sits on order lines 54 and 163, 16/11).

    @ShouldShowPercentOfSpec  1 / 0 sets it; NULL leaves the stored value as it is.

    Refused (51000), so a stale or wrong caller cannot change a report behind the signer's back:
      - an unknown or inactive user, an unknown or deleted line;
      - the line's second calibrator, unless they are also its main calibrator: the second
        calibrator signs the report as the first one left it;
      - a change once the report is signed (RemarksLockedDate set, see that column). Re-sending
        the stored value is still accepted (NoChange), so an idempotent re-submit does not fail.
    Not enforced: "only the main calibrator may write". MainCalibratorId is NULL on 6,118 of the
    6,186 STAGE lines (16/11), so that rule would refuse almost every line.

    Idempotent. One row: OrderDetailId, OrderDetailsItemId, ShouldShowPercentOfSpec,
    Outcome (Updated | NoChange).
*/
CREATE OR ALTER PROCEDURE dbo.SetReportDisplayOptions
    @LoggedInUserEmail       NVARCHAR(255),
    @OrderDetailId           INT,
    @OrderDetailsItemId      INT,
    @ShouldShowPercentOfSpec BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @UserId INT, @IsActive BIT;
    SELECT TOP (1) @UserId = ID, @IsActive = IsActive
    FROM dbo.Users
    WHERE Email = @LoggedInUserEmail
    ORDER BY IsActive DESC;

    IF @UserId IS NULL
        THROW 51000, 'Unknown user.', 1;
    IF ISNULL(@IsActive, 0) = 0
        THROW 51000, 'Inactive user.', 1;

    DECLARE @Current BIT, @MainId INT, @SecondId INT, @LockedDate DATETIME2(0);
    SELECT @Current    = ShouldShowPercentOfSpec,
           @MainId     = MainCalibratorId,
           @SecondId   = SecondCalibratorId,
           @LockedDate = RemarksLockedDate
    FROM dbo.OrderDetailsItems
    WHERE OrderDetailId = @OrderDetailId
      AND OrderDetailsItemId = @OrderDetailsItemId
      AND IsDeleted = 0;

    IF @@ROWCOUNT = 0
        THROW 51000, 'Unknown order line.', 1;

    DECLARE @WouldChange BIT =
        CASE WHEN @ShouldShowPercentOfSpec IS NOT NULL AND @ShouldShowPercentOfSpec <> @Current
             THEN 1 ELSE 0 END;

    IF @WouldChange = 1 AND @SecondId = @UserId AND (@MainId IS NULL OR @MainId <> @UserId)
        THROW 51000, 'The second calibrator cannot change the report options.', 1;
    IF @WouldChange = 1 AND @LockedDate IS NOT NULL
        THROW 51000, 'The report is signed; its options can no longer change.', 1;

    /* UpdatedDate / UpdateUserID are left alone: DBA/sql/02_usp_SyncHealthCheck.sql reads
       MAX(UpdatedDate) on this table as the last sync time, and a report option is not a sync */
    IF @WouldChange = 1
        UPDATE dbo.OrderDetailsItems
        SET ShouldShowPercentOfSpec = @ShouldShowPercentOfSpec
        WHERE OrderDetailId = @OrderDetailId
          AND OrderDetailsItemId = @OrderDetailsItemId
          AND IsDeleted = 0;

    SELECT OrderDetailId,
           OrderDetailsItemId,
           ShouldShowPercentOfSpec,
           Outcome = CASE WHEN @WouldChange = 1 THEN N'Updated' ELSE N'NoChange' END
    FROM dbo.OrderDetailsItems
    WHERE OrderDetailId = @OrderDetailId
      AND OrderDetailsItemId = @OrderDetailsItemId
      AND IsDeleted = 0;
END;
GO
