/*
    dbo.GetOrderApprovalRequestByToken
    ----------------------------------
    Resolve an approve/reject link to its order, without consuming it. Backs the GET of the
    public approval page: the visitor sees the coordination details and the two buttons only
    when Status = 'Valid'; every other status renders an explanatory message instead.

    Parameters:
      @TokenHash VARBINARY(32) (required) HMAC-SHA256 of the token from the URL

    Returns exactly 0 or 1 rows (0 only when @TokenHash is NULL):
      Status ∈ { 'Valid', 'Expired', 'Answered', 'Invalidated', 'NotFound' }
      OrderApprovalRequestId, OrderWorkPlanId, OrderNumber, CustomerId, SentToEmail,
      CreatedAt, ExpiresAt, RespondedAt, Decision, ResponseNotes,
      PriorityDocumentNumber, PriorityError

    'Answered' carries Decision + ResponseNotes so a customer who clicks the link twice sees
    what they already replied instead of an error. 'Invalidated' means a newer link was issued
    for the same order.

    Read-only.
*/
CREATE OR ALTER PROCEDURE dbo.GetOrderApprovalRequestByToken
    @TokenHash VARBINARY(32)
AS
BEGIN
    SET NOCOUNT ON;

    IF @TokenHash IS NULL
        RETURN;

    IF NOT EXISTS (SELECT 1 FROM dbo.OrderApprovalRequest WHERE TokenHash = @TokenHash)
    BEGIN
        SELECT CAST(N'NotFound' AS NVARCHAR(20))  AS Status,
               CAST(NULL AS BIGINT)               AS OrderApprovalRequestId,
               CAST(NULL AS INT)                  AS OrderWorkPlanId,
               CAST(NULL AS NVARCHAR(20))         AS OrderNumber,
               CAST(NULL AS INT)                  AS CustomerId,
               CAST(NULL AS NVARCHAR(100))        AS SentToEmail,
               CAST(NULL AS DATETIME2(3))         AS CreatedAt,
               CAST(NULL AS DATETIME2(3))         AS ExpiresAt,
               CAST(NULL AS DATETIME2(3))         AS RespondedAt,
               CAST(NULL AS NVARCHAR(10))         AS Decision,
               CAST(NULL AS NVARCHAR(1000))       AS ResponseNotes,
               CAST(NULL AS NVARCHAR(50))         AS PriorityDocumentNumber,
               CAST(NULL AS NVARCHAR(1000))       AS PriorityError;
        RETURN;
    END

    SELECT
        CAST(CASE
                WHEN r.RespondedAt   IS NOT NULL THEN N'Answered'
                WHEN r.InvalidatedAt IS NOT NULL THEN N'Invalidated'
                WHEN r.ExpiresAt <= SYSUTCDATETIME() THEN N'Expired'
                ELSE N'Valid'
             END AS NVARCHAR(20))       AS Status,
        r.OrderApprovalRequestId,
        r.OrderWorkPlanId,
        r.OrderNumber,
        r.CustomerId,
        r.SentToEmail,
        r.CreatedAt,
        r.ExpiresAt,
        r.RespondedAt,
        r.Decision,
        r.ResponseNotes,
        r.PriorityDocumentNumber,
        r.PriorityError
    FROM dbo.OrderApprovalRequest AS r
    WHERE r.TokenHash = @TokenHash;
END
GO
