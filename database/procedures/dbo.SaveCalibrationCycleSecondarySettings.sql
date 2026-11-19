/*
    dbo.SaveCalibrationCycleSecondarySettings                                              MBA-800
    ---------------------------------------------------------------------------------------------
    Saves one chamber cycle's SECOND measured value: in a Temperature + RH chamber, the cycle's RH
    set point and its Summary screen settings. The temperature value's settings are saved by
    dbo.SaveCalibrationCycleSettings and are not touched here; the controller (type, manufacturer,
    model) is the chamber's and stays there.

    Why a procedure of its own and not more parameters on dbo.SaveCalibrationCycleSettings: that
    procedure takes every parameter without a default on purpose (a forgotten one must fail, not
    clear a value), so adding parameters to it would break every save from the app deployed today
    until the app changes. And a temperature-only chamber has nothing to send here.

    The columns (database/schema/dbo.CalibrationCycles.SecondaryValue.sql) have exactly the meaning
    and rules of their temperature siblings:
        SecondaryUnitId, SecondaryTestedValue               the unit and the set point
        SecondaryToleranceValue / Start / End               the tolerance: middle value, borders
        SecondaryResolution, SecondaryUncertainty
        SecondaryStabilityThreshold, SecondaryUniformityThreshold
                                                            a saved threshold = its box is checked,
                                                            NULL = unchecked (Nofar 15/11, MBA-980)
        SecondaryDisplayValue, SecondaryDisplayResolution, SecondaryIsDisplayEnabled
        SecondaryIsTargetValueEnabled, SecondaryCalculationResolution

    Writes exactly what it is sent: all fourteen values every time, NULL = not set. The parameters
    have no defaults, so a call that forgets one fails instead of clearing it.

    @SecondaryUnitId NULL means "this cycle has no second set point" (a Temperature + RH chamber
    can run a cycle at a temperature only); every other value must then be NULL too, which is how
    the second value is removed from a cycle. A non-NULL unit must be the device's own second unit
    (OrderDetailsItems.SecondaryMeasurementUnitId), so a cycle cannot hold RH settings on a device
    that is not calibrated for RH.

    @Apply  0 (default) writes nothing and reports what would be saved; 1 saves.

    Refuses (THROW 51000) an unknown user; a cycle that does not exist or is deleted; values without
    a unit; a unit that is not the device's second unit; and values that break the sign rules:
    SecondaryToleranceStart <= 0, SecondaryToleranceEnd >= 0, SecondaryStabilityThreshold >= 0,
    SecondaryUniformityThreshold >= 0, SecondaryDisplayResolution >= 0,
    SecondaryCalculationResolution >= 0 (also CHECK constraints on the table). Saving the same values
    again writes nothing (Outcome NoChange).

    One result row: Outcome (WouldSave | Saved | NoChange), OrderDetailsItemId,
    CalibrationCycleStartDate and the fourteen values as they are (or would be) saved.
*/
CREATE OR ALTER PROCEDURE dbo.SaveCalibrationCycleSecondarySettings
    @UserEmail                      NVARCHAR(255),
    @OrderDetailsItemId             INT,
    @CalibrationCycleStartDate      DATETIME2(0),
    @SecondaryUnitId                INT,
    @SecondaryTestedValue           DECIMAL(18,6),
    @SecondaryToleranceValue        DECIMAL(18,6),
    @SecondaryToleranceStart        DECIMAL(18,6),
    @SecondaryToleranceEnd          DECIMAL(18,6),
    @SecondaryResolution            DECIMAL(18,6),
    @SecondaryUncertainty           DECIMAL(18,6),
    @SecondaryStabilityThreshold    DECIMAL(18,6),
    @SecondaryUniformityThreshold   DECIMAL(18,6),
    @SecondaryDisplayValue          DECIMAL(18,6),
    @SecondaryDisplayResolution     DECIMAL(18,6),
    @SecondaryIsDisplayEnabled      BIT,
    @SecondaryIsTargetValueEnabled  BIT,
    @SecondaryCalculationResolution DECIMAL(18,6),
    @Apply                          BIT = 0
/*
EXEC dbo.SaveCalibrationCycleSecondarySettings
    @UserEmail = N'ezequiel_lo@mba.co.il', @OrderDetailsItemId = 3077,
    @CalibrationCycleStartDate = '2026-10-20 09:00:00',
    @SecondaryUnitId = 30, @SecondaryTestedValue = 50,
    @SecondaryToleranceValue = 50, @SecondaryToleranceStart = -3, @SecondaryToleranceEnd = 3,
    @SecondaryResolution = 0.1, @SecondaryUncertainty = 1.5,
    @SecondaryStabilityThreshold = NULL, @SecondaryUniformityThreshold = NULL,
    @SecondaryDisplayValue = 50.2, @SecondaryDisplayResolution = 0.1,
    @SecondaryIsDisplayEnabled = 1, @SecondaryIsTargetValueEnabled = 1,
    @SecondaryCalculationResolution = 0.1,
    @Apply = 0
*/
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* TOP (1): dbo.Users.Email is not unique (see dbo.SaveCalibrationCycleSettings) */
    DECLARE @UserId INT = (SELECT TOP (1) ID FROM dbo.Users WHERE Email = @UserEmail ORDER BY ID);

    IF @UserId IS NULL
        THROW 51000, 'Unknown user.', 1;
    IF @SecondaryUnitId IS NULL
       AND COALESCE(@SecondaryTestedValue, @SecondaryToleranceValue, @SecondaryToleranceStart,
                    @SecondaryToleranceEnd, @SecondaryResolution, @SecondaryUncertainty,
                    @SecondaryStabilityThreshold, @SecondaryUniformityThreshold,
                    @SecondaryDisplayValue, @SecondaryDisplayResolution,
                    @SecondaryCalculationResolution) IS NOT NULL
        THROW 51000, 'The second value''s settings need its unit (SecondaryUnitId); NULL unit = no second set point, so every value must be NULL.', 1;
    IF @SecondaryUnitId IS NULL
       AND (@SecondaryIsDisplayEnabled IS NOT NULL OR @SecondaryIsTargetValueEnabled IS NOT NULL)
        THROW 51000, 'The second value''s checkboxes need its unit (SecondaryUnitId); NULL unit = no second set point, so every value must be NULL.', 1;
    IF @SecondaryToleranceStart > 0
        THROW 51000, 'SecondaryToleranceStart (the lower border) must be 0 or negative.', 1;
    IF @SecondaryToleranceEnd < 0
        THROW 51000, 'SecondaryToleranceEnd (the upper border) must be 0 or positive.', 1;
    IF @SecondaryStabilityThreshold < 0
        THROW 51000, 'SecondaryStabilityThreshold must be 0 or positive.', 1;
    IF @SecondaryUniformityThreshold < 0
        THROW 51000, 'SecondaryUniformityThreshold must be 0 or positive.', 1;
    IF @SecondaryDisplayResolution < 0
        THROW 51000, 'SecondaryDisplayResolution must be 0 or positive.', 1;
    IF @SecondaryCalculationResolution < 0
        THROW 51000, 'SecondaryCalculationResolution must be 0 or positive.', 1;
    BEGIN TRANSACTION;

    /* OrderDetailsItemId is not unique on its own (dbo.GetPreviousCalibrationCycleSettings), so
       any live line with this id and this second unit is enough: cycles are keyed by the id alone.
       Inside the transaction, with the line locked, so an Identification save clearing the unit
       cannot land between this check and the write; ISNULL so a line whose IsDeleted is NULL counts
       as live (review of PR #62; STAGE has none, 2026-11-19). */
    IF @SecondaryUnitId IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM dbo.OrderDetailsItems WITH (UPDLOCK, HOLDLOCK)
                       WHERE OrderDetailsItemId = @OrderDetailsItemId AND ISNULL(IsDeleted, 0) = 0
                         AND SecondaryMeasurementUnitId = @SecondaryUnitId)
        THROW 51000, 'SecondaryUnitId is not this device''s second measured value (OrderDetailsItems.SecondaryMeasurementUnitId); save the Identification page first.', 1;

    DECLARE @Old TABLE (SecondaryUnitId INT, SecondaryTestedValue DECIMAL(18,6),
                        SecondaryToleranceValue DECIMAL(18,6), SecondaryToleranceStart DECIMAL(18,6),
                        SecondaryToleranceEnd DECIMAL(18,6), SecondaryResolution DECIMAL(18,6),
                        SecondaryUncertainty DECIMAL(18,6), SecondaryStabilityThreshold DECIMAL(18,6),
                        SecondaryUniformityThreshold DECIMAL(18,6), SecondaryDisplayValue DECIMAL(18,6),
                        SecondaryDisplayResolution DECIMAL(18,6), SecondaryIsDisplayEnabled BIT,
                        SecondaryIsTargetValueEnabled BIT, SecondaryCalculationResolution DECIMAL(18,6));

    INSERT @Old
    SELECT SecondaryUnitId, SecondaryTestedValue, SecondaryToleranceValue, SecondaryToleranceStart,
           SecondaryToleranceEnd, SecondaryResolution, SecondaryUncertainty,
           SecondaryStabilityThreshold, SecondaryUniformityThreshold, SecondaryDisplayValue,
           SecondaryDisplayResolution, SecondaryIsDisplayEnabled, SecondaryIsTargetValueEnabled,
           SecondaryCalculationResolution
    FROM dbo.CalibrationCycles WITH (UPDLOCK, HOLDLOCK)
    WHERE OrderDetailsItemId = @OrderDetailsItemId
      AND CalibrationCycleStartDate = @CalibrationCycleStartDate
      AND IsDeleted = 0;

    IF NOT EXISTS (SELECT 1 FROM @Old)
        THROW 51000, 'No live calibration cycle starts at that time on this line.', 1;

    /* NULL-safe: INTERSECT treats two NULLs as equal */
    DECLARE @NoChange BIT =
        CASE WHEN EXISTS (SELECT SecondaryUnitId, SecondaryTestedValue, SecondaryToleranceValue,
                                 SecondaryToleranceStart, SecondaryToleranceEnd, SecondaryResolution,
                                 SecondaryUncertainty, SecondaryStabilityThreshold,
                                 SecondaryUniformityThreshold, SecondaryDisplayValue,
                                 SecondaryDisplayResolution, SecondaryIsDisplayEnabled,
                                 SecondaryIsTargetValueEnabled, SecondaryCalculationResolution
                          FROM @Old
                          INTERSECT
                          SELECT @SecondaryUnitId, @SecondaryTestedValue, @SecondaryToleranceValue,
                                 @SecondaryToleranceStart, @SecondaryToleranceEnd, @SecondaryResolution,
                                 @SecondaryUncertainty, @SecondaryStabilityThreshold,
                                 @SecondaryUniformityThreshold, @SecondaryDisplayValue,
                                 @SecondaryDisplayResolution, @SecondaryIsDisplayEnabled,
                                 @SecondaryIsTargetValueEnabled, @SecondaryCalculationResolution)
             THEN 1 ELSE 0 END;

    IF @Apply = 1 AND @NoChange = 0
        UPDATE dbo.CalibrationCycles
        SET SecondaryUnitId                = @SecondaryUnitId,
            SecondaryTestedValue           = @SecondaryTestedValue,
            SecondaryToleranceValue        = @SecondaryToleranceValue,
            SecondaryToleranceStart        = @SecondaryToleranceStart,
            SecondaryToleranceEnd          = @SecondaryToleranceEnd,
            SecondaryResolution            = @SecondaryResolution,
            SecondaryUncertainty           = @SecondaryUncertainty,
            SecondaryStabilityThreshold    = @SecondaryStabilityThreshold,
            SecondaryUniformityThreshold   = @SecondaryUniformityThreshold,
            SecondaryDisplayValue          = @SecondaryDisplayValue,
            SecondaryDisplayResolution     = @SecondaryDisplayResolution,
            SecondaryIsDisplayEnabled      = @SecondaryIsDisplayEnabled,
            SecondaryIsTargetValueEnabled  = @SecondaryIsTargetValueEnabled,
            SecondaryCalculationResolution = @SecondaryCalculationResolution,
            UpdatedDate                    = GETDATE(),
            UpdateUserID                   = @UserId
        WHERE OrderDetailsItemId = @OrderDetailsItemId
          AND CalibrationCycleStartDate = @CalibrationCycleStartDate
          AND IsDeleted = 0;

    COMMIT TRANSACTION;

    SELECT Outcome = CASE WHEN @NoChange = 1 THEN N'NoChange'
                          WHEN @Apply = 1    THEN N'Saved'
                          ELSE N'WouldSave' END,
           OrderDetailsItemId             = @OrderDetailsItemId,
           CalibrationCycleStartDate      = @CalibrationCycleStartDate,
           SecondaryUnitId                = @SecondaryUnitId,
           SecondaryTestedValue           = @SecondaryTestedValue,
           SecondaryToleranceValue        = @SecondaryToleranceValue,
           SecondaryToleranceStart        = @SecondaryToleranceStart,
           SecondaryToleranceEnd          = @SecondaryToleranceEnd,
           SecondaryResolution            = @SecondaryResolution,
           SecondaryUncertainty           = @SecondaryUncertainty,
           SecondaryStabilityThreshold    = @SecondaryStabilityThreshold,
           SecondaryUniformityThreshold   = @SecondaryUniformityThreshold,
           SecondaryDisplayValue          = @SecondaryDisplayValue,
           SecondaryDisplayResolution     = @SecondaryDisplayResolution,
           SecondaryIsDisplayEnabled      = @SecondaryIsDisplayEnabled,
           SecondaryIsTargetValueEnabled  = @SecondaryIsTargetValueEnabled,
           SecondaryCalculationResolution = @SecondaryCalculationResolution;
END;
GO
