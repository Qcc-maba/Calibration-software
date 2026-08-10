/*
    dbo.CreateCustomerPortalOtp
    ---------------------------
    Step 3 of the customer-portal login: issue a one-time passcode for an e-mail that belongs to a
    customer contact. The application generates the 6-digit code, hashes it (HMAC-SHA256 + server
    pepper) and passes only @CodeHash here - the plaintext code never reaches the database.

    Identity resolution is hybrid:
      1. dbo.CustomerContacts - the local mirror of Priority.
      2. Priority PHONEBOOK over the linked server, when the mirror does not know the e-mail. The
         mirror only carries ~2k of the ~22k contacts that exist in Priority, so without this step
         most legitimate contacts are told their address is unknown.

    A contact found only in Priority is materialised into dbo.CustomerContacts before the code is
    issued. That is deliberate: every other portal procedure resolves the customer by looking the
    logged-in e-mail up in CustomerContacts, so a session with no row there would authenticate and
    then show an empty portal. The inserted row carries SourceId/CustomerContactIdFromSource exactly
    as the Priority sync would write them, so the sync can still match it.

    A Priority contact whose customer does not exist locally is rejected - there would be no
    CustomerId to scope the portal's data by.

    Any previously issued, still-open code for the same e-mail is invalidated, so only the newest
    code can ever be redeemed.

    Result set (always exactly 1 row):
        Status        'Created' | 'EmailNotFound' | 'RateLimited'
        ExpiresAt     UTC expiry of the new code (NULL unless Created)
        RetryAfterSec seconds until the rate-limit window frees up (NULL unless RateLimited)
        IdentitySource 'Mirror' | 'Priority' | NULL
        CustomerId, CustomerContactId, CustomerContactName, CustomerName, MatchCount
*/
CREATE OR ALTER PROCEDURE dbo.CreateCustomerPortalOtp
    @Email         NVARCHAR(100),
    @CodeHash      VARBINARY(32),
    @TtlSeconds    INT     = 600,   /* code lifetime            */
    @MaxAttempts   TINYINT = 5,     /* wrong-code tries allowed  */
    @MaxPerWindow  INT     = 5,     /* codes issued per window   */
    @WindowSeconds INT     = 900,
    @RequestIp     NVARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NormalizedEmail NVARCHAR(100) = LOWER(LTRIM(RTRIM(@Email)));
    DECLARE @Now DATETIME2(3) = SYSUTCDATETIME();

    DECLARE @CustomerId        INT,
            @CustomerContactId INT,
            @ContactName       NVARCHAR(100),
            @ContactPhone      NVARCHAR(100),
            @CustomerName      NVARCHAR(200),
            @PriorityPhone     INT,
            @MatchCount        INT = 0,
            @IdentitySource    NVARCHAR(10);

    /* ---------- 1. local mirror ---------- */
    SELECT TOP (1)
        @CustomerContactId = cc.CustomerContactId,
        @CustomerId        = cc.CustomerId,
        @ContactName       = cc.CustomerContactName
    FROM dbo.CustomerContacts AS cc
    WHERE cc.IsDeleted = 0
      AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @NormalizedEmail
    ORDER BY cc.CustomerContactId ASC;

    IF @CustomerContactId IS NOT NULL
    BEGIN
        SET @IdentitySource = N'Mirror';

        SELECT @MatchCount = COUNT(DISTINCT cc.CustomerId)
        FROM dbo.CustomerContacts AS cc
        WHERE cc.IsDeleted = 0
          AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @NormalizedEmail;
    END
    ELSE
    BEGIN
        /* ---------- 2. Priority fallback ---------- */
        CREATE TABLE #PriorityContacts (PHONE INT, CUST INT, NAME NVARCHAR(100), PHONENUM NVARCHAR(50));

        BEGIN TRY
            INSERT INTO #PriorityContacts (PHONE, CUST, NAME, PHONENUM)
            EXEC dbo.GetPriorityContactsByEmail @Email = @NormalizedEmail;
        END TRY
        BEGIN CATCH
            /* linked server unreachable - fall through as "not a known contact" */
            DELETE FROM #PriorityContacts;
        END CATCH

        SELECT TOP (1)
            @PriorityPhone = p.PHONE,
            @CustomerId    = c.CustomerId,
            @ContactName   = LEFT(LTRIM(RTRIM(p.NAME)), 100),
            @ContactPhone  = LEFT(LTRIM(RTRIM(p.PHONENUM)), 100)
        FROM #PriorityContacts AS p
        INNER JOIN dbo.Customers AS c
                ON c.CustomerIdFromSource = p.CUST
               AND c.IsDeleted = 0
        ORDER BY p.PHONE ASC;

        IF @PriorityPhone IS NOT NULL
            SELECT @MatchCount = COUNT(DISTINCT c.CustomerId)
            FROM #PriorityContacts AS p
            INNER JOIN dbo.Customers AS c
                    ON c.CustomerIdFromSource = p.CUST
                   AND c.IsDeleted = 0;

        DROP TABLE #PriorityContacts;

        IF @PriorityPhone IS NOT NULL AND @CustomerId IS NOT NULL
        BEGIN
            /* materialise so the rest of the portal can resolve this visitor */
            INSERT INTO dbo.CustomerContacts
                (CustomerId, CustomerContactName, CustomerContactPhone, CustomerContactEmail,
                 CustomerContactIdFromSource, SourceId, CreateDate, IsDeleted)
            SELECT @CustomerId, @ContactName, @ContactPhone, @NormalizedEmail,
                   @PriorityPhone, 1, @Now, 0
            WHERE NOT EXISTS (   /* another concurrent request may have just created it */
                SELECT 1 FROM dbo.CustomerContacts AS cc
                WHERE cc.IsDeleted = 0
                  AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @NormalizedEmail
            );

            SELECT TOP (1) @CustomerContactId = cc.CustomerContactId
            FROM dbo.CustomerContacts AS cc
            WHERE cc.IsDeleted = 0
              AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @NormalizedEmail
            ORDER BY cc.CustomerContactId ASC;

            SET @IdentitySource = N'Priority';
        END
    END

    IF @CustomerContactId IS NULL
    BEGIN
        SELECT
            CAST('EmailNotFound' AS NVARCHAR(20)) AS Status,
            CAST(NULL AS DATETIME2(3))            AS ExpiresAt,
            CAST(NULL AS INT)                     AS RetryAfterSec,
            CAST(NULL AS INT)                     AS CustomerId,
            CAST(NULL AS INT)                     AS CustomerContactId,
            CAST(NULL AS NVARCHAR(100))           AS CustomerContactName,
            CAST(NULL AS NVARCHAR(200))           AS CustomerName,
            CAST(0 AS INT)                        AS MatchCount,
            CAST(NULL AS NVARCHAR(10))            AS IdentitySource;
        RETURN;
    END

    SELECT @CustomerName = c.CustomerName
    FROM dbo.Customers AS c
    WHERE c.CustomerId = @CustomerId
      AND c.IsDeleted = 0;

    /* ---- rate limit: at most @MaxPerWindow codes per e-mail per window ---- */
    DECLARE @IssuedInWindow INT, @OldestInWindow DATETIME2(3);

    SELECT
        @IssuedInWindow = COUNT(*),
        @OldestInWindow = MIN(o.CreatedAt)
    FROM dbo.CustomerPortalOtp AS o
    WHERE o.Email = @NormalizedEmail
      AND o.CreatedAt > DATEADD(SECOND, -@WindowSeconds, @Now);

    IF @IssuedInWindow >= @MaxPerWindow
    BEGIN
        SELECT
            CAST('RateLimited' AS NVARCHAR(20)) AS Status,
            CAST(NULL AS DATETIME2(3))          AS ExpiresAt,
            DATEDIFF(SECOND, @Now, DATEADD(SECOND, @WindowSeconds, @OldestInWindow)) AS RetryAfterSec,
            @CustomerId          AS CustomerId,
            @CustomerContactId   AS CustomerContactId,
            @ContactName         AS CustomerContactName,
            @CustomerName        AS CustomerName,
            @MatchCount          AS MatchCount,
            @IdentitySource      AS IdentitySource;
        RETURN;
    END

    DECLARE @ExpiresAt DATETIME2(3) = DATEADD(SECOND, @TtlSeconds, @Now);

    BEGIN TRY
        BEGIN TRANSACTION;

            /* only the newest code stays redeemable */
            UPDATE dbo.CustomerPortalOtp
            SET InvalidatedAt = @Now
            WHERE Email = @NormalizedEmail
              AND ConsumedAt IS NULL
              AND InvalidatedAt IS NULL;

            INSERT INTO dbo.CustomerPortalOtp
                (Email, CodeHash, CustomerId, CustomerContactId, AttemptsLeft, CreatedAt, ExpiresAt, RequestIp)
            VALUES
                (@NormalizedEmail, @CodeHash, @CustomerId, @CustomerContactId, @MaxAttempts, @Now, @ExpiresAt, @RequestIp);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT
        CAST('Created' AS NVARCHAR(20)) AS Status,
        @ExpiresAt           AS ExpiresAt,
        CAST(NULL AS INT)    AS RetryAfterSec,
        @CustomerId          AS CustomerId,
        @CustomerContactId   AS CustomerContactId,
        @ContactName         AS CustomerContactName,
        @CustomerName        AS CustomerName,
        @MatchCount          AS MatchCount,
        @IdentitySource      AS IdentitySource;
END
GO
