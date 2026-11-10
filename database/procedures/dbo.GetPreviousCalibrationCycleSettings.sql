/*
    dbo.GetPreviousCalibrationCycleSettings                                                MBA-980
    ---------------------------------------------------------------------------------------------
    The chamber cycles of a device's previous calibration, with their settings, so a new cycle can
    start from the values used last time (Nofar, MBA-980: "using last calibration").

    The same device across orders is the same Priority serial key, OrderDetailsItems.SERN (filled on
    99.9% of lines). The previous calibration is the device's other order line - live, not
    cancelled, created before this one - that has live cycles; if there are several, the one whose
    cycles ran last. A line without a SERN, or a device calibrated here for the first time, returns
    no rows.

    It returns all of that calibration's cycles and does not pick one: matching a new cycle to an
    old one is the app's rule (Nofar, MBA-980 29/10: cycle type + set value). With no match, or no
    previous calibration, nothing is carried over and the app's usual starting values apply: the
    middle tolerance = the cycle's TestedValue, the resolution from the set value's decimals (Nofar,
    10/11). Cycles whose settings were never saved are returned too, with NULLs.

    Rows, oldest cycle first: PreviousOrderDetailsItemId, PreviousMbaReportNumber, CycleNumber,
    CalibrationCycleStartDate, CalibrationCycleName, CalibrationCycleNameStatusId, UnitId, UnitName,
    TestedValue, ToleranceValue, ToleranceStart, ToleranceEnd, Resolution, Uncertainty,
    StabilityThreshold, UniformityThreshold.

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

    DECLARE @Sern INT, @CreatedDate DATETIME2(0);

    SELECT TOP (1) @Sern = SERN, @CreatedDate = CreatedDate
    FROM dbo.OrderDetailsItems
    WHERE OrderDetailsItemId = @OrderDetailsItemId AND IsDeleted = 0;

    DECLARE @PreviousItemId INT;

    IF @Sern IS NOT NULL
        SELECT TOP (1) @PreviousItemId = oi.OrderDetailsItemId
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
        ORDER BY c.LastStart DESC, oi.OrderDetailsItemId DESC;

    SELECT
         PreviousOrderDetailsItemId = cc.OrderDetailsItemId
        ,PreviousMbaReportNumber    = oi.MbaReportNumber
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
    FROM dbo.CalibrationCycles AS cc
    /* TOP (1): OrderDetailsItemId is an identity but not unique on its own - STAGE has id 112 on two
       order lines - so a plain join could return a cycle twice */
    OUTER APPLY (SELECT TOP (1) i.MbaReportNumber
                 FROM dbo.OrderDetailsItems AS i
                 WHERE i.OrderDetailsItemId = cc.OrderDetailsItemId AND i.IsDeleted = 0
                 ORDER BY i.OrderDetailId) AS oi
    LEFT JOIN dbo.MeasurementDeviceUnits AS mu ON mu.MeasurementDeviceUnitId = cc.UnitId
    WHERE cc.OrderDetailsItemId = @PreviousItemId
      AND cc.IsDeleted = 0
    ORDER BY cc.CalibrationCycleStartDate;
END;
GO
