/*
    dbo.BuildPriorityOpenQuery                                                         MBA-1028
    ---------------------------------------------------------------------------------------------
    Wraps a query for the Priority server in OPENQUERY on this database's linked server, ready to
    splice after FROM in dynamic SQL:

        DECLARE @Oq NVARCHAR(MAX), @Sql NVARCHAR(MAX);
        EXEC dbo.BuildPriorityOpenQuery @RemoteQuery = N'
            SELECT CUST, NAME FROM amaba.dbo.PHONEBOOK WHERE INACTIVE = ''Y''', @OpenQuery = @Oq OUTPUT;
        SET @Sql = N'SELECT CUST, NAME FROM ' + @Oq;
        INSERT INTO #T (CUST, NAME) EXEC sys.sp_executesql @Sql;

    OPENQUERY takes only a literal server name and a literal query, so a reader whose server comes
    from a setting has to be dynamic. This keeps that mechanical:

    * @RemoteQuery is written exactly as it stood inside OPENQUERY('...') before: quotes doubled
      once. A static OPENQUERY moves into it unchanged.
    * the quotes are doubled again here, for the extra literal level.

    Throws, through dbo.GetPriorityLinkedServer, when this database has no usable Priority link.
*/
CREATE OR ALTER PROCEDURE dbo.BuildPriorityOpenQuery
    @RemoteQuery NVARCHAR(MAX),
    @OpenQuery   NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Link NVARCHAR(258);
    EXEC dbo.GetPriorityLinkedServer @QuotedName = @Link OUTPUT;

    SET @OpenQuery = N'OPENQUERY(' + @Link + N', ''' + REPLACE(@RemoteQuery, N'''', N'''''') + N''')';
END
GO
