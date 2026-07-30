-- Empty schema shell used when no CalibratorProd backup is provided.
-- Creates the database and the three schemas the sync pipeline uses (stg / dbo / etl).
-- Full tables/procedures come either from a restored .bak or from schema scripts you add later.
SET NOCOUNT ON;

IF DB_ID('CalibratorTest') IS NULL
BEGIN
    PRINT 'Creating CalibratorTest...';
    CREATE DATABASE CalibratorTest;
END
GO

ALTER DATABASE CalibratorTest SET RECOVERY SIMPLE;   -- test DB: no TLog backups
GO

USE CalibratorTest;
GO

IF SCHEMA_ID('stg') IS NULL EXEC('CREATE SCHEMA stg');
IF SCHEMA_ID('etl') IS NULL EXEC('CREATE SCHEMA etl');
GO

PRINT 'CalibratorTest shell ready (schemas: dbo, stg, etl). Add tables via a .bak or schema scripts.';
GO
