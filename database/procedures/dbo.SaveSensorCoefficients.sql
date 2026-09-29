/*
    dbo.SaveSensorCoefficients                                                         MBA-816
    ---------------------------------------------------------------------------------------------
    Stores a precision sensor's ITS-90 coefficients - RTP, A4, B4, A7, B7, C7 - against the sensor,
    found by MabaID (Nofar, MBA-816, 24/09). Called by the "Save to DB" button after a calibration,
    and usable for coefficients entered by hand (MBA-831).

    What the coefficients are
    -------------------------
    ITS-90 turns a platinum thermometer's resistance into temperature through a reference function
    that is the same for every sensor, plus a small per-sensor correction:
        W   = R / RTP                 RTP = the sensor's resistance at the triple point of water
        W <= 1 (below 0 degC)   dW = (A4 + B4 * ln W) * (W - 1)
        W >  1 (above 0 degC)   dW = A7 (W-1) + B7 (W-1)^2 + C7 (W-1)^3
    HydraCalculations.CalcResistanceToTemperatureITS90 in the station does exactly this - with one
    sensor's values (21-214) hard-coded for every sensor. Storing them per sensor is what lets that
    be fixed (MBA-831).

    All six are required (Nofar, 29/09). A sensor calibrated for one range only is saved with zeros
    for the other range. RTP must be above zero - W divides by it - and the table enforces that too
    (CK_ConversionParameters_RTP_Positive).

    Why not dbo.CreateConversionParameter
    -------------------------------------
    It has no sensor to save against, and its duplicate check compares against every row in the
    table, so two sensors with the same values could not both be saved. Nothing calls it; it is to
    be dropped once this is on both servers (GIT_ROOT/STATUS.md).

    History
    -------
    Rows are never updated. A save whose values differ from THIS SENSOR's newest set adds a row; the
    older ones stay as history. A save identical to the newest set writes nothing (NoChange). The
    comparison is with the newest set only, so going back to earlier values - A, B, then A again -
    is three rows: returning to A is a real new calibration, not a duplicate.

    Identifying the sensor
    ----------------------
    @MabaID, as the lab does. A MabaID held by more than one live device is refused rather than
    guessed; pass @MeasurementDevicesId alongside it to say which one is meant. @MeasurementDevicesId
    alone also works. If both are given they must name the same device.

    @Apply  0 (default) returns what WOULD be saved and writes nothing. 1 saves.

    One result row: Outcome (WouldSave | Saved | NoChange), the set, and ConversionParameterId -
    the new row's when Saved, the unchanged newest row's when NoChange, NULL when WouldSave.
*/
CREATE OR ALTER PROCEDURE dbo.SaveSensorCoefficients
    @LoggedInUserEmail    NVARCHAR(255),
    @MabaID               NVARCHAR(50)    = NULL,
    @MeasurementDevicesId INT             = NULL,
    @RTP                  DECIMAL(35,15)  = NULL,
    @A4                   DECIMAL(35,15)  = NULL,
    @B4                   DECIMAL(35,15)  = NULL,
    @A7                   DECIMAL(35,15)  = NULL,
    @B7                   DECIMAL(35,15)  = NULL,
    @C7                   DECIMAL(35,15)  = NULL,
    @OrderDetailsItemId   INT             = NULL,   /* the calibration these came from, if any */
    @Apply                BIT             = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @UserId INT = (SELECT ID FROM dbo.Users WHERE Email = @LoggedInUserEmail);
    DECLARE @Maba NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@MabaID)), N'');

    /* ---- which sensor ---- */
    IF @Maba IS NOT NULL
    BEGIN
        DECLARE @Matches INT, @OnlyMatch INT, @IdMatches BIT;
        SELECT @Matches   = COUNT(*),
               @OnlyMatch = MIN(md.ID),
               @IdMatches = MAX(CASE WHEN md.ID = @MeasurementDevicesId THEN 1 ELSE 0 END)
        FROM dbo.MeasurementDevices AS md
        WHERE LTRIM(RTRIM(md.MabaID)) = @Maba AND md.IsDeleted = 0;

        IF @Matches = 0
            THROW 51000, 'No live sensor carries that MabaID.', 1;
        IF @MeasurementDevicesId IS NOT NULL AND @IdMatches = 0
            THROW 51000, 'MabaID and MeasurementDevicesId name different devices.', 1;
        IF @MeasurementDevicesId IS NULL AND @Matches > 1
            THROW 51000, 'That MabaID is held by more than one live device - pass MeasurementDevicesId too.', 1;

        SET @MeasurementDevicesId = COALESCE(@MeasurementDevicesId, @OnlyMatch);
    END;

    SELECT @Maba = LTRIM(RTRIM(md.MabaID))
    FROM dbo.MeasurementDevices AS md
    WHERE md.ID = @MeasurementDevicesId AND md.IsDeleted = 0;

    IF @@ROWCOUNT = 0
        THROW 51000, 'Unknown or deleted sensor - give MabaID or MeasurementDevicesId.', 1;

    /* ---- the coefficients ---- */
    IF @RTP IS NULL OR @A4 IS NULL OR @B4 IS NULL OR @A7 IS NULL OR @B7 IS NULL OR @C7 IS NULL
        THROW 51000, 'All six coefficients are required: RTP, A4, B4, A7, B7, C7. Use 0 for a range the sensor is not used in.', 1;
    IF @RTP <= 0
        THROW 51000, 'RTP must be above zero - ITS-90 divides every reading by it.', 1;

    BEGIN TRANSACTION;

    /* the sensor's newest set; the lock holds it until the insert, so two saves cannot both
       compare against the same row and both write */
    DECLARE @LatestId INT, @Same BIT = 0;
    IF @Apply = 1
        SELECT TOP (1) @LatestId = cp.ConversionParameterId,
               @Same = CASE WHEN cp.RTP = @RTP AND cp.A4 = @A4 AND cp.B4 = @B4
                             AND cp.A7 = @A7 AND cp.B7 = @B7 AND cp.C7 = @C7 THEN 1 ELSE 0 END
        FROM dbo.ConversionParameters AS cp WITH (UPDLOCK, HOLDLOCK)
        WHERE cp.MeasurementDevicesId = @MeasurementDevicesId AND cp.IsDeleted = 0
        ORDER BY cp.ConversionParameterId DESC;
    ELSE
        SELECT TOP (1) @LatestId = cp.ConversionParameterId,
               @Same = CASE WHEN cp.RTP = @RTP AND cp.A4 = @A4 AND cp.B4 = @B4
                             AND cp.A7 = @A7 AND cp.B7 = @B7 AND cp.C7 = @C7 THEN 1 ELSE 0 END
        FROM dbo.ConversionParameters AS cp
        WHERE cp.MeasurementDevicesId = @MeasurementDevicesId AND cp.IsDeleted = 0
        ORDER BY cp.ConversionParameterId DESC;

    DECLARE @Outcome NVARCHAR(10) = CASE WHEN @Same = 1  THEN N'NoChange'
                                         WHEN @Apply = 1 THEN N'Saved'
                                         ELSE N'WouldSave' END;
    DECLARE @SavedId INT = CASE WHEN @Same = 1 THEN @LatestId END;

    IF @Outcome = N'Saved'
    BEGIN
        INSERT dbo.ConversionParameters
              (MeasurementDevicesId, OrderDetailsItemId, RTP, A4, B4, A7, B7, C7,
               CreatedDate, IsDeleted, UpdateUserID)
        VALUES (@MeasurementDevicesId, @OrderDetailsItemId, @RTP, @A4, @B4, @A7, @B7, @C7,
                GETDATE(), 0, @UserId);
        SET @SavedId = SCOPE_IDENTITY();
    END;

    COMMIT TRANSACTION;

    SELECT Outcome               = @Outcome,
           ConversionParameterId = @SavedId,
           MeasurementDevicesId  = @MeasurementDevicesId,
           MabaID                = @Maba,
           RTP = @RTP, A4 = @A4, B4 = @B4, A7 = @A7, B7 = @B7, C7 = @C7,
           OrderDetailsItemId    = @OrderDetailsItemId;
END;
