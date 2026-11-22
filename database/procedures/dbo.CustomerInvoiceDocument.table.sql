/*
    dbo.CustomerInvoiceDocument                                                         MBA-998
    ---------------------------------------------------------------------------------------------
    One row per Priority invoice (INVOICES.IV) whose printed PDF the on-prem sync has tried to
    copy to S3. The portal's invoice screen shows the document icon only when StorageKey is set,
    and serves the PDF from S3 with a short-lived signed link - never from Priority's share, which
    Vercel cannot reach.

    Who writes it: ReportArchiveSync (Systems/ReportArchiveSync), through
    dbo.UpsertCustomerInvoiceDocument, after the blob is in S3. What it copies comes from
    dbo.GetInvoiceDocumentsToSync.

    Where the PDF comes from: Priority's attachment table EXTFILES, TYPE = 'I' (invoice
    attachments - measured 2026-11-22, every invoice type C/T/F/R/Q files them under 'I'), a
    path relative to the Priority root such as ..\..\system\mail\26\9\0\y\9bb7a8\<name>.pdf.
    PROD has 19,838 such invoices, exactly one PDF each.

    Columns
      IV             Priority's internal invoice id. The key: IVNUM is the printed number.
      InvoiceNumber  INVOICES.IVNUM, for people reading the table.
      ExtFileNum     EXTFILES.EXTFILENUM of the attachment last tried. A different number in
                     Priority means a re-issued attachment, and the sync tries again.
      SourcePath     EXTFILES.EXTFILENAME as Priority stores it (the Hebrew in the file name is
                     reversed; only the directory is used to find the file).
      Outcome        The LAST attempt: 1 uploaded, 2 no PDF in the directory, 3 several PDFs and
                     none matches the recorded size, 4 a path the sync refuses to follow,
                     5 the directory or file could not be read (access denied, locked, network
                     error on that folder). 5 is retried after hours, 2-3 after days, 4 only when
                     the attachment changes.
      Detail         Why, for outcomes 2-5.
      StorageKey     S3 key, invoices/<IV>.pdf. Kept from the last success even when a later
                     attempt fails, so a PDF that was once served stays served.
      FileHash       SHA-256 of the uploaded file. FileSize: its bytes.
      AttemptedAt    UTC of the last attempt. Retries: 2-3 after days, 5 after hours, 4 only when
                     the attachment changes (dbo.GetInvoiceDocumentsToSync).
      UploadedAt     UTC of the last successful upload.

    Idempotent: creates the table only when it is missing, and widens the Outcome check to
    include 5 on a table created before that outcome existed (STAGE, 2026-11-22). Run it before
    dbo.UpsertCustomerInvoiceDocument: that procedure accepts outcome 5, which the old check refuses.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.CustomerInvoiceDocument', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CustomerInvoiceDocument
    (
        IV            INT            NOT NULL,
        InvoiceNumber NVARCHAR(32)   NOT NULL,
        ExtFileNum    INT            NOT NULL,
        SourcePath    NVARCHAR(400)  NOT NULL,
        Outcome       TINYINT        NOT NULL,
        Detail        NVARCHAR(400)  NULL,
        StorageKey    NVARCHAR(400)  NULL,
        FileHash      BINARY(32)     NULL,
        FileSize      BIGINT         NULL,
        AttemptedAt   DATETIME2(3)   NOT NULL CONSTRAINT DF_CustomerInvoiceDocument_AttemptedAt DEFAULT (SYSUTCDATETIME()),
        UploadedAt    DATETIME2(3)   NULL,
        CONSTRAINT PK_CustomerInvoiceDocument PRIMARY KEY CLUSTERED (IV),
        CONSTRAINT CK_CustomerInvoiceDocument_Outcome CHECK (Outcome IN (1, 2, 3, 4, 5))
    );
END
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = N'CK_CustomerInvoiceDocument_Outcome'
             AND parent_object_id = OBJECT_ID(N'dbo.CustomerInvoiceDocument')
             AND definition NOT LIKE N'%5%')
BEGIN
    ALTER TABLE dbo.CustomerInvoiceDocument DROP CONSTRAINT CK_CustomerInvoiceDocument_Outcome;
    ALTER TABLE dbo.CustomerInvoiceDocument
        ADD CONSTRAINT CK_CustomerInvoiceDocument_Outcome CHECK (Outcome IN (1, 2, 3, 4, 5));
END
GO
