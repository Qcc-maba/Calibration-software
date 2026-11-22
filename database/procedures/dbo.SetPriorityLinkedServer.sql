/*
    dbo.SetPriorityLinkedServer                                                        MBA-1028
    ---------------------------------------------------------------------------------------------
    Points this database at a Priority server: writes the dbo.PriorityLinkedServer row and
    re-points the prio.* synonyms, together, so the two mechanisms can never disagree.

    Two mechanisms because the readers come in two shapes:

    * OPENQUERY readers (18 procedures) take the server from dbo.GetPriorityLinkedServer at run
      time - OPENQUERY accepts only a literal name, so they build their SQL dynamically.
    * four-part-name readers (dbo.RefreshCrmTextCache, dbo.GetCatalogTextByPart) join remote
      tables to local temp tables. They read prio.<TABLE>, a synonym for
      <server>.amaba.dbo.<TABLE>. A synonym cannot take its server from a setting, which is why
      this procedure recreates them whenever the setting changes.

    Refuses (51021) a server that is wrong for this database - see dbo.fnPriorityLinkRefusal - and
    (51023) a link whose remote machine is not the expected one (MABA-PRIORITY for CalibratorProd,
    PRIORITY-TEST elsewhere), asked of the remote server itself. STAGE cannot be pointed at live
    Priority, nor PROD at the copy, even by this procedure.

        EXEC dbo.SetPriorityLinkedServer @LinkedServer = N'<linked server>',
             @UpdatedBy = N'<who>', @Reason = N'<why>';                      -- dry run: the plan
        EXEC dbo.SetPriorityLinkedServer @LinkedServer = N'<linked server>',
             @UpdatedBy = N'<who>', @Reason = N'<why>', @Apply = 1;          -- do it

    Which server each database uses is in the header of dbo.PriorityLinkedServer.table.sql. The
    name is deliberately not written in any module: database/tests/Test-PriorityLinkedServer.sql
    fails on a module that names a server.

    Idempotent: a second run with the same server reports nothing to change.
*/
CREATE OR ALTER PROCEDURE dbo.SetPriorityLinkedServer
    @LinkedServer SYSNAME,
    @UpdatedBy    NVARCHAR(100),
    @Reason       NVARCHAR(400),
    @Apply        BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Refusal NVARCHAR(400) = dbo.fnPriorityLinkRefusal(@LinkedServer);
    IF @Refusal IS NOT NULL
        THROW 51021, @Refusal, 1;

    IF NULLIF(LTRIM(RTRIM(@UpdatedBy)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Reason)), N'') IS NULL
        THROW 51022, N'Say who is changing the Priority link and why: @UpdatedBy and @Reason are required.', 1;

    /* Ask the server behind the link who it is, so a link whose address passes the allowlist but
       reaches the wrong machine is still refused. The physical machine name, not @@SERVERNAME:
       priority-test is a cloned VM whose @@SERVERNAME still says MABA-PRIORITY\PRI. */
    DECLARE @ExpectedMachine SYSNAME = IIF(DB_NAME() = N'CalibratorProd', N'MABA-PRIORITY', N'PRIORITY-TEST'),
            @Machine         SYSNAME = NULL,
            @MachineError    NVARCHAR(2048) = NULL;
    DECLARE @MachineSql NVARCHAR(MAX) =
        N'SELECT @M = Machine FROM OPENQUERY(' + QUOTENAME(@LinkedServer)
        + N', ''SELECT CAST(SERVERPROPERTY(''''ComputerNamePhysicalNetBIOS'''') AS NVARCHAR(128)) AS Machine'')';
    BEGIN TRY
        EXEC sys.sp_executesql @MachineSql, N'@M SYSNAME OUTPUT', @M = @Machine OUTPUT;
    END TRY
    BEGIN CATCH
        SET @MachineError = ERROR_MESSAGE();
    END CATCH

    IF @Machine IS NULL OR @Machine <> @ExpectedMachine
    BEGIN
        DECLARE @MachineRefusal NVARCHAR(2048) =
            N'Database ' + DB_NAME() + N' must reach ' + @ExpectedMachine + N' through ' + QUOTENAME(@LinkedServer)
            + N', but ' + COALESCE(N'it answered as ' + @Machine, N'it could not be asked: ' + @MachineError, N'it did not answer')
            + N'. Nothing changed.';
        THROW 51023, @MachineRefusal, 1;
    END

    /* The remote tables read by four-part name. Add a table here before a procedure reads it. */
    DECLARE @Tables TABLE (TableName SYSNAME PRIMARY KEY);
    INSERT INTO @Tables (TableName)
    VALUES (N'FAMILY'), (N'ORDERSTEXT'), (N'PART'), (N'PARTTEXT'), (N'SERNUMBERSTEXT');

    DECLARE @Plan TABLE (Item NVARCHAR(200), CurrentValue NVARCHAR(1035), NewValue NVARCHAR(1035), Changes BIT);

    DECLARE @Current SYSNAME = (SELECT LinkedServer FROM dbo.PriorityLinkedServer WHERE Id = 1);
    INSERT INTO @Plan VALUES
        (N'dbo.PriorityLinkedServer', @Current, @LinkedServer, IIF(ISNULL(@Current, N'') = @LinkedServer, 0, 1));

    INSERT INTO @Plan (Item, CurrentValue, NewValue, Changes)
    SELECT N'synonym prio.' + t.TableName,
           sy.base_object_name,
           QUOTENAME(@LinkedServer) + N'.[amaba].[dbo].' + QUOTENAME(t.TableName),
           IIF(ISNULL(sy.base_object_name, N'') = QUOTENAME(@LinkedServer) + N'.[amaba].[dbo].' + QUOTENAME(t.TableName), 0, 1)
    FROM @Tables AS t
    LEFT JOIN sys.synonyms AS sy
           ON sy.name = t.TableName AND sy.schema_id = SCHEMA_ID(N'prio');

    SELECT Item, CurrentValue, NewValue, Changes FROM @Plan ORDER BY Item;

    IF @Apply = 0 OR NOT EXISTS (SELECT 1 FROM @Plan WHERE Changes = 1)
        RETURN;

    IF SCHEMA_ID(N'prio') IS NULL
        EXEC (N'CREATE SCHEMA prio AUTHORIZATION dbo;');

    BEGIN TRANSACTION;

        IF @Current IS NULL
            INSERT INTO dbo.PriorityLinkedServer (Id, LinkedServer, UpdatedBy, Reason)
            VALUES (1, @LinkedServer, @UpdatedBy, @Reason);
        ELSE
            UPDATE dbo.PriorityLinkedServer
            SET LinkedServer = @LinkedServer, UpdatedAt = SYSUTCDATETIME(),
                UpdatedBy = @UpdatedBy, Reason = @Reason
            WHERE Id = 1;

        DECLARE @Ddl NVARCHAR(MAX) = N'';
        SELECT @Ddl += N'DROP SYNONYM IF EXISTS prio.' + QUOTENAME(t.TableName) + N'; '
                     + N'CREATE SYNONYM prio.' + QUOTENAME(t.TableName) + N' FOR '
                     + QUOTENAME(@LinkedServer) + N'.[amaba].[dbo].' + QUOTENAME(t.TableName) + N'; '
        FROM @Tables AS t;
        EXEC sys.sp_executesql @Ddl;

    COMMIT TRANSACTION;

    SELECT LinkedServer, UpdatedAt, UpdatedBy, Reason FROM dbo.PriorityLinkedServer;
END
GO
