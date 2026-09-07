/*  Deactivate the 34 duplicate accounts on CalibratorProd.

    WHERE TO RUN
      SSMS -> connect to 51.17.121.203\QCC  ->  database CalibratorProd  ->  open this file  ->  F5.
      Run it whole. It is one batch: the guard cannot be skipped by running only part of it.

    WHAT IT DOES
      38 e-mail addresses carry more than one account. In 31 of those groups every account has the
      identical name and role - the same person entered more than once, not a shared mailbox. This
      keeps the lowest id in each group (the oldest account, the one calibration history is most
      likely to reference) and deactivates the other 34.

      The seven remaining groups differ in spelling or role and are listed in
      duplicate-emails-2026-09-07.md - they are deliberately NOT touched here.

    SAFETY
      Part 1 copies the current IsActive of every affected row into
      dbo.Users_DuplicateBackup_20260907 before anything changes.
      Part 2 refuses to run if any id in the list would be left with no lower-numbered account on
      the same address.
      Part 4 (commented out at the bottom) puts everything back from that backup table.

    Prepared 2026-09-07.  Expected result: 79 active accounts -> 45.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Ids TABLE (ID INT PRIMARY KEY);

INSERT INTO @Ids (ID)
VALUES (2360),(2445),(2910),(3016),(3217),(3296),(3371),(3411),(3465),(3551),(3554),(3580),
       (3625),(3696),(3708),(3709),(3715),(3801),(3919),(3935),(3949),(3950),(3955),(4012),
       (4132),(4133),(4141),(4149),(4153),(4154),(4156),(4164),(4167),(4169);

-------------------------------------------------------------------------------
-- Part 1: capture what you are about to change
-------------------------------------------------------------------------------

IF OBJECT_ID('dbo.Users_DuplicateBackup_20260907', 'U') IS NOT NULL
BEGIN
    /* Already run once. Stop rather than overwrite the record of the original state. */
    RAISERROR('dbo.Users_DuplicateBackup_20260907 already exists - this script has already run. Nothing changed.', 16, 1);
    RETURN;
END;

SELECT u.ID, u.Email, u.FirstName, u.LastName, u.IsActive
INTO   dbo.Users_DuplicateBackup_20260907
FROM   dbo.Users AS u
JOIN   @Ids AS i ON i.ID = u.ID;

PRINT CONCAT('Backed up ', @@ROWCOUNT, ' rows into dbo.Users_DuplicateBackup_20260907.');

-------------------------------------------------------------------------------
-- Part 2: refuse to run if any address would be left with no active account
-------------------------------------------------------------------------------

IF EXISTS (
    SELECT 1
    FROM   dbo.Users AS u
    JOIN   @Ids AS i ON i.ID = u.ID
    WHERE  NOT EXISTS (SELECT 1
                       FROM   dbo.Users AS k
                       WHERE  LOWER(LTRIM(RTRIM(k.Email))) = LOWER(LTRIM(RTRIM(u.Email)))
                         AND  k.ID < u.ID))
BEGIN
    THROW 50001, 'One of these ids has no lower-numbered account on the same address - nothing changed.', 1;
END;

-------------------------------------------------------------------------------
-- Part 3: deactivate
-------------------------------------------------------------------------------

UPDATE u
SET    u.IsActive    = 0,
       u.UpdatedDate = SYSUTCDATETIME()
FROM   dbo.Users AS u
JOIN   @Ids AS i ON i.ID = u.ID
WHERE  ISNULL(u.IsActive, 0) = 1;

PRINT CONCAT('Deactivated ', @@ROWCOUNT, ' accounts.');

-------------------------------------------------------------------------------
-- Check: how many active accounts are left, and are any addresses still doubled
-------------------------------------------------------------------------------

SELECT ActiveAccounts = COUNT(*)
FROM   dbo.Users
WHERE  ISNULL(IsActive, 0) = 1;

SELECT Email        = LOWER(LTRIM(RTRIM(Email))),
       StillActive  = COUNT(*)
FROM   dbo.Users
WHERE  ISNULL(IsActive, 0) = 1
  AND  Email LIKE '%@%'
GROUP BY LOWER(LTRIM(RTRIM(Email)))
HAVING COUNT(*) > 1
ORDER BY 2 DESC, 1;
/*  The seven groups from the document are expected to appear here. Anything else is a surprise
    worth reading before you accept it. */

-------------------------------------------------------------------------------
-- Part 4: undo, if you want the previous state back. Select these lines and run them alone.
-------------------------------------------------------------------------------
/*
UPDATE u
SET    u.IsActive = b.IsActive
FROM   dbo.Users AS u
JOIN   dbo.Users_DuplicateBackup_20260907 AS b ON b.ID = u.ID;

DROP TABLE dbo.Users_DuplicateBackup_20260907;
*/
