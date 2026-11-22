/*
    dbo.fnPriorityLinkRefusal                                                          MBA-1028
    ---------------------------------------------------------------------------------------------
    Why this database must not read Priority through @LinkedServer, or NULL when it may.

    The one place that knows which Priority server is production. Used by
    dbo.GetPriorityLinkedServer on every read, by dbo.SetPriorityLinkedServer before it changes
    anything, and by database/tests/Test-PriorityLinkedServer.sql.

    The rule is about where the link GOES (sys.servers.data_source), not what it is called, so an
    alias of the production link under another name is refused just the same. Both sides are
    ALLOWLISTS: a source that is not listed is refused, so a production link spelled some other way
    (host name, instance name, DNS alias) can never pass as "not production":

        CalibratorProd  must use live Priority: 31.168.173.93 (port 1433).
        any other DB    must use the test Priority: 31.168.173.93,14330 (priority-test, MBA-1028).

    data_source is normalised before comparing: spaces and a "TCP:" prefix are dropped, and so is
    the default port ",1433". A new test source goes into @TestSources, nowhere else.

    The address check catches a wrong link name; dbo.SetPriorityLinkedServer also asks the remote
    server for its machine name before it stores anything.

    This function is the only module allowed to contain the production address; the test checks
    that no other module does.
*/
CREATE OR ALTER FUNCTION dbo.fnPriorityLinkRefusal (@LinkedServer SYSNAME)
RETURNS NVARCHAR(400)
AS
BEGIN
    DECLARE @ProductionDatabase SYSNAME       = N'CalibratorProd',
            @ProductionSource   NVARCHAR(100) = N'31.168.173.93';

    IF @LinkedServer IS NULL
        RETURN N'No linked server given.';

    DECLARE @Source NVARCHAR(4000) =
        (SELECT s.data_source FROM sys.servers AS s WHERE s.name = @LinkedServer AND s.is_linked = 1);

    IF @Source IS NULL
        RETURN N'There is no linked server named ' + QUOTENAME(@LinkedServer) + N' on this instance.';

    /* Allowed sources for every database other than CalibratorProd. */
    DECLARE @TestSources TABLE (Source NVARCHAR(100) PRIMARY KEY);
    INSERT INTO @TestSources (Source) VALUES (N'31.168.173.93,14330');   -- priority-test

    SET @Source = REPLACE(@Source, N' ', N'');
    IF @Source LIKE N'TCP:%'   SET @Source = SUBSTRING(@Source, 5, 4000);
    IF @Source LIKE N'%,1433'  SET @Source = LEFT(@Source, LEN(@Source) - 5);

    IF DB_NAME() = @ProductionDatabase
    BEGIN
        IF @Source <> @ProductionSource
            RETURN N'Database ' + DB_NAME() + N' must read live Priority, but ' + QUOTENAME(@LinkedServer)
                 + N' goes to ' + @Source + N'.';
        RETURN NULL;
    END

    IF NOT EXISTS (SELECT 1 FROM @TestSources WHERE Source = @Source)
        RETURN N'Database ' + DB_NAME() + N' may read only the test Priority, but ' + QUOTENAME(@LinkedServer)
             + N' goes to ' + @Source + N', which is not on the test list in dbo.fnPriorityLinkRefusal (MBA-1028).';

    RETURN NULL;
END
GO
