/*
    dbo.SetOrderApprovalPriorityResult
    ----------------------------------
    Record what happened when the Priority external-calibration API ("פתיחת כיולי חוץ") was called
    after a customer approved an order.

    The Priority call is deliberately NOT part of dbo.ResolveOrderApprovalRequest: the customer's
    answer must be durable even when Priority is unreachable. The app calls Priority after the
    answer is committed and stamps the outcome here, so a failed call is visible and can be retried
    without asking the customer again.

    Parameters:
      @OrderApprovalRequestId BIGINT         (required)
      @DocumentNumber         NVARCHAR(50)   = NULL  Priority DOCNO on success
      @Error                  NVARCHAR(1000) = NULL  error text on failure

    Returns one row: Status ∈ { 'Updated', 'NotFound' }.
*/
CREATE OR ALTER PROCEDURE dbo.SetOrderApprovalPriorityResult
    @OrderApprovalRequestId BIGINT,
    @DocumentNumber         NVARCHAR(50)   = NULL,
    @Error                  NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.OrderApprovalRequest
    SET PriorityDocumentNumber = @DocumentNumber,
        PriorityError          = @Error,
        PriorityCompletedAt    = SYSUTCDATETIME()
    WHERE OrderApprovalRequestId = @OrderApprovalRequestId;

    SELECT CAST(CASE WHEN @@ROWCOUNT = 1 THEN N'Updated' ELSE N'NotFound' END AS NVARCHAR(20)) AS Status;
END
GO
