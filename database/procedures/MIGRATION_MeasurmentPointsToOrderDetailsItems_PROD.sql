-- =============================================
-- Migration:  dbo.MeasurmentPointsToOrderDetailsItems — bring PROD up to the STAGE shape
-- Jira:       calibration wizard / sensors.getCalibrationValuesForManyOrderDetailItems
--
-- WHY: dbo.GetCalibrationValuesForManyOrderDetailItems could be created on STAGE but not on PROD —
-- "Invalid column name 'SerialNumber' / 'MbaReportNumber' / 'Tolerance' / 'NominalValue'". Comparing
-- INFORMATION_SCHEMA on both servers, the PROD table has 19 columns and STAGE has 23; those four
-- are the entire difference, and PROD has nothing STAGE lacks. So PROD's schema is simply behind.
--
-- SAFETY: all four are NULLable with no default, which SQL Server adds as a metadata-only change —
-- no table rewrite, no long lock, no row touched. Existing rows read NULL, which is exactly what
-- the read procs already expect (they COALESCE these columns against OrderDetailsItems).
--
-- Idempotent: re-running does nothing.
-- =============================================
IF COL_LENGTH('dbo.MeasurmentPointsToOrderDetailsItems', 'Tolerance') IS NULL
    ALTER TABLE dbo.MeasurmentPointsToOrderDetailsItems ADD Tolerance DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.MeasurmentPointsToOrderDetailsItems', 'NominalValue') IS NULL
    ALTER TABLE dbo.MeasurmentPointsToOrderDetailsItems ADD NominalValue DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.MeasurmentPointsToOrderDetailsItems', 'SerialNumber') IS NULL
    ALTER TABLE dbo.MeasurmentPointsToOrderDetailsItems ADD SerialNumber NVARCHAR(100) NULL;
GO
IF COL_LENGTH('dbo.MeasurmentPointsToOrderDetailsItems', 'MbaReportNumber') IS NULL
    ALTER TABLE dbo.MeasurmentPointsToOrderDetailsItems ADD MbaReportNumber NVARCHAR(100) NULL;
GO

-- verify: expected 23 columns, and the four present
SELECT COUNT(*) AS total_columns,
       SUM(CASE WHEN COLUMN_NAME IN ('Tolerance','NominalValue','SerialNumber','MbaReportNumber') THEN 1 ELSE 0 END) AS the_four
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'MeasurmentPointsToOrderDetailsItems';
GO
