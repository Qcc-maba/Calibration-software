/*
    dbo.ResolveOrderApprovalRequest
    -------------------------------
    Consume an approve/reject link: record the customer's answer and move the order to
    ClientConfirmationStatus 'Confirmed' (מאושר) or 'Rejected' (נדחה).

    This is the only place the two writes happen together, and they happen in one transaction —
    an answer that is stored without moving the order (or the other way round) would leave the
    coordinator screen lying about what the customer said.

    The link is consumed atomically: the UPDATE that stamps RespondedAt also filters on
    RespondedAt IS NULL, so two concurrent clicks (a double-click, or the customer forwarding the
    mail) produce exactly one decision — the second one comes back 'AlreadyAnswered'.

    Rejection notes are ALSO written to OrderWorkPlans.CustomerComment, because that is the column
    the coordinator screen already renders (see dbo.AssignOrderComment / the CustomerComment column
    in dbo.GetWorkPlanData) — otherwise the coordinator would have to open a second screen to learn
    why the customer said no.

    Parameters:
      @TokenHash VARBINARY(32)  (required)
      @Decision  NVARCHAR(10)   (required) 'Confirmed' | 'Rejected'
      @Notes     NVARCHAR(1000) = NULL   הערות הלקוח
      @Ip        NVARCHAR(45)   = NULL

    Returns one row:
      Status ∈ { 'Resolved', 'AlreadyAnswered', 'Expired', 'Invalidated', 'NotFound',
                 'BadDecision', 'StatusMissing' }
      OrderApprovalRequestId, OrderWorkPlanId, OrderNumber, Decision, ResponseNotes
*/
CREATE OR ALTER PROCEDURE dbo.ResolveOrderApprovalRequest
    @TokenHash VARBINARY(32),
    @Decision  NVARCHAR(10),
    @Notes     NVARCHAR(1000) = NULL,
    @Ip        NVARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status                 NVARCHAR(20),
            @OrderApprovalRequestId BIGINT,
            @OrderWorkPlanId        INT,
            @OrderNumber            NVARCHAR(20);

    IF @Decision NOT IN (N'Confirmed', N'Rejected')
    BEGIN
        SELECT CAST(N'BadDecision' AS NVARCHAR(20)) AS Status,
               CAST(NULL AS BIGINT)                 AS OrderApprovalRequestId,
               CAST(NULL AS INT)                    AS OrderWorkPlanId,
               CAST(NULL AS NVARCHAR(20))           AS OrderNumber,
               CAST(NULL AS NVARCHAR(10))           AS Decision,
               CAST(NULL AS NVARCHAR(1000))         AS ResponseNotes;
        RETURN;
    END

    /* The status id is looked up, never hard-coded — Statuses.StatusId is IDENTITY and differs
       between STG and PROD. */
    DECLARE @StatusId INT =
    (
        SELECT s.StatusId
        FROM dbo.Statuses AS s
        JOIN dbo.StatusesCategories AS c ON c.StatusCategoryId = s.StatusCategoryId
        WHERE c.StatusDescriptionENG = N'ClientConfirmationStatus'
          AND s.StatusDescriptionENG = @Decision
    );

    IF @StatusId IS NULL
    BEGIN
        SELECT CAST(N'StatusMissing' AS NVARCHAR(20)) AS Status,
               CAST(NULL AS BIGINT)                   AS OrderApprovalRequestId,
               CAST(NULL AS INT)                      AS OrderWorkPlanId,
               CAST(NULL AS NVARCHAR(20))             AS OrderNumber,
               CAST(NULL AS NVARCHAR(10))             AS Decision,
               CAST(NULL AS NVARCHAR(1000))           AS ResponseNotes;
        RETURN;
    END

    DECLARE @Now         DATETIME2(3)   = SYSUTCDATETIME();
    DECLARE @CleanNotes  NVARCHAR(1000) = NULLIF(LTRIM(RTRIM(@Notes)), N'');
    DECLARE @Answered    TABLE (OrderApprovalRequestId BIGINT,
                                OrderWorkPlanId        INT,
                                OrderNumber            NVARCHAR(20));

    BEGIN TRANSACTION;

        /* Consume the link. The RespondedAt IS NULL predicate is the concurrency guard. */
        UPDATE r
        SET r.RespondedAt   = @Now,
            r.Decision      = @Decision,
            r.ResponseNotes = @CleanNotes,
            r.ResponseIp    = @Ip
        OUTPUT inserted.OrderApprovalRequestId, inserted.OrderWorkPlanId, inserted.OrderNumber
        INTO @Answered
        FROM dbo.OrderApprovalRequest AS r
        WHERE r.TokenHash     = @TokenHash
          AND r.RespondedAt   IS NULL
          AND r.InvalidatedAt IS NULL
          AND r.ExpiresAt     > @Now;

        SELECT @OrderApprovalRequestId = a.OrderApprovalRequestId,
               @OrderWorkPlanId        = a.OrderWorkPlanId,
               @OrderNumber            = a.OrderNumber
        FROM @Answered AS a;

        IF @OrderApprovalRequestId IS NOT NULL
        BEGIN
            UPDATE dbo.OrderWorkPlans
            SET ClientConfirmationStatusId = @StatusId,
                UpdatedDate                = SYSDATETIME()
            WHERE OrderWorkPlanId = @OrderWorkPlanId;

            /* Surface the reason for a rejection where the coordinator already looks. */
            IF @Decision = N'Rejected' AND @CleanNotes IS NOT NULL
                UPDATE dbo.OrderWorkPlans
                SET CustomerComment = @CleanNotes
                WHERE OrderWorkPlanId = @OrderWorkPlanId;

            SET @Status = N'Resolved';
        END

    COMMIT TRANSACTION;

    /* Nothing was consumed — say precisely why, so the page can explain it to the customer. */
    IF @Status IS NULL
    BEGIN
        SELECT TOP (1)
            @Status                 = CASE
                                          WHEN r.RespondedAt   IS NOT NULL THEN N'AlreadyAnswered'
                                          WHEN r.InvalidatedAt IS NOT NULL THEN N'Invalidated'
                                          ELSE N'Expired'
                                      END,
            @OrderApprovalRequestId = r.OrderApprovalRequestId,
            @OrderWorkPlanId        = r.OrderWorkPlanId,
            @OrderNumber            = r.OrderNumber
        FROM dbo.OrderApprovalRequest AS r
        WHERE r.TokenHash = @TokenHash;

        IF @Status IS NULL
            SET @Status = N'NotFound';
    END

    /* Scalar sub-queries, not a join — this must return exactly one row even for 'NotFound'. */
    SELECT @Status                 AS Status,
           @OrderApprovalRequestId AS OrderApprovalRequestId,
           @OrderWorkPlanId        AS OrderWorkPlanId,
           @OrderNumber            AS OrderNumber,
           (SELECT TOP (1) r.Decision
            FROM dbo.OrderApprovalRequest AS r
            WHERE r.TokenHash = @TokenHash)      AS Decision,
           (SELECT TOP (1) r.ResponseNotes
            FROM dbo.OrderApprovalRequest AS r
            WHERE r.TokenHash = @TokenHash)      AS ResponseNotes;
END
GO
