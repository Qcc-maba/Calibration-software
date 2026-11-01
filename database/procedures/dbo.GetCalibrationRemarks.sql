/*
    dbo.GetCalibrationRemarks                                                              MBA-848
    ---------------------------------------------------------------------------------------------
    Every live remark on one report, report remarks first, then each cycle's in start-time order,
    each group in DisplayOrder. One result set; the screen and the PDF group it by
    (Scope, CalibrationCycleStartDate).

    The PDF prints TextENG for an English report and TextHEB otherwise; TextENG is NULL only for a
    customized remark whose calibrator gave no English, and then TextHEB is the fallback.
    A cycle remark whose cycle was deleted is not returned.

    For re-opening a remark in the dialog: PredefinedRemarkId + ValuesJson select it again;
    TemplateHEB / TemplateENG are the list row's texts with their placeholders.
    IsLocked is 1 once the report was signed (dbo.SetCalibrationRemarksLock). A report with no
    remarks returns no rows - read the lock from dbo.GetCalibrationRemarksLock.
*/
CREATE OR ALTER PROCEDURE dbo.GetCalibrationRemarks
    @OrderDetailsItemId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsLocked BIT =
        CASE WHEN EXISTS (SELECT 1 FROM dbo.OrderDetailsItems
                          WHERE OrderDetailsItemId = @OrderDetailsItemId
                            AND RemarksLockedDate IS NOT NULL)
             THEN 1 ELSE 0 END;

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
           IsLocked    = @IsLocked,
           r.UpdatedDate,
           r.CreatedDate
    FROM dbo.CalibrationRemarks AS r
    LEFT JOIN dbo.PredefinedRemarks AS p ON p.PredefinedRemarkId = r.PredefinedRemarkId
    LEFT JOIN dbo.CalibrationCycles AS c
           ON c.OrderDetailsItemId = r.OrderDetailsItemId
          AND c.CalibrationCycleStartDate = r.CalibrationCycleStartDate
    WHERE r.OrderDetailsItemId = @OrderDetailsItemId
      AND r.IsDeleted = 0
      AND (r.Scope = N'Report' OR c.IsDeleted = 0)
    ORDER BY CASE WHEN r.Scope = N'Report' THEN 0 ELSE 1 END,
             r.CalibrationCycleStartDate,
             r.DisplayOrder;
END;
GO
