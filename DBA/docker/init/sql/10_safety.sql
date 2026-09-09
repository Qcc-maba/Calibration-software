-- Cross-environment safety toggles (MIGRATION-AND-FIX-PLAN.md 3.1).
-- A fresh container has no SQL Agent jobs, no Database Mail and no linked servers, so the
-- job/mail/linked-server risks are absent by construction. What still matters:
--   * a measured login (calib_test) instead of app_prod's db_owner habit  [also the init marker]
--   * scrambling any real customer e-mails if production data was restored
--   * defensively removing any linked server that a restore might have carried
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- 1) Measured login (NOT sysadmin / db_owner). Serves as the "already initialised" marker.
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = 'calib_test')
BEGIN
    DECLARE @pwd sysname = N'$(CALIB_TEST_PASSWORD)';
    EXEC('CREATE LOGIN calib_test WITH PASSWORD = ''' + @pwd + N''', CHECK_POLICY = OFF;');
    PRINT 'Created login calib_test.';
END
GO

IF DB_ID('CalibratorTest') IS NOT NULL
BEGIN
    USE CalibratorTest;

    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'calib_test')
    BEGIN
        CREATE USER calib_test FOR LOGIN calib_test;
        ALTER ROLE db_datareader ADD MEMBER calib_test;
        ALTER ROLE db_datawriter ADD MEMBER calib_test;
        GRANT EXECUTE TO calib_test;   -- run procedures, but not db_owner
        PRINT 'calib_test granted datareader + datawriter + execute (not db_owner).';
    END

    -- 2) Scramble any real e-mail addresses in dbo.Users (only if the table/columns exist).
    IF OBJECT_ID('dbo.Users') IS NOT NULL
    BEGIN
        DECLARE @col sysname, @sql nvarchar(max);
        DECLARE c CURSOR LOCAL FAST_FORWARD FOR
            SELECT c.name
            FROM sys.columns c
            WHERE c.object_id = OBJECT_ID('dbo.Users')
              AND c.name LIKE '%mail%'
              AND c.system_type_id IN (167, 175, 231, 239); -- (n)varchar/(n)char
        OPEN c; FETCH NEXT FROM c INTO @col;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @sql = N'UPDATE dbo.Users SET ' + QUOTENAME(@col) +
                       N' = CONCAT(''user'', CAST(ABS(CHECKSUM(NEWID())) AS varchar(12)), ''@example.test'')' +
                       N' WHERE ' + QUOTENAME(@col) + N' IS NOT NULL AND ' + QUOTENAME(@col) + N' <> '''';';
            EXEC (@sql);
            PRINT 'Scrambled dbo.Users.' + @col;
            FETCH NEXT FROM c INTO @col;
        END
        CLOSE c; DEALLOCATE c;
    END
END
GO

-- 3) Defensive: drop any linked server a restore might have carried (a container should have none).
DECLARE @srv sysname;
DECLARE ls CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.servers WHERE is_linked = 1;
OPEN ls; FETCH NEXT FROM ls INTO @srv;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC sp_dropserver @server = @srv, @droplogins = 'droplogins';
    PRINT 'Dropped linked server: ' + @srv;
    FETCH NEXT FROM ls INTO @srv;
END
CLOSE ls; DEALLOCATE ls;
GO
