/*
    dbo.vwOrderDetailsItemsPriorityStatus                                              MBA-911
    ---------------------------------------------------------------------------------------------
    For each device row (OrderDetailsItems), the calibration's CURRENT status in Priority and
    the dates of its main steps, read from dbo.PriorityCalibrationStatusLog (filled hourly by
    dbo.RefreshPriorityCalibrationStatus). This is what the screens join to.

    Kept SEPARATE from OrderDetailsItems.CalibrationStatusId / CalibrationReportStatusId on
    purpose: those are the Calibrator app's own workflow statuses (InCalibration,
    AwaitingSignature, ...), set by dbo.AssignOrderItemsStatus. Priority's status is a second,
    independent fact. Until the app rolls out it is the only real progress there is; afterwards
    it is what Priority recorded, which is worth seeing next to what the app thinks.

    Joined through Doc, so the several rows that share one calibration (134 Docs on 500 rows in
    the PROD copy of 2026-10-21) all show the same status.

    "Current" = the step with the highest Kline, which is Priority's own step order. Not the
    latest StatusDate: a CD row is dated at midnight of the calibration day.

    The milestone dates take the LATEST occurrence of each code, because steps repeat: a report
    is generated again after a rejection, and the signatures follow again.

    There is deliberately no "received at" milestone. AA (received) is always step 1, but its
    date is NOT the intake date: in 2,869 of 5,609 calibrations (STAGE copy, 2026-11-09) it is
    LATER than the calibration was opened, so Priority evidently re-stamps it. The lab-receiving
    date already comes from the goods-receipt document (dbo.RefreshPackingDataFromPriority).
    The current status still shows AA correctly when it is the latest step.

    Rows with no Doc yet, or whose Doc has no log rows yet, return NULLs (LEFT/OUTER joins).
*/
CREATE OR ALTER VIEW dbo.vwOrderDetailsItemsPriorityStatus
AS
SELECT
    i.OrderDetailsItemId,
    i.OrderDetailId,
    i.Doc,
    i.MbaReportNumber,
    cur.Kline                AS PriorityStatusKline,
    cur.StatusCode           AS PriorityStatusCode,
    c.DescriptionENG         AS PriorityStatusENG,
    c.DescriptionHEB         AS PriorityStatusHEB,
    c.Stage                  AS PriorityStage,
    c.WrittenBy              AS PriorityStatusWrittenBy,
    cur.StatusDate           AS PriorityStatusDate,
    cur.StatusByUserName     AS PriorityStatusByUserName,
    m.CalibrationOpenedAt,
    m.ReportGeneratedAt,
    m.FirstSignatureAt,
    m.SecondSignatureAt,
    m.RejectedAt,
    m.PackedAt,
    m.SentAt
FROM dbo.OrderDetailsItems AS i
OUTER APPLY (
    SELECT TOP (1) g.Kline, g.StatusCode, g.StatusDate, g.StatusByUserName
    FROM dbo.PriorityCalibrationStatusLog AS g
    WHERE g.Doc = i.Doc
    ORDER BY g.Kline DESC
) AS cur
OUTER APPLY (
    SELECT
        CalibrationOpenedAt = MAX(CASE WHEN g.StatusCode = 'AC' THEN g.StatusDate END),
        ReportGeneratedAt   = MAX(CASE WHEN g.StatusCode = 'GR' THEN g.StatusDate END),
        FirstSignatureAt    = MAX(CASE WHEN g.StatusCode = 'H1' THEN g.StatusDate END),
        SecondSignatureAt   = MAX(CASE WHEN g.StatusCode = 'H2' THEN g.StatusDate END),
        RejectedAt          = MAX(CASE WHEN g.StatusCode = 'HR' THEN g.StatusDate END),
        PackedAt            = MAX(CASE WHEN g.StatusCode = 'PI' THEN g.StatusDate END),
        SentAt              = MAX(CASE WHEN g.StatusCode = 'TX' THEN g.StatusDate END)
    FROM dbo.PriorityCalibrationStatusLog AS g
    WHERE g.Doc = i.Doc
) AS m
LEFT JOIN dbo.PriorityCalibrationStatusCodes AS c ON c.StatusCode = cur.StatusCode
WHERE i.IsDeleted = 0;
GO
