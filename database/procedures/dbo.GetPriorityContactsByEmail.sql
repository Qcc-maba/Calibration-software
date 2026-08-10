/*
    dbo.GetPriorityContactsByEmail
    ------------------------------
    Reads the Priority phone book (amaba.dbo.PHONEBOOK) over the linked server for one e-mail.

    Why OPENQUERY and not a plain four-part join: the local predicate
    `LOWER(LTRIM(RTRIM(p.EMAIL))) = @Email` cannot be pushed to the remote server, so SQL Server
    drags all ~25k rows across and filters here - measured at 4.6s per lookup. Pushing the same
    filter through OPENQUERY runs it remotely and returns in ~0.5s.

    The linked server has RPC OUT disabled, so parameters cannot be passed with `EXEC ... AT`; the
    e-mail is therefore embedded in the remote query text with both nesting levels escaped.
    Callers still validate the address before calling.

    Callers consume this with INSERT ... EXEC, so it must not use INSERT ... EXEC itself.
*/
CREATE OR ALTER PROCEDURE dbo.GetPriorityContactsByEmail
    @Email NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NormalizedEmail NVARCHAR(100) = LOWER(LTRIM(RTRIM(@Email)));

    IF @NormalizedEmail IS NULL OR @NormalizedEmail = ''
    BEGIN
        SELECT CAST(NULL AS INT) AS PHONE, CAST(NULL AS INT) AS CUST,
               CAST(NULL AS NVARCHAR(100)) AS NAME, CAST(NULL AS NVARCHAR(50)) AS PHONENUM
        WHERE 1 = 0;
        RETURN;
    END

    DECLARE @Quote CHAR(1) = CHAR(39);

    /* the statement as the remote server will see it */
    DECLARE @RemoteQuery NVARCHAR(MAX) =
        N'SELECT PHONE, CUST, NAME, PHONENUM FROM amaba.dbo.PHONEBOOK WHERE LOWER(LTRIM(RTRIM(EMAIL))) = '
        + @Quote + REPLACE(@NormalizedEmail, @Quote, @Quote + @Quote) + @Quote;

    /* ... wrapped as a string literal inside OPENQUERY, so every quote doubles again */
    DECLARE @Sql NVARCHAR(MAX) =
        N'SELECT PHONE, CUST, NAME, PHONENUM FROM OPENQUERY([31.168.173.93], '
        + @Quote + REPLACE(@RemoteQuery, @Quote, @Quote + @Quote) + @Quote + N')';

    EXEC sp_executesql @Sql;
END
GO
