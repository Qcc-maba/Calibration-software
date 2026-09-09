-- Restore a CalibratorProd backup as CalibratorTest, moving the data/log files into the
-- container's data dir. Logical file names are read from the backup so this works regardless
-- of how the .bak was produced. Pass the path with -v BAK="/backup/xxx.bak".
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @bak nvarchar(4000) = N'$(BAK)';
DECLARE @data nvarchar(4000) = N'/var/opt/mssql/data/';

-- Read the logical file names from the backup.
IF OBJECT_ID('tempdb..#fl') IS NOT NULL DROP TABLE #fl;
CREATE TABLE #fl (
    LogicalName nvarchar(128), PhysicalName nvarchar(260), [Type] char(1), FileGroupName nvarchar(128),
    Size numeric(20,0), MaxSize numeric(20,0), FileID bigint, CreateLSN numeric(25,0), DropLSN numeric(25,0),
    UniqueID uniqueidentifier, ReadOnlyLSN numeric(25,0), ReadWriteLSN numeric(25,0), BackupSizeInBytes bigint,
    SourceBlockSize int, FileGroupID int, LogGroupGUID uniqueidentifier, DifferentialBaseLSN numeric(25,0),
    DifferentialBaseGUID uniqueidentifier, IsReadOnly bit, IsPresent bit, TDEThumbprint varbinary(32),
    SnapshotUrl nvarchar(360)
);
INSERT INTO #fl EXEC('RESTORE FILELISTONLY FROM DISK = ''' + @bak + '''');

DECLARE @dataName nvarchar(128) = (SELECT TOP 1 LogicalName FROM #fl WHERE [Type] = 'D' ORDER BY FileID);
DECLARE @logName  nvarchar(128) = (SELECT TOP 1 LogicalName FROM #fl WHERE [Type] = 'L' ORDER BY FileID);

DECLARE @sql nvarchar(max) =
    N'RESTORE DATABASE CalibratorTest FROM DISK = ''' + @bak + N''' WITH REPLACE, RECOVERY, ' +
    N'MOVE ''' + @dataName + N''' TO ''' + @data + N'CalibratorTest.mdf'', ' +
    N'MOVE ''' + @logName  + N''' TO ''' + @data + N'CalibratorTest_log.ldf'', STATS = 5;';

PRINT @sql;
EXEC (@sql);

ALTER DATABASE CalibratorTest SET RECOVERY SIMPLE;
PRINT 'Restored CalibratorTest from backup.';
GO
