/*
    dbo.VerifyCustomerPortalOtp
    ---------------------------
    Step 4 of the customer-portal login: redeem a one-time passcode.

    The comparison is done on the HMAC digest supplied by the application, and a successful
    redemption consumes the row so a code can never be used twice.  A wrong code burns one
    attempt; when AttemptsLeft reaches 0 the code is dead and a new one must be requested.

    Result set (always exactly 1 row):
        Status        'Verified' | 'NotFound' | 'Expired' | 'TooManyAttempts' | 'Invalid'
        AttemptsLeft  tries remaining on the current code (0 unless Invalid/TooManyAttempts)
        Email, CustomerId, CustomerContactId, CustomerContactName, CustomerName  (Verified only)
*/
CREATE OR ALTER PROCEDURE dbo.VerifyCustomerPortalOtp
    @Email    NVARCHAR(100),
    @CodeHash VARBINARY(32)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NormalizedEmail NVARCHAR(100) = LOWER(LTRIM(RTRIM(@Email)));
    DECLARE @Now DATETIME2(3) = SYSUTCDATETIME();

    DECLARE @OtpId        BIGINT,
            @StoredHash   VARBINARY(32),
            @AttemptsLeft TINYINT,
            @ExpiresAt    DATETIME2(3),
            @CustomerId   INT,
            @ContactId    INT;

    SELECT TOP (1)
        @OtpId        = o.CustomerPortalOtpId,
        @StoredHash   = o.CodeHash,
        @AttemptsLeft = o.AttemptsLeft,
        @ExpiresAt    = o.ExpiresAt,
        @CustomerId   = o.CustomerId,
        @ContactId    = o.CustomerContactId
    FROM dbo.CustomerPortalOtp AS o
    WHERE o.Email = @NormalizedEmail
      AND o.ConsumedAt IS NULL
      AND o.InvalidatedAt IS NULL
    ORDER BY o.CreatedAt DESC, o.CustomerPortalOtpId DESC;

    IF @OtpId IS NULL
    BEGIN
        SELECT CAST('NotFound' AS NVARCHAR(20)) AS Status, CAST(0 AS TINYINT) AS AttemptsLeft,
               CAST(NULL AS NVARCHAR(100)) AS Email, CAST(NULL AS INT) AS CustomerId,
               CAST(NULL AS INT) AS CustomerContactId, CAST(NULL AS NVARCHAR(100)) AS CustomerContactName,
               CAST(NULL AS NVARCHAR(200)) AS CustomerName;
        RETURN;
    END

    IF @ExpiresAt <= @Now
    BEGIN
        UPDATE dbo.CustomerPortalOtp SET InvalidatedAt = @Now WHERE CustomerPortalOtpId = @OtpId;

        SELECT CAST('Expired' AS NVARCHAR(20)) AS Status, CAST(0 AS TINYINT) AS AttemptsLeft,
               CAST(NULL AS NVARCHAR(100)) AS Email, CAST(NULL AS INT) AS CustomerId,
               CAST(NULL AS INT) AS CustomerContactId, CAST(NULL AS NVARCHAR(100)) AS CustomerContactName,
               CAST(NULL AS NVARCHAR(200)) AS CustomerName;
        RETURN;
    END

    IF @AttemptsLeft = 0
    BEGIN
        UPDATE dbo.CustomerPortalOtp SET InvalidatedAt = @Now WHERE CustomerPortalOtpId = @OtpId;

        SELECT CAST('TooManyAttempts' AS NVARCHAR(20)) AS Status, CAST(0 AS TINYINT) AS AttemptsLeft,
               CAST(NULL AS NVARCHAR(100)) AS Email, CAST(NULL AS INT) AS CustomerId,
               CAST(NULL AS INT) AS CustomerContactId, CAST(NULL AS NVARCHAR(100)) AS CustomerContactName,
               CAST(NULL AS NVARCHAR(200)) AS CustomerName;
        RETURN;
    END

    IF @StoredHash <> @CodeHash
    BEGIN
        UPDATE dbo.CustomerPortalOtp
        SET AttemptsLeft  = AttemptsLeft - 1,
            InvalidatedAt = CASE WHEN AttemptsLeft - 1 = 0 THEN @Now ELSE InvalidatedAt END
        WHERE CustomerPortalOtpId = @OtpId;

        SELECT CAST('Invalid' AS NVARCHAR(20)) AS Status, CAST(@AttemptsLeft - 1 AS TINYINT) AS AttemptsLeft,
               CAST(NULL AS NVARCHAR(100)) AS Email, CAST(NULL AS INT) AS CustomerId,
               CAST(NULL AS INT) AS CustomerContactId, CAST(NULL AS NVARCHAR(100)) AS CustomerContactName,
               CAST(NULL AS NVARCHAR(200)) AS CustomerName;
        RETURN;
    END

    /* correct code — consume it, and only then hand back the identity */
    UPDATE dbo.CustomerPortalOtp
    SET ConsumedAt = @Now
    WHERE CustomerPortalOtpId = @OtpId
      AND ConsumedAt IS NULL;

    IF @@ROWCOUNT = 0   /* raced with another redemption of the same code */
    BEGIN
        SELECT CAST('NotFound' AS NVARCHAR(20)) AS Status, CAST(0 AS TINYINT) AS AttemptsLeft,
               CAST(NULL AS NVARCHAR(100)) AS Email, CAST(NULL AS INT) AS CustomerId,
               CAST(NULL AS INT) AS CustomerContactId, CAST(NULL AS NVARCHAR(100)) AS CustomerContactName,
               CAST(NULL AS NVARCHAR(200)) AS CustomerName;
        RETURN;
    END

    SELECT
        CAST('Verified' AS NVARCHAR(20)) AS Status,
        CAST(0 AS TINYINT)               AS AttemptsLeft,
        @NormalizedEmail                 AS Email,
        @CustomerId                      AS CustomerId,
        @ContactId                       AS CustomerContactId,
        cc.CustomerContactName           AS CustomerContactName,
        c.CustomerName                   AS CustomerName
    FROM (SELECT 1 AS X) AS Anchor
    LEFT JOIN dbo.CustomerContacts AS cc ON cc.CustomerContactId = @ContactId
    LEFT JOIN dbo.Customers        AS c  ON c.CustomerId = @CustomerId;
END
GO
