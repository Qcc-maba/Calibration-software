/*
    dbo.GetPreviousCalibrationCycleSettings                                                MBA-980
    ---------------------------------------------------------------------------------------------
    The chamber cycles of a device's previous calibration, with their settings, so a new cycle can
    start from the values used last time (Nofar, MBA-980: "using last calibration").

    The same device across orders is the same Priority serial key, OrderDetailsItems.SERN (2026-11-11:
    filled on 99.89% of PROD's 10,307 lines and 95.10% of STAGE's 6,186; every line without one was
    added manually, and those get no carry-over). The previous calibration is the device's other
    order line - live, not cancelled, created before this one - that has live cycles; if there are
    several, the one whose cycles ran last. A line without a SERN, or a device calibrated here for
    the first time, returns no rows.

    OrderDetailsItemId is an identity but not unique on its own (STAGE has id 112 on two order lines,
    PROD none on 2026-11-11), and cycles are keyed by it alone. An id on two live lines cannot say
    which device it means, so it is never used: as the line asked about it returns no rows, as a
    candidate it is skipped. Starting from the usual values is better than another instrument's.

    It returns all of that calibration's cycles and does not pick one: matching a new cycle to an
    old one is the app's rule (Nofar, MBA-980 29/10: cycle type + set value). With no match, or no
    previous calibration, nothing is carried over and the app's usual starting values apply: the
    middle tolerance = the cycle's TestedValue, the resolution from the set value's decimals (Nofar,
    10/11). Cycles whose settings were never saved are returned too, with NULLs. When several
    previous cycles match, the app takes the last one (Nofar 11/11) - the rows come oldest first.

    Nofar 15/11: the Display reading, its resolution and checkbox, the Target Value checkbox, the
    Controller (type, manufacturer, model) and the Calculation Resolution carry over the same way.

    Rows, oldest cycle first: PreviousOrderDetailsItemId, PreviousMbaReportNumber, CycleNumber,
    CalibrationCycleStartDate, CalibrationCycleName, CalibrationCycleNameStatusId, UnitId, UnitName,
    TestedValue, ToleranceValue, ToleranceStart, ToleranceEnd, Resolution, Uncertainty,
    StabilityThreshold, UniformityThreshold, DisplayValue, DisplayResolution, IsDisplayEnabled,
    IsTargetValueEnabled, ControllerTypeStatusId, ControllerManufacturer, ControllerModel,
    CalculationResolution, and (MBA-800) SecondaryUnitId, SecondaryUnitName and the thirteen other
    Secondary* columns: the cycle's second measured value, NULL where it has none. Matching a new
    cycle's RH set point to an old one is the app's rule, as for the temperature set point.

    STAGE copy 2026-11-10: 19 devices with live cycles, none of them with cycles on two lines yet,
    so on real data this returns nothing until a device comes back for its next calibration.
*/
CREATE OR ALTER PROCEDURE dbo.GetPreviousCalibrationCycleSettings
    @OrderDetailsItemId INT
/*
EXEC dbo.GetPreviousCalibrationCycleSettings @OrderDetailsItemId = 3077
*/
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LiveLines INT, @Sern INT, @CreatedDate DATETIME2(0);

    SELECT @LiveLines = COUNT(*), @Sern = MAX(SERN), @CreatedDate = MAX(CreatedDate)
    FROM dbo.OrderDetailsItems
    WHERE OrderDetailsItemId = @OrderDetailsItemId AND IsDeleted = 0;

    DECLARE @PreviousItemId INT, @PreviousReportNumber NVARCHAR(100);

    IF @LiveLines = 1 AND @Sern IS NOT NULL
        SELECT TOP (1) @PreviousItemId = oi.OrderDetailsItemId,
                       @PreviousReportNumber = oi.MbaReportNumber
        FROM dbo.OrderDetailsItems AS oi
        CROSS APPLY (SELECT LastStart = MAX(cc.CalibrationCycleStartDate)
                     FROM dbo.CalibrationCycles AS cc
                     WHERE cc.OrderDetailsItemId = oi.OrderDetailsItemId AND cc.IsDeleted = 0) AS c
        WHERE oi.SERN = @Sern
          AND oi.OrderDetailsItemId <> @OrderDetailsItemId
          AND oi.IsDeleted = 0
          AND oi.IsCancelled = 0
          AND (oi.CreatedDate < @CreatedDate
               OR (oi.CreatedDate = @CreatedDate AND oi.OrderDetailsItemId < @OrderDetailsItemId))
          AND c.LastStart IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM dbo.OrderDetailsItems AS d
                          WHERE d.OrderDetailsItemId = oi.OrderDetailsItemId
                            AND d.OrderDetailId <> oi.OrderDetailId
                            AND d.IsDeleted = 0)
        ORDER BY c.LastStart DESC, oi.OrderDetailsItemId DESC;

    SELECT
         PreviousOrderDetailsItemId = cc.OrderDetailsItemId
        ,PreviousMbaReportNumber    = @PreviousReportNumber
        ,CycleNumber                = ROW_NUMBER() OVER (ORDER BY cc.CalibrationCycleStartDate)
        ,cc.CalibrationCycleStartDate
        ,cc.CalibrationCycleName
        ,cc.CalibrationCycleNameStatusId
        ,cc.UnitId
        ,UnitName                   = mu.LongNameHe
        ,cc.TestedValue
        ,cc.ToleranceValue
        ,cc.ToleranceStart
        ,cc.ToleranceEnd
        ,cc.Resolution
        ,cc.Uncertainty
        ,cc.StabilityThreshold
        ,cc.UniformityThreshold
        ,cc.DisplayValue
        ,cc.DisplayResolution
        ,cc.IsDisplayEnabled
        ,cc.IsTargetValueEnabled
        ,cc.ControllerTypeStatusId
        ,cc.ControllerManufacturer
        ,cc.ControllerModel
        ,cc.CalculationResolution
        -- MBA-800: the second measured value carries over the same way
        ,cc.SecondaryUnitId
        ,SecondaryUnitName          = smu.ShortNameEn
        ,cc.SecondaryTestedValue
        ,cc.SecondaryToleranceValue
        ,cc.SecondaryToleranceStart
        ,cc.SecondaryToleranceEnd
        ,cc.SecondaryResolution
        ,cc.SecondaryUncertainty
        ,cc.SecondaryStabilityThreshold
        ,cc.SecondaryUniformityThreshold
        ,cc.SecondaryDisplayValue
        ,cc.SecondaryDisplayResolution
        ,cc.SecondaryIsDisplayEnabled
        ,cc.SecondaryIsTargetValueEnabled
        ,cc.SecondaryCalculationResolution
    FROM dbo.CalibrationCycles AS cc
    LEFT JOIN dbo.MeasurementDeviceUnits AS mu ON mu.MeasurementDeviceUnitId = cc.UnitId
    LEFT JOIN dbo.MeasurementDeviceUnits AS smu ON smu.MeasurementDeviceUnitId = cc.SecondaryUnitId -- MBA-800
    WHERE cc.OrderDetailsItemId = @PreviousItemId
      AND cc.IsDeleted = 0
    ORDER BY cc.CalibrationCycleStartDate;
END;
GO
