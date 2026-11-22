/*
    dbo.UpsertCustomerInvoiceDocument                                                   MBA-998
    ---------------------------------------------------------------------------------------------
    Records one attempt of the on-prem sync (ReportArchiveSync) to copy an invoice PDF to S3, in
    dbo.CustomerInvoiceDocument. Called once per invoice per attempt, and only AFTER the blob is in
    S3 for @Outcome = 1, so the portal can never show an icon that opens nothing.

    Parameters
      @IV             INT            (required) INVOICES.IV
      @InvoiceNumber  NVARCHAR(32)   (required) INVOICES.IVNUM
      @ExtFileNum     INT            (required) EXTFILES.EXTFILENUM tried
      @SourcePath     NVARCHAR(400)  (required) EXTFILES.EXTFILENAME
      @Outcome        TINYINT        (required) 1 uploaded, 2 no file, 3 ambiguous, 4 refused path
      @Detail         NVARCHAR(400)  = NULL     why, for 2-4
      @StorageKey     NVARCHAR(400)  = NULL     required for 1
      @FileHash       BINARY(32)     = NULL
      @FileSize       BIGINT         = NULL

    A failed attempt (2-4) keeps the StorageKey, hash and size of an earlier success: the PDF that
    was served stays served, and Outcome / Detail / AttemptedAt say what went wrong since.

    Idempotent: one row per IV, updated in place. The caller is a service, not a person, so there is
    no @Apply dry run here; the service has its own DryRun, which skips this call entirely.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.UpsertCustomerInvoiceDocument
    @IV            INT,
    @InvoiceNumber NVARCHAR(32),
    @ExtFileNum    INT,
    @SourcePath    NVARCHAR(400),
    @Outcome       TINYINT,
    @Detail        NVARCHAR(400) = NULL,
    @StorageKey    NVARCHAR(400) = NULL,
    @FileHash      BINARY(32)    = NULL,
    @FileSize      BIGINT        = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @IV IS NULL OR NULLIF(@InvoiceNumber, N'') IS NULL OR @ExtFileNum IS NULL
       OR NULLIF(@SourcePath, N'') IS NULL OR @Outcome IS NULL
        THROW 51111, N'UpsertCustomerInvoiceDocument: IV, InvoiceNumber, ExtFileNum, SourcePath and Outcome are required.', 1;

    IF @Outcome NOT IN (1, 2, 3, 4)
        THROW 51112, N'UpsertCustomerInvoiceDocument: Outcome must be 1 (uploaded), 2 (no file), 3 (ambiguous) or 4 (refused path).', 1;

    IF @Outcome = 1 AND NULLIF(@StorageKey, N'') IS NULL
        THROW 51113, N'UpsertCustomerInvoiceDocument: an uploaded document needs its StorageKey.', 1;

    DECLARE @IsUpload BIT = IIF(@Outcome = 1, 1, 0);

    UPDATE dbo.CustomerInvoiceDocument
    SET InvoiceNumber = @InvoiceNumber,
        ExtFileNum    = @ExtFileNum,
        SourcePath    = @SourcePath,
        Outcome       = @Outcome,
        Detail        = IIF(@IsUpload = 1, NULL, @Detail),
        StorageKey    = IIF(@IsUpload = 1, @StorageKey, StorageKey),
        FileHash      = IIF(@IsUpload = 1, @FileHash, FileHash),
        FileSize      = IIF(@IsUpload = 1, @FileSize, FileSize),
        AttemptedAt   = SYSUTCDATETIME(),
        UploadedAt    = IIF(@IsUpload = 1, SYSUTCDATETIME(), UploadedAt)
    WHERE IV = @IV;

    IF @@ROWCOUNT = 0
        INSERT INTO dbo.CustomerInvoiceDocument
            (IV, InvoiceNumber, ExtFileNum, SourcePath, Outcome, Detail, StorageKey, FileHash, FileSize, UploadedAt)
        VALUES
            (@IV, @InvoiceNumber, @ExtFileNum, @SourcePath, @Outcome,
             IIF(@IsUpload = 1, NULL, @Detail),
             IIF(@IsUpload = 1, @StorageKey, NULL),
             IIF(@IsUpload = 1, @FileHash, NULL),
             IIF(@IsUpload = 1, @FileSize, NULL),
             IIF(@IsUpload = 1, SYSUTCDATETIME(), NULL));
END
GO
