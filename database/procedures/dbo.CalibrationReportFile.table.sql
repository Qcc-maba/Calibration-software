/*
    dbo.CalibrationReportFile  --  index of every calibration report PDF available for a device.

    Two producers write here:

      SourceKind 1 — the app.      The calibration wizard renders the PDF in the browser and
                                   uploads it to S3 at orders/{OrderNumber}/reports/{ItemId}/report.pdf
      SourceKind 2 — Tomax archive. Priority's own print engine wrote the PDF to
                                   \\maba-priority\priority\Tomax\Archives\DOC_Q\Out\{year}\
                                   and the on-prem sync service mirrored it into S3.
      SourceKind 3 — manual.       A coordinator attached an existing report by hand.

    Why this table exists at all: today the UI decides whether to show the report icon by issuing
    one S3 ListObjectsV2 + presign PER DEVICE CARD (see ValidatorDeviceCard). A screen with 30
    devices costs 30 S3 round-trips just to render icons. This table is the authoritative index,
    so the icon comes from the same query that already loads the devices.

    ------------------------------------------------------------------------------------------
    Variant vs UpdateLevel — the two are NOT the same thing, and collapsing them loses reports.
    ------------------------------------------------------------------------------------------
    The archive encodes both in the file name, e.g. 2601089-1b.pdf / 2412012-77u2.PDF:

      Variant     'a','b','c'...  A SEPARATE REPORT, issued to split measurement domains
                                  (הפרדת תחומים). a, b and c all remain valid at the same time.
                                  Measured: 202 devices carry more than one; the record is 12.

      UpdateLevel  u1, u2, ...    A RE-ISSUE of one report — a recalibration, or a calibration
                                  after adjustment (כיול אחרי כיוון). The HIGHEST number wins and
                                  supersedes the lower ones. UpdateLevel 0 is the original.

    So a device's current report set = one row per Variant, each at its max UpdateLevel.
    dbo.GetCalibrationReportFiles applies exactly that rule.

    ------------------------------------------------------------------------------------------
    CoversFrom / CoversTo — consolidated reports
    ------------------------------------------------------------------------------------------
    One PDF can hold the results of several instruments (דוח מרוכז), named 2601001-63-75.pdf,
    and in that case the individual per-index files do not exist at all. Measured: 689 such files
    across 2024-2026, averaging 7.7 instruments, the largest covering 151.

    Such a file is uploaded to S3 ONCE and gets one row here per covered device, all sharing the
    same StorageKey. Never copy the blob per device.

    All timestamps are UTC (SYSUTCDATETIME) to match dbo.OrderApprovalRequest and dbo.CustomerPortalOtp.
*/
/*
    QUOTED_IDENTIFIER / ANSI_NULLS must be ON: this table has a PERSISTED computed column and
    two filtered indexes, and SQL Server refuses to create either under the OFF setting that
    sqlcmd defaults to. The same applies to every procedure that WRITES here — a procedure
    carries the SET options it was created with, so one created under OFF fails at runtime with
    "UPDATE failed because the following SET options have incorrect settings". Keep these two
    lines at the top of this file and of dbo.UpsertCalibrationReportFile.sql.
*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.CalibrationReportFile', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CalibrationReportFile
    (
        CalibrationReportFileId BIGINT        IDENTITY(1, 1) NOT NULL,
        OrderDetailsItemId      INT           NOT NULL,

        /* As stored on the item: '2603086\4'. The archive spells the same number '2603086-4'. */
        MbaReportNumber         NVARCHAR(50)  NOT NULL,

        SourceKind              TINYINT       NOT NULL,

        /* '' for the plain report; 'a', 'b', 'c'... for a domain-split sibling. Never NULL, so
           the unique index below treats "no variant" as a real value rather than a gap. */
        Variant                 NVARCHAR(10)  NOT NULL CONSTRAINT DF_CalibrationReportFile_Variant DEFAULT (N''),

        /* 0 = original, 1 = u1, 2 = u2 ... Highest wins within a Variant. */
        UpdateLevel             TINYINT       NOT NULL CONSTRAINT DF_CalibrationReportFile_UpdateLevel DEFAULT (0),

        /* Report indices this PDF covers. Equal for an ordinary single-device report. */
        CoversFrom              INT           NOT NULL,
        CoversTo                INT           NOT NULL,
        IsConsolidated          AS (CASE WHEN CoversTo > CoversFrom THEN CONVERT(BIT, 1) ELSE CONVERT(BIT, 0) END) PERSISTED,

        /* S3 object key. Shared by every device of a consolidated report. */
        StorageKey              NVARCHAR(400) NOT NULL,

        /* UNC path the file was mirrored from — kept for audit, never read at runtime. */
        ArchivePath             NVARCHAR(400) NULL,

        /* SHA-256 of the blob: lets the sync skip re-uploading an unchanged file. */
        FileHash                BINARY(32)    NULL,
        FileSize                BIGINT        NULL,
        ArchiveModifiedAt       DATETIME2(3)  NULL,

        SyncedAt                DATETIME2(3)  NOT NULL CONSTRAINT DF_CalibrationReportFile_SyncedAt DEFAULT (SYSUTCDATETIME()),
        SyncedBy                NVARCHAR(100) NULL,   /* service name, or the user e-mail for SourceKind 3 */

        IsDeleted               BIT           NOT NULL CONSTRAINT DF_CalibrationReportFile_IsDeleted DEFAULT (0),

        /* NO foreign key to dbo.OrderDetailsItems — deliberately. Its primary key is COMPOSITE,
           PK_OrderDetailsItems (OrderDetailId, OrderDetailsItemId), so OrderDetailsItemId alone
           is not a candidate key and SQL Server rejects the reference (Msg 1776).

           Keying on OrderDetailsItemId alone is nevertheless the right call here, because it is
           already the app-wide identity for a device: the existing S3 layout is
           orders/{OrderNumber}/reports/{OrderDetailsItemId}/report.pdf, and the device mutations
           (assignValidatedStatus, assignOrderItemStatus) address items by that id only.

           Caveat, verified 2026-08-23: the column is unique on PROD (7,920 rows / 7,920 distinct)
           but NOT on STAGE, where OrderDetailsItemId 112 appears twice under OrderDetailId 54 and
           163 — same serial, same report number, both IsDeleted = 0. If that is not merely test
           residue, the EXISTING S3 report path is already ambiguous for such a pair, independently
           of this table. Worth a look; it is not introduced by this feature. */
        CONSTRAINT PK_CalibrationReportFile PRIMARY KEY CLUSTERED (CalibrationReportFileId),
        CONSTRAINT CK_CalibrationReportFile_SourceKind
            CHECK (SourceKind IN (1, 2, 3)),
        CONSTRAINT CK_CalibrationReportFile_Covers
            CHECK (CoversTo >= CoversFrom)
    );

    /* One row per (device, variant, update level). Filtered so a soft-deleted row does not block
       a re-sync of the same file. */
    CREATE UNIQUE NONCLUSTERED INDEX UX_CalibrationReportFile_Item_Variant_Update
        ON dbo.CalibrationReportFile (OrderDetailsItemId, Variant, UpdateLevel)
        WHERE IsDeleted = 0;

    /* The read path: "which reports does this device have". */
    CREATE NONCLUSTERED INDEX IX_CalibrationReportFile_Item
        ON dbo.CalibrationReportFile (OrderDetailsItemId)
        INCLUDE (Variant, UpdateLevel, StorageKey, SourceKind, IsConsolidated)
        WHERE IsDeleted = 0;

    /* "has this blob already been mirrored" — the sync checks before uploading, and a
       consolidated file is looked up here to reuse its key across all covered devices. */
    CREATE NONCLUSTERED INDEX IX_CalibrationReportFile_StorageKey
        ON dbo.CalibrationReportFile (StorageKey);
END
GO
