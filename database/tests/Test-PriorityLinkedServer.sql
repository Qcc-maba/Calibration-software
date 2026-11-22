/*
    Tests for the Priority linked-server setting                                       MBA-1028
    ---------------------------------------------------------------------------------------------
    Run on STAGE and on PROD after every deploy. Writes nothing. Anything other than 'PASS' in
    Result is a failure.

    What it proves, per database:
      1. dbo.PriorityLinkedServer has its row, and dbo.fnPriorityLinkRefusal accepts it.
      2. The link reaches the right machine: PRIORITY-TEST from STAGE, MABA-PRIORITY from PROD.
         Asked of the server itself (ComputerNamePhysicalNetBIOS), because priority-test is a
         cloned VM whose @@SERVERNAME still says MABA-PRIORITY\PRI.
      3. Every prio.* synonym points through the same link, that link is allowed for the database
         (dbo.fnPriorityLinkRefusal), and one of them answers.
      4. No module names a server itself: no production address outside
         dbo.fnPriorityLinkRefusal, no test-server name, no four-part [server].amaba. reference,
         no OPENQUERY on a literal bracketed name. Any of those would read whatever it names,
         whatever the setting says.
*/
SET NOCOUNT ON;

DECLARE @Out TABLE (Seq INT IDENTITY, Test NVARCHAR(80), Expected NVARCHAR(200), Actual NVARCHAR(MAX), Result NVARCHAR(10));

DECLARE @Name SYSNAME = (SELECT LinkedServer FROM dbo.PriorityLinkedServer WHERE Id = 1);
DECLARE @Refusal NVARCHAR(400) = dbo.fnPriorityLinkRefusal(@Name);

INSERT INTO @Out (Test, Expected, Actual, Result)
VALUES (N'1a setting row exists', N'a linked server name', ISNULL(@Name, N'(no row)'), IIF(@Name IS NULL, N'FAIL', N'PASS')),
       (N'1b setting is allowed for ' + DB_NAME(), N'(allowed)', ISNULL(@Refusal, N'(allowed)'), IIF(@Refusal IS NULL AND @Name IS NOT NULL, N'PASS', N'FAIL'));

/* 2. the machine behind the link */
DECLARE @ExpectedMachine SYSNAME = IIF(DB_NAME() = N'CalibratorProd', N'MABA-PRIORITY', N'PRIORITY-TEST');
DECLARE @Machine SYSNAME = NULL, @Err NVARCHAR(400) = NULL;
IF @Name IS NOT NULL AND @Refusal IS NULL
BEGIN
    BEGIN TRY
        DECLARE @Oq NVARCHAR(MAX), @Sql NVARCHAR(MAX);
        EXEC dbo.BuildPriorityOpenQuery @OpenQuery = @Oq OUTPUT, @RemoteQuery =
            N'SELECT CAST(SERVERPROPERTY(''ComputerNamePhysicalNetBIOS'') AS NVARCHAR(128)) AS Machine';
        SET @Sql = N'SELECT @M = Machine FROM ' + @Oq;
        EXEC sys.sp_executesql @Sql, N'@M SYSNAME OUTPUT', @M = @Machine OUTPUT;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
    END CATCH
END
INSERT INTO @Out (Test, Expected, Actual, Result)
VALUES (N'2 link reaches the right machine', @ExpectedMachine, COALESCE(@Machine, @Err, N'(not run)'),
        IIF(@Machine = @ExpectedMachine, N'PASS', N'FAIL'));

/* 3. synonyms */
DECLARE @SynTotal INT, @SynWrong INT;
SELECT @SynTotal = COUNT(*),
       @SynWrong = SUM(IIF(sy.base_object_name LIKE REPLACE(QUOTENAME(@Name), N'[', N'[[]') + N'.%', 0, 1))
FROM sys.synonyms AS sy
WHERE sy.schema_id = SCHEMA_ID(N'prio');

INSERT INTO @Out (Test, Expected, Actual, Result)
VALUES (N'3a prio synonyms exist', N'5', CAST(@SynTotal AS NVARCHAR(10)), IIF(@SynTotal = 5, N'PASS', N'FAIL')),
       (N'3b every prio synonym goes through ' + ISNULL(QUOTENAME(@Name), N'?'), N'0 wrong',
        CAST(ISNULL(@SynWrong, 0) AS NVARCHAR(10)) + N' wrong', IIF(@SynTotal > 0 AND ISNULL(@SynWrong, 0) = 0, N'PASS', N'FAIL'));

DECLARE @PartRows INT = NULL;
SET @Err = NULL;
IF @SynTotal > 0 AND ISNULL(@SynWrong, 0) = 0
BEGIN
    BEGIN TRY
        SELECT @PartRows = COUNT(*) FROM (SELECT TOP (1) PART FROM prio.PART) AS x;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
    END CATCH
END
INSERT INTO @Out (Test, Expected, Actual, Result)
VALUES (N'3c prio.PART answers', N'1 row', COALESCE(CAST(@PartRows AS NVARCHAR(10)) + N' row', @Err, N'(not run)'),
        IIF(@PartRows = 1, N'PASS', N'FAIL'));

/* 3d. The synonym readers never call the resolver, so check the server inside each synonym with
       the same rule: a link recreated with another data_source, or a synonym edited by hand,
       must fail here even though 3b still matches the name. */
DECLARE @SynRefused NVARCHAR(MAX) =
    (SELECT STRING_AGG(N'prio.' + sy.name + N': ' + r.Refusal, N'; ')
     FROM sys.synonyms AS sy
     CROSS APPLY (SELECT dbo.fnPriorityLinkRefusal(PARSENAME(sy.base_object_name, 4)) AS Refusal) AS r
     WHERE sy.schema_id = SCHEMA_ID(N'prio') AND r.Refusal IS NOT NULL);
INSERT INTO @Out (Test, Expected, Actual, Result)
VALUES (N'3d every prio synonym''s server is allowed here', N'(allowed)', ISNULL(@SynRefused, N'(allowed)'),
        IIF(@SynTotal > 0 AND @SynRefused IS NULL, N'PASS', N'FAIL'));

/* 4. no module names a server */
DECLARE @Hard TABLE (Module NVARCHAR(260), Why NVARCHAR(60));
INSERT INTO @Hard (Module, Why)
SELECT s.name + N'.' + o.name,
       CASE WHEN m.definition LIKE N'%31.168.173.93%'               THEN N'production address'
            WHEN m.definition LIKE N'%PRIORITY[_]TEST%'             THEN N'test server name'
            WHEN m.definition LIKE N'%].amaba.%'
              OR m.definition LIKE N'%].[[]amaba].%'                THEN N'four-part [server].amaba.'
            WHEN m.definition LIKE N'%OPENQUERY([[]%'
              OR m.definition LIKE N'%OPENQUERY ([[]%'              THEN N'OPENQUERY on a literal name' END
FROM sys.sql_modules AS m
JOIN sys.objects AS o ON o.object_id = m.object_id
JOIN sys.schemas AS s ON s.schema_id = o.schema_id
WHERE s.name + N'.' + o.name NOT IN (N'dbo.fnPriorityLinkRefusal')
  AND (   m.definition LIKE N'%31.168.173.93%'
       OR m.definition LIKE N'%PRIORITY[_]TEST%'
       OR m.definition LIKE N'%].amaba.%'
       OR m.definition LIKE N'%].[[]amaba].%'
       OR m.definition LIKE N'%OPENQUERY([[]%'
       OR m.definition LIKE N'%OPENQUERY ([[]%');

INSERT INTO @Out (Test, Expected, Actual, Result)
SELECT N'4 no module names a server', N'none',
       ISNULL((SELECT STRING_AGG(Module + N' (' + Why + N')', N', ') FROM @Hard), N'none'),
       IIF(EXISTS (SELECT 1 FROM @Hard), N'FAIL', N'PASS');

SELECT DB_NAME() AS DatabaseName, Test, Expected, Actual, Result FROM @Out ORDER BY Seq;
