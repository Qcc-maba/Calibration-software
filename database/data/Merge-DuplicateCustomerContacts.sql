/*
    Merging the contacts off a dead duplicate customer
    ---------------------------------------------------------------------------------------------
    Priority keeps a company's retired record alongside its live one, and both arrive here as
    ordinary customers. West Pharma is the worked example:

        Priority CUST 1123  code 2025   CUSTSTAT -2 active     1,220 invoices, 820 orders
        Priority CUST 7639  code 8556   CUSTSTAT -5 dead       nothing since ~2020

    dbo.Customers.IsInactiveInSource now carries that status (see
    dbo.RefreshCustomerStatusFromPriority), so the dead record no longer reads as live. What it
    still holds is people: 14 contacts, while the live record holds 86. Leaving them there hides
    six real West Pharma employees behind a customer nobody will open again.

    NOT a blind reassign. Seven of the fourteen are the SAME person as a contact already on the
    live record - same e-mail - and moving them would put a duplicate on the live customer, which
    is worse than the problem being fixed. One more matches only by name and has no e-mail. So:

        6  moved to the live customer   (no counterpart there)
        8  retired in place             (7 same e-mail, 1 same name)

    Nothing is deleted. "Retired" means IsDeleted = 1, which is this system's own soft delete;
    the row and its Priority key stay.

    ADDRESSED BY PRIORITY KEY, NOT BY CustomerId. CustomerId is an identity column and differs
    between STAGE and PROD - West Pharma's dead record is 7553 on both today, but that is luck,
    not a guarantee. CustomerIdFromSource is the Priority CUST and is the same everywhere.

    Run with @Apply = 0 first: it reports the split and touches nothing. Re-running after an apply
    is a no-op, because the moved rows no longer sit on the dead customer.

    To use it for another of the 226 duplicated names, change the two keys below.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @LiveCust INT = 1123,   /* Priority CUST of the record to keep */
        @DeadCust INT = 7639,   /* Priority CUST of the record being retired */
        @Apply    BIT = 0;

DECLARE @LiveId INT = (SELECT CustomerId FROM dbo.Customers
                       WHERE CustomerIdFromSource = @LiveCust AND SourceId = 1),
        @DeadId INT = (SELECT CustomerId FROM dbo.Customers
                       WHERE CustomerIdFromSource = @DeadCust AND SourceId = 1);

IF @LiveId IS NULL OR @DeadId IS NULL
BEGIN
    RAISERROR('Live or dead customer not found for the given Priority CUST values.', 16, 1);
    RETURN;
END

SELECT d.CustomerContactId,
       d.CustomerContactName,
       d.CustomerContactEmail,
       CASE
         WHEN ISNULL(d.CustomerContactEmail, '') <> '' AND EXISTS (
              SELECT 1 FROM dbo.CustomerContacts l
              WHERE l.CustomerId = @LiveId AND l.IsDeleted = 0
                AND l.CustomerContactEmail = d.CustomerContactEmail)      THEN 'RETIRE-email'
         WHEN ISNULL(d.CustomerContactEmail, '') = '' AND EXISTS (
              SELECT 1 FROM dbo.CustomerContacts l
              WHERE l.CustomerId = @LiveId AND l.IsDeleted = 0
                AND l.CustomerContactName = d.CustomerContactName)        THEN 'RETIRE-name'
         ELSE 'MOVE'
       END AS Verdict
INTO #Plan
FROM dbo.CustomerContacts d
WHERE d.CustomerId = @DeadId
  AND d.IsDeleted = 0;

SELECT Verdict, COUNT(*) AS Contacts FROM #Plan GROUP BY Verdict ORDER BY Verdict;
SELECT * FROM #Plan ORDER BY Verdict, CustomerContactName;

IF @Apply = 1
BEGIN
    BEGIN TRAN;

    UPDATE c
        SET c.CustomerId  = @LiveId,
            c.UpdatedDate = SYSUTCDATETIME()
    FROM dbo.CustomerContacts AS c
    INNER JOIN #Plan AS p ON p.CustomerContactId = c.CustomerContactId
    WHERE p.Verdict = 'MOVE';
    SELECT @@ROWCOUNT AS Moved;

    UPDATE c
        SET c.IsDeleted   = 1,
            c.UpdatedDate = SYSUTCDATETIME()
    FROM dbo.CustomerContacts AS c
    INNER JOIN #Plan AS p ON p.CustomerContactId = c.CustomerContactId
    WHERE p.Verdict LIKE 'RETIRE%';
    SELECT @@ROWCOUNT AS Retired;

    COMMIT;

    SELECT (SELECT COUNT(*) FROM dbo.CustomerContacts WHERE CustomerId = @LiveId AND IsDeleted = 0) AS LiveContactsNow,
           (SELECT COUNT(*) FROM dbo.CustomerContacts WHERE CustomerId = @DeadId AND IsDeleted = 0) AS DeadContactsLeft,
           (SELECT COUNT(*) FROM dbo.CustomerContacts a
            WHERE a.CustomerId = @LiveId AND a.IsDeleted = 0
              AND ISNULL(a.CustomerContactEmail,'') <> ''
              AND EXISTS (SELECT 1 FROM dbo.CustomerContacts b
                          WHERE b.CustomerId = @LiveId AND b.IsDeleted = 0
                            AND b.CustomerContactEmail = a.CustomerContactEmail
                            AND b.CustomerContactId <> a.CustomerContactId))                        AS DuplicateEmailsIntroduced;
END

DROP TABLE #Plan;
