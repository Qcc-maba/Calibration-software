/*
    dbo.OrderApprovalRequest  --  one-time approve/reject links mailed to the customer.

    Flow (MBA — "אישור תיאום כיול ע"י הלקוח"):
      1. An order moves to ClientConfirmationStatus = 'Pending'.
      2. The app creates a row here and mails the contact a link carrying the plaintext token.
      3. The customer clicks אשר / דחה; dbo.ResolveOrderApprovalRequest consumes the row,
         writes the decision + notes, and flips OrderWorkPlans.ClientConfirmationStatusId.
      4. On 'Confirmed' the app calls the Priority external-calibration API and stamps the
         resulting document number back here via dbo.SetOrderApprovalPriorityResult.

    The plaintext token NEVER reaches the database: the application stores an HMAC-SHA256
    digest computed with a server-side pepper, exactly like dbo.CustomerPortalOtp. A DB reader
    therefore cannot forge a live approval link.

    All timestamps are UTC (SYSUTCDATETIME) so the TTL is timezone independent.
*/
IF OBJECT_ID('dbo.OrderApprovalRequest', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.OrderApprovalRequest
    (
        OrderApprovalRequestId BIGINT         IDENTITY(1, 1) NOT NULL,
        OrderWorkPlanId        INT            NOT NULL,
        OrderNumber            NVARCHAR(20)   NOT NULL,
        TokenHash              VARBINARY(32)  NOT NULL,
        CustomerId             INT            NULL,
        CustomerContactId      INT            NULL,
        SentToEmail            NVARCHAR(100)  NOT NULL,
        CreatedAt              DATETIME2(3)   NOT NULL CONSTRAINT DF_OrderApprovalRequest_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ExpiresAt              DATETIME2(3)   NOT NULL,

        /* Response */
        RespondedAt            DATETIME2(3)   NULL,
        Decision               NVARCHAR(10)   NULL,   /* 'Confirmed' | 'Rejected' */
        ResponseNotes          NVARCHAR(1000) NULL,
        ResponseIp             NVARCHAR(45)   NULL,

        /* Superseded by a newer link for the same order, or cancelled by a coordinator. */
        InvalidatedAt          DATETIME2(3)   NULL,

        /* Outcome of the Priority external-calibration call that follows an approval. */
        PriorityDocumentNumber NVARCHAR(50)   NULL,
        PriorityError          NVARCHAR(1000) NULL,
        PriorityCompletedAt    DATETIME2(3)   NULL,

        CONSTRAINT PK_OrderApprovalRequest PRIMARY KEY CLUSTERED (OrderApprovalRequestId),
        CONSTRAINT CK_OrderApprovalRequest_Decision
            CHECK (Decision IS NULL OR Decision IN (N'Confirmed', N'Rejected'))
    );

    /* The token is the lookup key for every visit to the approval page. */
    CREATE UNIQUE NONCLUSTERED INDEX UX_OrderApprovalRequest_TokenHash
        ON dbo.OrderApprovalRequest (TokenHash);

    /* "latest open link for this order" — used when a new link supersedes the previous one. */
    CREATE NONCLUSTERED INDEX IX_OrderApprovalRequest_Order_CreatedAt
        ON dbo.OrderApprovalRequest (OrderWorkPlanId, CreatedAt DESC)
        INCLUDE (ExpiresAt, RespondedAt, InvalidatedAt, Decision, SentToEmail);
END
GO
