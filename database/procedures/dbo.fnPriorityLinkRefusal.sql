/*
    dbo.fnPriorityLinkRefusal                                                          MBA-1028
    ---------------------------------------------------------------------------------------------
    Why this database must not read Priority through @LinkedServer, or NULL when it may.

    The one place that knows which Priority server is production. Used by
    dbo.GetPriorityLinkedServer on every read, by dbo.SetPriorityLinkedServer before it changes
    anything, and by database/tests/Test-PriorityLinkedServer.sql.

    The rule is about where the link GOES (sys.servers.data_source), not what it is called, so an
    alias of the production link under another name is refused just the same:

        CalibratorProd  must use a link to live Priority, 31.168.173.93 on port 1433.
        any other DB    must NOT use one. STAGE reads priority-test only (MBA-1028).

    data_source is normalised before comparing: a "TCP:" prefix and the default port ",1433" are
    dropped. priority-test is reached on the same office address but port 14330, so it stays
    distinct.

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

    SET @Source = LTRIM(RTRIM(@Source));
    IF @Source LIKE N'TCP:%'   SET @Source = SUBSTRING(@Source, 5, 4000);
    IF @Source LIKE N'%,1433'  SET @Source = LEFT(@Source, LEN(@Source) - 5);

    DECLARE @IsProductionSource BIT = IIF(@Source = @ProductionSource, 1, 0);

    IF DB_NAME() = @ProductionDatabase AND @IsProductionSource = 0
        RETURN N'Database ' + DB_NAME() + N' must read live Priority, but ' + QUOTENAME(@LinkedServer)
             + N' goes to ' + @Source + N'.';

    IF DB_NAME() <> @ProductionDatabase AND @IsProductionSource = 1
        RETURN N'Database ' + DB_NAME() + N' must not read live Priority, but ' + QUOTENAME(@LinkedServer)
             + N' goes to it. STAGE reads priority-test only (MBA-1028).';

    RETURN NULL;
END
GO
