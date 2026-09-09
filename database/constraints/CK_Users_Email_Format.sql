/*
    CK_Users_Email_Format
    ---------------------------------------------------------------------------------------------
    Stops dbo.Users accepting values in Email that cannot be an e-mail address.

    WHY
    ---
    The column had no validation at all, and the rows that got in are not harmless. User 2055 was
    created as "A X" with the address 121gmail.com - no @ - and the application then wrote that
    account onto 19 work items as their main calibrator, so calibration reports were issued naming
    it. Others on PROD: '.', a phone number, and an address with a space in the middle.

    An account whose address cannot receive mail is worse than a missing one: it looks like a real
    calibrator on a signed report, and nothing ever bounces to reveal the mistake.

    THE RULE, AND WHY IT IS DELIBERATELY LOOSE
    ------------------------------------------
    something @ something . at-least-two-more, and no spaces anywhere.

    It is not a full RFC 5322 check and is not meant to be - the aim is to reject the values that
    are obviously not addresses while never rejecting a real one. Anything stricter risks blocking
    a legitimate address, which is a worse failure than letting an odd-looking one through.

    WITH NOCHECK IS INTENTIONAL
    ---------------------------
    Existing rows are left alone: 2 on STAGE and 6 on PROD would fail, one of them the ETL system
    account (ID 0, 'N/A'). Validating them would fail the deployment, and cleaning them needs the
    real addresses, which only the business knows. The constraint still applies in full to every
    INSERT and UPDATE from this point on, so the problem stops growing while the existing rows are
    corrected separately.

    To tighten later, once the offenders are fixed:
        ALTER TABLE dbo.Users WITH CHECK CHECK CONSTRAINT CK_Users_Email_Format;

    NOT COVERED HERE: dbo.Users allows duplicate addresses - 38 on PROD - and dbo.GetLoginUser
    resolves a user with WHERE Email = @email, so a duplicate makes the account you get arbitrary.
    That is a correctness problem in its own right and needs its own decision; a unique index is
    the fix, but only after the duplicates are merged.
*/

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Users_Email_Format')
BEGIN
    ALTER TABLE dbo.Users WITH NOCHECK
        ADD CONSTRAINT CK_Users_Email_Format CHECK
        (
            Email IS NULL
            OR (
                Email LIKE '%_@_%_.__%'
                AND Email NOT LIKE '% %'
            )
        );

    PRINT 'CK_Users_Email_Format created (WITH NOCHECK - existing rows untouched)';
END
ELSE
BEGIN
    PRINT 'CK_Users_Email_Format already exists';
END
GO

/* what the constraint will and will not allow, for whoever reviews this */
SELECT
    ConstraintName = c.name,
    IsDisabled     = c.is_disabled,
    IsNotTrusted   = c.is_not_trusted,
    Definition     = c.definition
FROM sys.check_constraints AS c
WHERE c.name = 'CK_Users_Email_Format';
GO
