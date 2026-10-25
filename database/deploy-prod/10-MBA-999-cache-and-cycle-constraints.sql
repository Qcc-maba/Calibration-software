/*
    MBA-999 - the rest of the 31/08 constraint gap. PROD only; on STAGE every guard is already met
    and the script changes nothing.

    WHY
    ---
    01-tranche-A-schema.sql created its new tables from their columns and primary key alone, so the
    defaults, checks, foreign keys and secondary indexes they have on STAGE never reached PROD.
    09-hotfix-2026-10-25-portal-and-notes-constraints.sql fixed the four tables whose writers relied on
    a default (validator notes and portal requests failed on release day). This file closes the rest,
    which is everything database/Compare-Schema.ps1 reports outside the MBA-816 coefficient tables, the
    customer-status column and PROD's own etl.SyncRunLog.
    None of it is breaking today - the writers below pass every value themselves - but a missing
    default is a failure waiting for the next writer, and the indexes are what the lookups read.

      dbo.CrmDeviceDescription   (3,006 rows) RefreshedAt default, IX_..._Raw, IX_..._Desc
      dbo.CrmOrderAttachments    (2,328 rows) FetchedAt and IsPathTruncated defaults, IX_..._ORD
      dbo.OrderApprovalRequest   CreatedAt default (the one 09 left out)
      dbo.MeasurmentPointsToCalibrationCycles  FK to dbo.CalibrationCycles, ON DELETE CASCADE as on STAGE
                                 (52 rows, 0 orphans on 2026-10-25)

    Definitions match database/procedures/dbo.<Table>.table.sql. A default is detected by column, not by
    name, because STAGE's were created with system-generated names.

    Safe to re-run. One transaction, XACT_ABORT ON. The foreign key is checked first: if any point no
    longer has its cycle, the script stops before changing anything and says how many.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET XACT_ABORT ON;
GO


/* PROD-only: refuse to run anywhere else. STAGE (Calibrator) and PROD (CalibratorProd) share one
   server, so an SSMS tab can be on either; on STAGE every guard below is already met, the script
   changes nothing and still prints its check row - which looks exactly like success. */
IF DB_NAME() <> N'CalibratorProd'
BEGIN
    /* RAISERROR, not THROW: SSMS goes on to the next batch after an error, so the rest of the file is
       switched off with NOEXEC. Run SET NOEXEC OFF; afterwards, or open a new tab, before anything else. */
    DECLARE @WrongDb NVARCHAR(200) = CONCAT(N'Stopped, nothing changed: this script is for CalibratorProd, but the current database is ', DB_NAME(), N'. Run SET NOEXEC OFF; before anything else in this tab.');
    RAISERROR(@WrongDb, 16, 1);
    SET NOEXEC ON;
END;
GO

DECLARE @Orphans INT =
(
    SELECT COUNT(*)
    FROM dbo.MeasurmentPointsToCalibrationCycles AS m
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CalibrationCycles AS c
                      WHERE c.OrderDetailsItemId = m.OrderDetailsItemId
                        AND c.CalibrationCycleStartDate = m.CalibrationCycleStartDate)
);

IF @Orphans > 0 AND OBJECT_ID('dbo.FK_MeasurmentPointsToCalibrationCycles_CalibrationCycles', 'F') IS NULL
BEGIN
    DECLARE @Msg NVARCHAR(200) = CONCAT(N'Stopped, nothing changed: ', @Orphans,
        N' MeasurmentPointsToCalibrationCycles rows have no matching CalibrationCycles row.');
    THROW 50999, @Msg, 1;
END;

BEGIN TRANSACTION;

/* ---- dbo.CrmDeviceDescription ------------------------------------------------------------------ */
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints
               WHERE parent_object_id = OBJECT_ID('dbo.CrmDeviceDescription')
                 AND parent_column_id = COLUMNPROPERTY(OBJECT_ID('dbo.CrmDeviceDescription'), 'RefreshedAt', 'ColumnId'))
    ALTER TABLE dbo.CrmDeviceDescription
        ADD CONSTRAINT DF_CrmDeviceDescription_RefreshedAt DEFAULT (SYSUTCDATETIME()) FOR RefreshedAt;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CrmDeviceDescription_Raw' AND object_id = OBJECT_ID('dbo.CrmDeviceDescription'))
    CREATE NONCLUSTERED INDEX IX_CrmDeviceDescription_Raw ON dbo.CrmDeviceDescription (DescriptionRaw);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CrmDeviceDescription_Desc' AND object_id = OBJECT_ID('dbo.CrmDeviceDescription'))
    CREATE NONCLUSTERED INDEX IX_CrmDeviceDescription_Desc ON dbo.CrmDeviceDescription (Description);

/* ---- dbo.CrmOrderAttachments ------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints
               WHERE parent_object_id = OBJECT_ID('dbo.CrmOrderAttachments')
                 AND parent_column_id = COLUMNPROPERTY(OBJECT_ID('dbo.CrmOrderAttachments'), 'IsPathTruncated', 'ColumnId'))
    ALTER TABLE dbo.CrmOrderAttachments
        ADD CONSTRAINT DF_CrmOrderAttachments_IsPathTruncated DEFAULT (0) FOR IsPathTruncated;
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints
               WHERE parent_object_id = OBJECT_ID('dbo.CrmOrderAttachments')
                 AND parent_column_id = COLUMNPROPERTY(OBJECT_ID('dbo.CrmOrderAttachments'), 'FetchedAt', 'ColumnId'))
    ALTER TABLE dbo.CrmOrderAttachments
        ADD CONSTRAINT DF_CrmOrderAttachments_FetchedAt DEFAULT (SYSUTCDATETIME()) FOR FetchedAt;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CrmOrderAttachments_ORD' AND object_id = OBJECT_ID('dbo.CrmOrderAttachments'))
    CREATE NONCLUSTERED INDEX IX_CrmOrderAttachments_ORD ON dbo.CrmOrderAttachments (ORD) INCLUDE (IsPathTruncated);

/* ---- dbo.OrderApprovalRequest: CreatedAt default --------------------------------------------- */
/* Left out of the 09 hotfix on purpose - dbo.CreateOrderApprovalRequest passes CreatedAt itself, so
   nothing failed - but the table file defines it, and the next writer should not have to know. */
IF OBJECT_ID('dbo.DF_OrderApprovalRequest_CreatedAt', 'D') IS NULL
   AND NOT EXISTS (SELECT 1 FROM sys.default_constraints
                   WHERE parent_object_id = OBJECT_ID('dbo.OrderApprovalRequest')
                     AND parent_column_id = COLUMNPROPERTY(OBJECT_ID('dbo.OrderApprovalRequest'), 'CreatedAt', 'ColumnId'))
    ALTER TABLE dbo.OrderApprovalRequest
        ADD CONSTRAINT DF_OrderApprovalRequest_CreatedAt DEFAULT (SYSUTCDATETIME()) FOR CreatedAt;

/* ---- dbo.MeasurmentPointsToCalibrationCycles ------------------------------------------------------ */
IF OBJECT_ID('dbo.FK_MeasurmentPointsToCalibrationCycles_CalibrationCycles', 'F') IS NULL
    ALTER TABLE dbo.MeasurmentPointsToCalibrationCycles WITH CHECK
        ADD CONSTRAINT FK_MeasurmentPointsToCalibrationCycles_CalibrationCycles
        FOREIGN KEY (OrderDetailsItemId, CalibrationCycleStartDate)
        REFERENCES dbo.CalibrationCycles (OrderDetailsItemId, CalibrationCycleStartDate)
        ON DELETE CASCADE;

COMMIT TRANSACTION;
GO

/* ---- Check: expect a single row reading 4 | 3 | 1 -------------------------------------------- */
SELECT
    (SELECT COUNT(*) FROM sys.default_constraints
     WHERE (parent_object_id = OBJECT_ID('dbo.CrmDeviceDescription')
            AND parent_column_id = COLUMNPROPERTY(OBJECT_ID('dbo.CrmDeviceDescription'), 'RefreshedAt', 'ColumnId'))
        OR (parent_object_id = OBJECT_ID('dbo.CrmOrderAttachments')
            AND parent_column_id IN (COLUMNPROPERTY(OBJECT_ID('dbo.CrmOrderAttachments'), 'IsPathTruncated', 'ColumnId'),
                                     COLUMNPROPERTY(OBJECT_ID('dbo.CrmOrderAttachments'), 'FetchedAt', 'ColumnId')))
        OR (parent_object_id = OBJECT_ID('dbo.OrderApprovalRequest')
            AND parent_column_id = COLUMNPROPERTY(OBJECT_ID('dbo.OrderApprovalRequest'), 'CreatedAt', 'ColumnId'))) AS defaults_expect_4,
    (SELECT COUNT(*) FROM sys.indexes
     WHERE name IN ('IX_CrmDeviceDescription_Raw', 'IX_CrmDeviceDescription_Desc', 'IX_CrmOrderAttachments_ORD')) AS indexes_expect_3,
    (SELECT COUNT(*) FROM sys.foreign_keys
     WHERE name = 'FK_MeasurmentPointsToCalibrationCycles_CalibrationCycles' AND is_not_trusted = 0) AS trusted_fk_expect_1;
GO
SET NOEXEC OFF;  -- harmless when the guard did not fire
GO
