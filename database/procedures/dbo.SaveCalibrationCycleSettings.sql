/*
    dbo.SaveCalibrationCycleSettings                                                       MBA-980
    ---------------------------------------------------------------------------------------------
    Saves one chamber cycle's Summary screen settings:
      - the Tolerance (middle value, lower and upper border), the set-value resolution, the
        uncertainty, and the stability and uniformity thresholds;
      - (15/11) the chamber's Display reading with its resolution and checkbox, the Target Value
        checkbox, the Controller (type, manufacturer, model) and the Calculation Resolution.
    The app calls it whenever one of them changes, so a reload or re-opening the order keeps them,
    a regenerated report shows the same values, and the device's next calibration can start from
    them (dbo.GetPreviousCalibrationCycleSettings).

    It is a procedure of its own, not more parameters on dbo.AddCalibrationCycle, on purpose: the
    graph screen saves cycles through AddCalibrationCycle and the app's inline update, and neither
    knows the Summary values. If they carried the settings, a graph-screen save would overwrite them
    with NULL. Here, only this procedure writes these columns.

    Writes exactly what it is sent: all fifteen values every time, NULL = not set (that is how a
    field is cleared). The parameters have no defaults, so a call that forgets one fails instead of
    clearing it. A blank manufacturer or model is stored as NULL; one longer than 100 characters is
    refused, not cut (the parameters are wider than the columns so that the length can be checked).

    Stability / Uniformity checkboxes: a saved threshold (any value, 0 included) means the box is
    checked; NULL means unchecked. An unchecked box saves NULL (Nofar 15/11: "if the box is
    unchecked, the value should not be saved", and it stays unchecked when the order is reopened).
    Both boxes start unchecked (Nofar 20/10), so a never-saved cycle and an unchecked one look the
    same, and an unchecked box carries over as unchecked.

    @ControllerTypeStatusId is a dbo.Statuses row of category 'ControllerType' (Digital / Analog,
    database/data/Seed-ControllerTypeStatuses.sql); the app gets the ids and labels from
    dbo.GetStatusByCategory @StatusDescriptionENG = N'ControllerType'.

    The cycle must exist and be live, so a new cycle is saved (AddCalibrationCycle) before its
    settings. Cycles have no id; the cycle is its line and its start time.

    @Apply  0 (default) writes nothing and reports what would be saved; 1 saves.

    Refuses (THROW 51000) an unknown user, a cycle that does not exist or is deleted, a controller
    type that is not a 'ControllerType' status, a manufacturer or model over 100 characters, and
    values that break the sign rules: ToleranceStart <= 0, ToleranceEnd >= 0,
    StabilityThreshold >= 0, UniformityThreshold >= 0, DisplayResolution >= 0,
    CalculationResolution >= 0 (also CHECK constraints on the table). The two resolutions may be 0
    because the Summary screen starts them at 0. Saving the same values again writes nothing (Outcome
    NoChange); text is compared exactly, so a change of case is a change.

    One result row: Outcome (WouldSave | Saved | NoChange), OrderDetailsItemId,
    CalibrationCycleStartDate and the fifteen values as they are (or would be) saved.
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
    @DisplayValue              DECIMAL(18,6),
    @DisplayResolution         DECIMAL(18,6),
    @IsDisplayEnabled          BIT,
    @IsTargetValueEnabled      BIT,
    @ControllerTypeStatusId    INT,
    @ControllerManufacturer    NVARCHAR(4000),   -- column is 100; wider so a longer value is refused, not cut
    @ControllerModel           NVARCHAR(4000),
    @CalculationResolution     DECIMAL(18,6),
    @Apply                     BIT = 0
/*
EXEC dbo.SaveCalibrationCycleSettings
    @UserEmail = N'ezequiel_lo@mba.co.il', @OrderDetailsItemId = 3077,
    @CalibrationCycleStartDate = '2026-10-20 09:00:00',
    @ToleranceValue = 20, @ToleranceStart = -0.5, @ToleranceEnd = 0.5, @Resolution = 1,
    @Uncertainty = 0.3, @StabilityThreshold = NULL, @UniformityThreshold = 1,
    @DisplayValue = 20.1, @DisplayResolution = 0.1, @IsDisplayEnabled = 1, @IsTargetValueEnabled = 1,
    @ControllerTypeStatusId = NULL, @ControllerManufacturer = N'Binder', @ControllerModel = N'KB 240',
    @CalculationResolution = 0.1,
    @Apply = 0
*/
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* TOP (1): dbo.Users.Email is not unique (PROD has 38 addresses shared by 79 users, 2026-11-11),
       and a plain scalar lookup would fail the save with error 512. The id only records who saved. */
    DECLARE @UserId INT = (SELECT TOP (1) ID FROM dbo.Users WHERE Email = @UserEmail ORDER BY ID);

    SET @ControllerManufacturer = NULLIF(LTRIM(RTRIM(@ControllerManufacturer)), N'');
    SET @ControllerModel        = NULLIF(LTRIM(RTRIM(@ControllerModel)), N'');

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
    IF @DisplayResolution < 0
        THROW 51000, 'DisplayResolution must be 0 or positive.', 1;
    IF @CalculationResolution < 0
        THROW 51000, 'CalculationResolution must be 0 or positive.', 1;
    IF LEN(@ControllerManufacturer) > 100
        THROW 51000, 'ControllerManufacturer is longer than 100 characters.', 1;
    IF LEN(@ControllerModel) > 100
        THROW 51000, 'ControllerModel is longer than 100 characters.', 1;
    IF @ControllerTypeStatusId IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM dbo.Statuses AS s
                       JOIN dbo.StatusesCategories AS c ON c.StatusCategoryId = s.StatusCategoryId
                       WHERE s.StatusId = @ControllerTypeStatusId AND c.StatusDescriptionENG = N'ControllerType')
        THROW 51000, 'ControllerTypeStatusId must be a ControllerType status (dbo.GetStatusByCategory N''ControllerType'').', 1;

    BEGIN TRANSACTION;

    DECLARE @Old TABLE (ToleranceValue DECIMAL(18,6), ToleranceStart DECIMAL(18,6), ToleranceEnd DECIMAL(18,6),
                        Resolution DECIMAL(18,6), Uncertainty DECIMAL(18,6),
                        StabilityThreshold DECIMAL(18,6), UniformityThreshold DECIMAL(18,6),
                        DisplayValue DECIMAL(18,6), DisplayResolution DECIMAL(18,6),
                        IsDisplayEnabled BIT, IsTargetValueEnabled BIT, ControllerTypeStatusId INT,
                        ControllerManufacturer NVARCHAR(100), ControllerModel NVARCHAR(100),
                        CalculationResolution DECIMAL(18,6));

    /* the key is (OrderDetailsItemId, CalibrationCycleStartDate): a seek, holding this one row */
    INSERT @Old
    SELECT ToleranceValue, ToleranceStart, ToleranceEnd, Resolution, Uncertainty,
           StabilityThreshold, UniformityThreshold,
           DisplayValue, DisplayResolution, IsDisplayEnabled, IsTargetValueEnabled, ControllerTypeStatusId,
           ControllerManufacturer, ControllerModel, CalculationResolution
    FROM dbo.CalibrationCycles WITH (UPDLOCK, HOLDLOCK)
    WHERE OrderDetailsItemId = @OrderDetailsItemId
      AND CalibrationCycleStartDate = @CalibrationCycleStartDate
      AND IsDeleted = 0;

    IF NOT EXISTS (SELECT 1 FROM @Old)
        THROW 51000, 'No live calibration cycle starts at that time on this line.', 1;

    /* NULL-safe: INTERSECT treats two NULLs as equal. Text compared in a binary collation, so a
       change of case or accent is saved, not reported as NoChange. */
    DECLARE @NoChange BIT =
        CASE WHEN EXISTS (SELECT ToleranceValue, ToleranceStart, ToleranceEnd, Resolution, Uncertainty,
                                 StabilityThreshold, UniformityThreshold,
                                 DisplayValue, DisplayResolution, IsDisplayEnabled, IsTargetValueEnabled,
                                 ControllerTypeStatusId,
                                 ControllerManufacturer COLLATE Latin1_General_100_BIN2,
                                 ControllerModel COLLATE Latin1_General_100_BIN2,
                                 CalculationResolution
                          FROM @Old
                          INTERSECT
                          SELECT @ToleranceValue, @ToleranceStart, @ToleranceEnd, @Resolution, @Uncertainty,
                                 @StabilityThreshold, @UniformityThreshold,
                                 @DisplayValue, @DisplayResolution, @IsDisplayEnabled, @IsTargetValueEnabled,
                                 @ControllerTypeStatusId,
                                 @ControllerManufacturer COLLATE Latin1_General_100_BIN2,
                                 @ControllerModel COLLATE Latin1_General_100_BIN2,
                                 @CalculationResolution)
             THEN 1 ELSE 0 END;

    IF @Apply = 1 AND @NoChange = 0
        UPDATE dbo.CalibrationCycles
        SET ToleranceValue         = @ToleranceValue,
            ToleranceStart         = @ToleranceStart,
            ToleranceEnd           = @ToleranceEnd,
            Resolution             = @Resolution,
            Uncertainty            = @Uncertainty,
            StabilityThreshold     = @StabilityThreshold,
            UniformityThreshold    = @UniformityThreshold,
            DisplayValue           = @DisplayValue,
            DisplayResolution      = @DisplayResolution,
            IsDisplayEnabled       = @IsDisplayEnabled,
            IsTargetValueEnabled   = @IsTargetValueEnabled,
            ControllerTypeStatusId = @ControllerTypeStatusId,
            ControllerManufacturer = @ControllerManufacturer,
            ControllerModel        = @ControllerModel,
            CalculationResolution  = @CalculationResolution,
            UpdatedDate            = GETDATE(),
            UpdateUserID           = @UserId
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
           UniformityThreshold       = @UniformityThreshold,
           DisplayValue              = @DisplayValue,
           DisplayResolution         = @DisplayResolution,
           IsDisplayEnabled          = @IsDisplayEnabled,
           IsTargetValueEnabled      = @IsTargetValueEnabled,
           ControllerTypeStatusId    = @ControllerTypeStatusId,
           ControllerManufacturer    = @ControllerManufacturer,
           ControllerModel           = @ControllerModel,
           CalculationResolution     = @CalculationResolution;
END;
GO
