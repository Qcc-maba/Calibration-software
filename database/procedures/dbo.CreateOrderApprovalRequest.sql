/*
    dbo.CreateOrderApprovalRequest
    ------------------------------
    Issue a one-time approve/reject link for an order and remember who it was mailed to.

    The caller (the app) generated a random token, hashed it with the server-side pepper and
    passes only the digest — the plaintext token lives in the e-mail and nowhere else.

    Any earlier link that is still open for the same order is invalidated first, so a re-send
    always leaves exactly one usable link per order. Links that were already answered are left
    untouched — they are the audit trail of what the customer decided and when.

    Parameters:
      @OrderWorkPlanId INT           (required)
      @TokenHash       VARBINARY(32) (required) HMAC-SHA256 of the token
      @Email           NVARCHAR(100) (required) recipient
      @CustomerContactId INT  = NULL
      @TtlSeconds      INT    = 1209600  (14 days — a customer may answer after a weekend)

    Returns one row:
      Status ∈ { 'Created', 'OrderNotFound', 'OrderCancelled' }, OrderApprovalRequestId,
      OrderNumber, ExpiresAt, SupersededCount
*/
CREATE OR ALTER PROCEDURE dbo.CreateOrderApprovalRequest
    @OrderWorkPlanId   INT,
    @TokenHash         VARBINARY(32),
    @Email             NVARCHAR(100),
    @CustomerContactId INT = NULL,
    @TtlSeconds        INT = 1209600
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @OrderNumber NVARCHAR(20),
            @CustomerId  INT,
            @IsCancelled BIT;

    SELECT @OrderNumber = wp.OrderNumber,
           @CustomerId  = wp.CustomerId,
           @IsCancelled = wp.IsCancelled
    FROM dbo.OrderWorkPlans AS wp
    WHERE wp.OrderWorkPlanId = @OrderWorkPlanId;

    IF @OrderNumber IS NULL
    BEGIN
        SELECT CAST(N'OrderNotFound' AS NVARCHAR(20)) AS Status,
               CAST(NULL AS BIGINT)                   AS OrderApprovalRequestId,
               CAST(NULL AS NVARCHAR(20))             AS OrderNumber,
               CAST(NULL AS DATETIME2(3))             AS ExpiresAt,
               0                                      AS SupersededCount;
        RETURN;
    END

    IF @IsCancelled = 1
    BEGIN
        SELECT CAST(N'OrderCancelled' AS NVARCHAR(20)) AS Status,
               CAST(NULL AS BIGINT)                    AS OrderApprovalRequestId,
               @OrderNumber                            AS OrderNumber,
               CAST(NULL AS DATETIME2(3))              AS ExpiresAt,
               0                                       AS SupersededCount;
        RETURN;
    END

    DECLARE @Now       DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @ExpiresAt DATETIME2(3) = DATEADD(SECOND, @TtlSeconds, @Now);
    DECLARE @Superseded INT = 0;

    BEGIN TRANSACTION;

        UPDATE dbo.OrderApprovalRequest
        SET InvalidatedAt = @Now
        WHERE OrderWorkPlanId = @OrderWorkPlanId
          AND RespondedAt   IS NULL
          AND InvalidatedAt IS NULL;

        SET @Superseded = @@ROWCOUNT;

        INSERT dbo.OrderApprovalRequest
            (OrderWorkPlanId, OrderNumber, TokenHash, CustomerId, CustomerContactId,
             SentToEmail, CreatedAt, ExpiresAt)
        VALUES
            (@OrderWorkPlanId, @OrderNumber, @TokenHash, @CustomerId, @CustomerContactId,
             LOWER(LTRIM(RTRIM(@Email))), @Now, @ExpiresAt);

        DECLARE @Id BIGINT = SCOPE_IDENTITY();

    COMMIT TRANSACTION;

    SELECT CAST(N'Created' AS NVARCHAR(20)) AS Status,
           @Id                              AS OrderApprovalRequestId,
           @OrderNumber                     AS OrderNumber,
           @ExpiresAt                       AS ExpiresAt,
           @Superseded                      AS SupersededCount;
END
GO
