/*
    dbo.CustomerPortalOtp  --  one-time passcodes for the customer portal e-mail login.

    A row is created by dbo.CreateCustomerPortalOtp and consumed by dbo.VerifyCustomerPortalOtp.
    The plaintext code NEVER reaches the database: the application sends an HMAC-SHA256 digest
    (32 bytes) computed with a server-side pepper, so a DB reader cannot replay a live code.

    All timestamps are UTC (SYSUTCDATETIME) so the TTL is timezone independent.
*/
IF OBJECT_ID('dbo.CustomerPortalOtp', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CustomerPortalOtp
    (
        CustomerPortalOtpId BIGINT         IDENTITY(1, 1) NOT NULL,
        Email               NVARCHAR(100)  NOT NULL,
        CodeHash            VARBINARY(32)  NOT NULL,
        CustomerId          INT            NULL,
        CustomerContactId   INT            NULL,
        AttemptsLeft        TINYINT        NOT NULL,
        CreatedAt           DATETIME2(3)   NOT NULL CONSTRAINT DF_CustomerPortalOtp_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ExpiresAt           DATETIME2(3)   NOT NULL,
        ConsumedAt          DATETIME2(3)   NULL,
        InvalidatedAt       DATETIME2(3)   NULL,
        RequestIp           NVARCHAR(45)   NULL,
        CONSTRAINT PK_CustomerPortalOtp PRIMARY KEY CLUSTERED (CustomerPortalOtpId)
    );

    /* Lookup path for both the rate-limit window and "latest open code for this e-mail". */
    CREATE NONCLUSTERED INDEX IX_CustomerPortalOtp_Email_CreatedAt
        ON dbo.CustomerPortalOtp (Email, CreatedAt DESC)
        INCLUDE (CodeHash, AttemptsLeft, ExpiresAt, ConsumedAt, InvalidatedAt, CustomerId, CustomerContactId);
END
GO
