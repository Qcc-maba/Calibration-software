/*  The half of the Philips identity fix that the Priority flag cannot reach.

    WHERE TO RUN
      SSMS -> 51.17.121.203\QCC. Run once against **Calibrator** (STAGE) and once against
      **CalibratorProd**. It works from the e-mail address and the Priority ids, never from local
      row ids, which differ between the two databases.

    RUN THE SCHEMA AND PROCEDURE CHANGES FIRST
      database/schema/dbo.CustomerContacts.IsActive.sql, then the four procedures
      (stg.LoadCustomerContactsFromPriority, stg.MergeCustomersContactsData,
      dbo.GetPortalCustomerIds, dbo.CreateCustomerPortalOtp, dbo.GetCustomerPortalContactByEmail).
      This script needs the IsActive column.

    WHAT IT DOES
      Priority holds eliran_ha@mba.co.il on three contacts: PHONE 52397 (CUST 1), 53544 (CUST 2)
      and 56102 (CUST 6674, Philips). Marking the first two INACTIVE in Priority is what retires
      them here - the sync carries the flag now, and nothing is deleted on either side.

      Two things the sync cannot do on its own, which is all this script is for:

        1. A hand-made contact row exists for this address on a customer Priority never associated
           with it (המ-לט on STAGE, לרית on PROD). It has no Priority id, so no Priority flag will
           ever reach it. It is marked inactive here.
        2. The Philips contact (PHONE 56102) has never arrived in the mirror at all, even though it
           maps cleanly to one local customer. It is created here the way the sync would create it;
           the next sync will simply match and update it.

    SAFETY
      Every row it touches is copied to dbo.CustomerContacts_PortalIdentityBackup_20260907 first,
      and the last statement prints what the portal will now resolve to. The undo is at the bottom.

    Prepared 2026-09-07.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Email        NVARCHAR(100) = N'eliran_ha@mba.co.il',
        @PhilipsCust  INT = 6674,    /* Priority CUST  */
        @PhilipsPhone INT = 56102;   /* Priority PHONE */

DECLARE @CustomerId INT, @ContactName NVARCHAR(100), @Rows INT;

IF COL_LENGTH('dbo.CustomerContacts', 'IsActive') IS NULL
BEGIN
    RAISERROR('dbo.CustomerContacts has no IsActive column - run database/schema/dbo.CustomerContacts.IsActive.sql first. Nothing changed.', 16, 1);
    RETURN;
END;

-------------------------------------------------------------------------------
-- 0. the local customer behind Priority CUST 6674, and the name Priority uses
-------------------------------------------------------------------------------

SELECT @CustomerId = CustomerId
FROM   dbo.Customers
WHERE  CustomerIdFromSource = @PhilipsCust
  AND  SourceId = 1              /* MABA - not the SEPHARM customer that shares the number */
  AND  IsDeleted = 0;

IF @CustomerId IS NULL
BEGIN
    RAISERROR('No local customer for Priority CUST 6674 - nothing changed.', 16, 1);
    RETURN;
END;

/* Lift the spelling from a row the sync itself wrote, so no Hebrew literal has to survive this
   file's encoding on the way to the server. */
SELECT TOP (1) @ContactName = CustomerContactName
FROM   dbo.CustomerContacts
WHERE  LOWER(LTRIM(RTRIM(CustomerContactEmail))) = @Email
  AND  CustomerContactIdFromSource IS NOT NULL
ORDER BY CustomerContactIdFromSource;

-------------------------------------------------------------------------------
-- 1. back up every row for this address before anything changes
-------------------------------------------------------------------------------

IF OBJECT_ID('dbo.CustomerContacts_PortalIdentityBackup_20260907', 'U') IS NULL
    SELECT *
    INTO   dbo.CustomerContacts_PortalIdentityBackup_20260907
    FROM   dbo.CustomerContacts
    WHERE  LOWER(LTRIM(RTRIM(CustomerContactEmail))) = @Email;

SELECT @Rows = COUNT(*) FROM dbo.CustomerContacts_PortalIdentityBackup_20260907;
PRINT CONCAT('Backup holds ', @Rows, ' rows.');

-------------------------------------------------------------------------------
-- 2. retire the hand-made rows - the ones no Priority flag can ever reach
-------------------------------------------------------------------------------

UPDATE dbo.CustomerContacts
SET    IsActive    = 0,
       UpdatedDate = SYSUTCDATETIME()
WHERE  LOWER(LTRIM(RTRIM(CustomerContactEmail))) = @Email
  AND  ISNULL(IsDeleted, 0) = 0
  AND  CustomerContactIdFromSource IS NULL       /* never came from Priority */
  AND  ISNULL(IsActive, 1) = 1;

SET @Rows = @@ROWCOUNT;
PRINT CONCAT('Hand-made rows marked inactive: ', @Rows, '.');

-------------------------------------------------------------------------------
-- 3. create the Philips contact the sync should have created
-------------------------------------------------------------------------------

INSERT INTO dbo.CustomerContacts
      (CustomerId, CustomerContactName, CustomerContactEmail, CustomerContactIdFromSource,
       SourceId, CreateDate, IsDeleted, IsPrimary, DoNotMail, IsActive)
SELECT @CustomerId, @ContactName, @Email, @PhilipsPhone,
       1, SYSUTCDATETIME(), 0, 0, 0, 1
WHERE NOT EXISTS (SELECT 1
                  FROM   dbo.CustomerContacts
                  WHERE  CustomerContactIdFromSource = @PhilipsPhone
                    AND  ISNULL(IsDeleted, 0) = 0);

SET @Rows = @@ROWCOUNT;
PRINT CONCAT('Philips contact rows created: ', @Rows, ' (0 means it already existed).');

-------------------------------------------------------------------------------
-- 4. what the portal resolves to now
-------------------------------------------------------------------------------

/*  Expect Philips to be one of the rows. The two מ.ב.א customers stay until they are marked
    INACTIVE in Priority and the contact sync runs - that part is deliberately not done here. */
SELECT * FROM dbo.GetPortalCustomerIds(@Email);

-------------------------------------------------------------------------------
-- Undo. Select these lines and run them alone.
-------------------------------------------------------------------------------
/*
DELETE FROM dbo.CustomerContacts
WHERE  CustomerContactIdFromSource = 56102
  AND  NOT EXISTS (SELECT 1 FROM dbo.CustomerContacts_PortalIdentityBackup_20260907 AS b
                   WHERE  b.CustomerContactId = dbo.CustomerContacts.CustomerContactId);

UPDATE c
SET    c.IsActive = ISNULL(b.IsActive, 1)
FROM   dbo.CustomerContacts AS c
JOIN   dbo.CustomerContacts_PortalIdentityBackup_20260907 AS b ON b.CustomerContactId = c.CustomerContactId;

DROP TABLE dbo.CustomerContacts_PortalIdentityBackup_20260907;
*/
