/*
    dbo.GetPreviousCalibrationRemarks                                                      MBA-831
    ---------------------------------------------------------------------------------------------
    The report remarks of the same sensor's last calibration, so a customer's precision sensor gets
    them back when it returns: its general remarks, the coefficients it arrived and was adjusted
    with, its hysteresis (Nofar, Jira 38336). The calibrator reviews them and saves them on the new
    report through dbo.SaveCalibrationRemarks; nothing is copied here.

    "The same sensor" is the order line's serial number (Nofar, Jira 38338: the serial number is
    enough). The serial usually carries the customer's code as its prefix ("10251-MY63001114"), but a
    serial typed without it would match another customer's sensor, so the line must also belong to the
    same customer (OrderWorkPlans.CustomerId; review of #63). STAGE 2026-11-19: 5,971 of 6,187 lines
    have a serial; 10 serial texts sit on more than one Priority SERN, which look like one device
    registered twice.

    The source is the other live, uncancelled line of that customer with that serial that has report
    remarks and was calibrated last (ActualCalibrationDate, else when its remarks were saved). Not the
    remarks saved last: a typo fixed on an older, unsigned report re-saves its remarks and would make
    that older calibration "the last" (review of #63). Report remarks only: cycle remarks belong to a
    chamber cycle of that one calibration. No serial, no customer, or no earlier line with remarks
    returns no rows - an answer, not an error.

    Nothing is offered to a line that has ever had report remarks saved, even if they were all removed
    since: dbo.SaveCalibrationRemarks soft-deletes the set it replaces, so a deleted row is the trace of
    a calibrator who cleared the remarks on purpose (review of app #198). A line where the offered
    remarks were removed before anything was ever saved leaves no trace, and is offered them again.

    Same columns as dbo.GetCalibrationRemarks, plus where they came from:
    SourceOrderDetailsItemId, SourceReportNumber (MbaReportNumber), SourceCalibrationDate
    (ActualCalibrationDate, else the day the remarks were saved). PredefinedIsActive says whether the
    list row can still be saved by id; a retired one has to be saved as typed text.

    OrderDetailsItemId is not unique on its own (STAGE: 112 sits on two order lines), as for the
    other remarks procedures; the serial is read from every live line carrying the id, and two
    different serials there return nothing rather than a guess.
*/
CREATE OR ALTER PROCEDURE dbo.GetPreviousCalibrationRemarks
    @OrderDetailsItemId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Serial NVARCHAR(200);
    IF (SELECT COUNT(DISTINCT LTRIM(RTRIM(SerialNumber)))
        FROM dbo.OrderDetailsItems
        WHERE OrderDetailsItemId = @OrderDetailsItemId AND IsDeleted = 0
          AND NULLIF(LTRIM(RTRIM(SerialNumber)), N'') IS NOT NULL) = 1
        SELECT TOP (1) @Serial = LTRIM(RTRIM(SerialNumber))
        FROM dbo.OrderDetailsItems
        WHERE OrderDetailsItemId = @OrderDetailsItemId AND IsDeleted = 0
          AND NULLIF(LTRIM(RTRIM(SerialNumber)), N'') IS NOT NULL;

    IF @Serial IS NULL RETURN;

    IF EXISTS (SELECT 1 FROM dbo.CalibrationRemarks
               WHERE OrderDetailsItemId = @OrderDetailsItemId AND Scope = N'Report')
        RETURN;

    DECLARE @Customer INT;
    IF (SELECT COUNT(DISTINCT wp.CustomerId)
        FROM dbo.OrderDetailsItems AS i
        JOIN dbo.OrderDetails AS od ON od.OrderDetailId = i.OrderDetailId
        JOIN dbo.OrderWorkPlans AS wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
        WHERE i.OrderDetailsItemId = @OrderDetailsItemId AND i.IsDeleted = 0) = 1
        SELECT TOP (1) @Customer = wp.CustomerId
        FROM dbo.OrderDetailsItems AS i
        JOIN dbo.OrderDetails AS od ON od.OrderDetailId = i.OrderDetailId
        JOIN dbo.OrderWorkPlans AS wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
        WHERE i.OrderDetailsItemId = @OrderDetailsItemId AND i.IsDeleted = 0;

    IF @Customer IS NULL RETURN;

    DECLARE @Source INT, @SourceReport NVARCHAR(200), @SourceDate DATETIME2(0);

    SELECT TOP (1) @Source = i.OrderDetailsItemId,
                   @SourceReport = i.MbaReportNumber,
                   @SourceDate = COALESCE(i.ActualCalibrationDate, x.LastSaved)
    FROM dbo.OrderDetailsItems AS i
    JOIN dbo.OrderDetails AS od ON od.OrderDetailId = i.OrderDetailId
    JOIN dbo.OrderWorkPlans AS wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
    CROSS APPLY (SELECT LastSaved = MAX(r.CreatedDate)
                 FROM dbo.CalibrationRemarks AS r
                 WHERE r.OrderDetailsItemId = i.OrderDetailsItemId
                   AND r.Scope = N'Report' AND r.IsDeleted = 0) AS x
    WHERE LTRIM(RTRIM(i.SerialNumber)) = @Serial
      AND wp.CustomerId = @Customer
      AND i.OrderDetailsItemId <> @OrderDetailsItemId
      AND i.IsDeleted = 0
      AND ISNULL(i.IsCancelled, 0) = 0
      AND x.LastSaved IS NOT NULL
    ORDER BY COALESCE(i.ActualCalibrationDate, x.LastSaved) DESC, x.LastSaved DESC, i.OrderDetailsItemId DESC;

    IF @Source IS NULL RETURN;

    SELECT r.CalibrationRemarkId,
           r.OrderDetailsItemId,
           r.Scope,
           r.CalibrationCycleStartDate,
           r.DisplayOrder,
           r.PredefinedRemarkId,
           r.ValuesJson,
           r.IsCustomized,
           IsManual    = CAST(CASE WHEN r.PredefinedRemarkId IS NULL THEN 1 ELSE 0 END AS BIT),
           r.TextHEB,
           r.TextENG,
           TemplateHEB = p.TextHEB,
           TemplateENG = p.TextENG,
           IsLocked    = CAST(0 AS BIT),
           r.UpdatedDate,
           r.CreatedDate,
           PredefinedIsActive       = CAST(CASE WHEN p.IsActive = 1 THEN 1 ELSE 0 END AS BIT),
           SourceOrderDetailsItemId = @Source,
           SourceReportNumber       = @SourceReport,
           SourceCalibrationDate    = @SourceDate
    FROM dbo.CalibrationRemarks AS r
    LEFT JOIN dbo.PredefinedRemarks AS p ON p.PredefinedRemarkId = r.PredefinedRemarkId
    WHERE r.OrderDetailsItemId = @Source
      AND r.Scope = N'Report'
      AND r.IsDeleted = 0
    ORDER BY r.DisplayOrder;
END;
GO
