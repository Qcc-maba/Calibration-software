/*
    dbo.SaveCalibrationCycleSettings                                                       MBA-980
    ---------------------------------------------------------------------------------------------
    Saves one chamber cycle's settings: the Tolerance (middle value, lower and upper border), the
    set-value resolution, the uncertainty, and the stability and uniformity thresholds. The app
    calls it whenever one of them changes, so a reload or re-opening the order keeps them, and the
    device's next calibration can start from them (dbo.GetPreviousCalibrationCycleSettings).

    It is a procedure of its own, not more parameters on dbo.AddCalibrationCycle, on purpose: the
    graph screen saves cycles through AddCalibrationCycle and the app's inline update, and neither
    knows the Summary values. If they carried the settings, a graph-screen save would overwrite them
    with NULL. Here, only this procedure writes the seven columns.

    Writes exactly what it is sent: all seven values every time, NULL = not set (that is how a field
    is cleared). The parameters have no defaults, so a call that forgets one fails instead of
    clearing it.

    The cycle must exist and be live, so a new cycle is saved (AddCalibrationCycle) before its
    settings. Cycles have no id; the cycle is its line and its start time.

    @Apply  0 (default) writes nothing and reports what would be saved; 1 saves.

    Refuses (THROW 51000) an unknown user, a cycle that does not exist or is deleted, and values
    that break the sign rules: ToleranceStart <= 0, ToleranceEnd >= 0, StabilityThreshold >= 0,
    UniformityThreshold >= 0 (also CHECK constraints on the table). Saving the same values again
    writes nothing (Outcome NoChange).

    One result row: Outcome (WouldSave | Saved | NoChange), OrderDetailsItemId,
    CalibrationCycleStartDate and the seven values as they are (or would be) saved.
*/
CREATE OR ALTER PROCEDURE dbo.SaveCalibrationCycleSettings
    @UserEmail                 NVARCHAR(255),
    @OrderDetailsItemId        INT,
    @CalibrationCycleStartDate DATETIME2(0),
    @ToleranceValue            DECIMAL(18,6),
    @ToleranceStart            DECIMAL(18,6),
    @ToleranceEnd              DECIMAL(18,6),
    @Resolution                DECIMAL(18,6),
    @Uncertainty               DECIMAL(18,6),
    @StabilityThreshold        DECIMAL(18,6),
    @UniformityThreshold       DECIMAL(18,6),
    @Apply                     BIT = 0
/*
EXEC dbo.SaveCalibrationCycleSettings
    @UserEmail = N'ezequiel_lo@mba.co.il', @OrderDetailsItemId = 3077,
    @CalibrationCycleStartDate = '2026-10-20 09:00:00',
    @ToleranceValue = 20, @ToleranceStart = -0.5, @ToleranceEnd = 0.5, @Resolution = 1,
    @Uncertainty = 0.3, @StabilityThreshold = NULL, @UniformityThreshold = 1,
    @Apply = 0
*/
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* TOP (1): dbo.Users.Email is not unique (PROD has 38 addresses shared by 79 users, 2026-11-11),
       and a plain scalar lookup would fail the save with error 512. The id only records who saved. */
    DECLARE @UserId INT = (SELECT TOP (1) ID FROM dbo.Users WHERE Email = @UserEmail ORDER BY ID);

    IF @UserId IS NULL
        THROW 51000, 'Unknown user.', 1;
    IF @ToleranceStart > 0
        THROW 51000, 'ToleranceStart (the lower border) must be 0 or negative.', 1;
    IF @ToleranceEnd < 0
        THROW 51000, 'ToleranceEnd (the upper border) must be 0 or positive.', 1;
    IF @StabilityThreshold < 0
        THROW 51000, 'StabilityThreshold must be 0 or positive.', 1;
    IF @UniformityThreshold < 0
        THROW 51000, 'UniformityThreshold must be 0 or positive.', 1;

    BEGIN TRANSACTION;

    DECLARE @Old TABLE (ToleranceValue DECIMAL(18,6), ToleranceStart DECIMAL(18,6), ToleranceEnd DECIMAL(18,6),
                        Resolution DECIMAL(18,6), Uncertainty DECIMAL(18,6),
                        StabilityThreshold DECIMAL(18,6), UniformityThreshold DECIMAL(18,6));

    /* the key is (OrderDetailsItemId, CalibrationCycleStartDate): a seek, holding this one row */
    INSERT @Old
    SELECT ToleranceValue, ToleranceStart, ToleranceEnd, Resolution, Uncertainty,
           StabilityThreshold, UniformityThreshold
    FROM dbo.CalibrationCycles WITH (UPDLOCK, HOLDLOCK)
    WHERE OrderDetailsItemId = @OrderDetailsItemId
      AND CalibrationCycleStartDate = @CalibrationCycleStartDate
      AND IsDeleted = 0;

    IF NOT EXISTS (SELECT 1 FROM @Old)
        THROW 51000, 'No live calibration cycle starts at that time on this line.', 1;

    /* NULL-safe: INTERSECT treats two NULLs as equal */
    DECLARE @NoChange BIT =
        CASE WHEN EXISTS (SELECT ToleranceValue, ToleranceStart, ToleranceEnd, Resolution, Uncertainty,
                                 StabilityThreshold, UniformityThreshold
                          FROM @Old
                          INTERSECT
                          SELECT @ToleranceValue, @ToleranceStart, @ToleranceEnd, @Resolution, @Uncertainty,
                                 @StabilityThreshold, @UniformityThreshold)
             THEN 1 ELSE 0 END;

    IF @Apply = 1 AND @NoChange = 0
        UPDATE dbo.CalibrationCycles
        SET ToleranceValue      = @ToleranceValue,
            ToleranceStart      = @ToleranceStart,
            ToleranceEnd        = @ToleranceEnd,
            Resolution          = @Resolution,
            Uncertainty         = @Uncertainty,
            StabilityThreshold  = @StabilityThreshold,
            UniformityThreshold = @UniformityThreshold,
            UpdatedDate         = GETDATE(),
            UpdateUserID        = @UserId
        WHERE OrderDetailsItemId = @OrderDetailsItemId
          AND CalibrationCycleStartDate = @CalibrationCycleStartDate
          AND IsDeleted = 0;

    COMMIT TRANSACTION;

    SELECT Outcome = CASE WHEN @NoChange = 1 THEN N'NoChange'
                          WHEN @Apply = 1    THEN N'Saved'
                          ELSE N'WouldSave' END,
           OrderDetailsItemId        = @OrderDetailsItemId,
           CalibrationCycleStartDate = @CalibrationCycleStartDate,
           ToleranceValue            = @ToleranceValue,
           ToleranceStart            = @ToleranceStart,
           ToleranceEnd              = @ToleranceEnd,
           Resolution                = @Resolution,
           Uncertainty               = @Uncertainty,
           StabilityThreshold        = @StabilityThreshold,
           UniformityThreshold       = @UniformityThreshold;
END;
GO
