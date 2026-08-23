/*
    dbo.GetCalibrationReportSendStatus                                                 MBA-337
    ---------------------------------------------------------------------------------------------
    Has this report been sent, and to whom?

    Two result sets:
      1. A single summary row, so a screen can show "נשלח ב-..." or "טרם נשלח" without counting rows itself.
      2. The full history, newest first, for the detail view.

    A report that has never been sent still returns one summary row, with Status 'NotSent' and nulls
    — an empty result set would force every caller to handle "no rows" as a third case.

    LastSuccessfulSentAt is deliberately separate from LastAttemptAt: a report can have gone out
    fine on Monday and failed a re-send on Tuesday, and "when did the customer actually get it" is
    the question that matters.
*/
CREATE OR ALTER PROCEDURE dbo.GetCalibrationReportSendStatus
    @OrderDetailsItemId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        @OrderDetailsItemId AS OrderDetailsItemId,
        CASE
            WHEN SUM(CASE WHEN l.Status = N'Sent' THEN 1 ELSE 0 END) > 0 THEN N'Sent'
            WHEN COUNT(l.CalibrationReportSendLogId) > 0                 THEN N'Failed'
            ELSE N'NotSent'
        END AS Status,
        COUNT(l.CalibrationReportSendLogId)                                   AS Attempts,
        SUM(CASE WHEN l.Status = N'Sent'   THEN 1 ELSE 0 END)                 AS Delivered,
        SUM(CASE WHEN l.Status = N'Failed' THEN 1 ELSE 0 END)                 AS Failures,
        MAX(CASE WHEN l.Status = N'Sent' THEN l.SentAt END)                   AS LastSuccessfulSentAt,
        MAX(l.SentAt)                                                         AS LastAttemptAt
    FROM dbo.CalibrationReportSendLog AS l
    WHERE l.OrderDetailsItemId = @OrderDetailsItemId;

    SELECT
        l.CalibrationReportSendLogId,
        l.SentToEmail,
        l.Status,
        l.IsDraft,
        l.MbaReportNumber,
        l.DocumentPath,
        l.FailureReason,
        l.SentAt,
        l.SentByEmail,
        u.FirstName + N' ' + u.LastName AS SentByName
    FROM dbo.CalibrationReportSendLog AS l
    LEFT JOIN dbo.Users AS u ON u.ID = l.SentByUserId
    WHERE l.OrderDetailsItemId = @OrderDetailsItemId
    ORDER BY l.SentAt DESC;
END
GO
