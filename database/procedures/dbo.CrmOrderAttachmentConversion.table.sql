/*
    dbo.CrmOrderAttachmentConversion                                                    MBA-930
    ---------------------------------------------------------------------------------------------
    One row per Priority order attachment (ORD, EXTFILENUM) that the on-prem sync
    (ReportArchiveSync) has tried to convert to PDF and copy to S3. The parts it produced are in
    dbo.CrmOrderAttachmentPart.

    Why a table of its own and not columns on dbo.CrmOrderAttachments: a full refresh of that
    cache TRUNCATEs it (dbo.RefreshOrderAttachmentsCache), which would forget every conversion and
    convert all ~3,000 files again every night.

    Why the PDFs are made ahead of time and not on request: the web app runs on Vercel, which
    cannot reach Priority's share (\\maba-priority on PROD, \\priority-test on STAGE). Same reason
    and same shape as dbo.CustomerInvoiceDocument (MBA-998).

    Columns
      ORD, EXTFILENUM   The attachment's key in Priority. EXTFILENUM, not LINE: see
                        dbo.CrmOrderAttachments.table.sql.
      SourcePath        EXTFILES.EXTFILENAME at the time of the attempt. A different path in the
                        cache means Priority re-attached the file, and it is converted again.
      Outcome           The LAST attempt: 1 converted (each part carries its own error, if any),
                        2 the file could not be read (locked, access denied, network error;
                        retried after hours), 3 the file does not exist (retried after days).
      Detail            Why, for 2-3.
      MergedStorageKey  S3 key of all parts as one PDF. When only one part converted, that part's
                        own key. NULL when nothing converted.
      AttemptedAt       UTC of the last attempt. ConvertedAt: UTC of the last outcome 1.

    A failed attempt (2-3) keeps the parts and MergedStorageKey of an earlier success, so a PDF
    that was served once stays served (dbo.SaveOrderAttachmentConversion).

    Idempotent: creates the table only when it is missing.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.CrmOrderAttachmentConversion', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CrmOrderAttachmentConversion
    (
        ORD              INT            NOT NULL,
        EXTFILENUM       INT            NOT NULL,
        SourcePath       NVARCHAR(200)  NOT NULL,
        Outcome          TINYINT        NOT NULL,
        Detail           NVARCHAR(400)  NULL,
        MergedStorageKey NVARCHAR(400)  NULL,
        AttemptedAt      DATETIME2(3)   NOT NULL CONSTRAINT DF_CrmOrderAttachmentConversion_AttemptedAt DEFAULT (SYSUTCDATETIME()),
        ConvertedAt      DATETIME2(3)   NULL,
        CONSTRAINT PK_CrmOrderAttachmentConversion PRIMARY KEY CLUSTERED (ORD, EXTFILENUM),
        CONSTRAINT CK_CrmOrderAttachmentConversion_Outcome CHECK (Outcome IN (1, 2, 3))
    );
END
GO
