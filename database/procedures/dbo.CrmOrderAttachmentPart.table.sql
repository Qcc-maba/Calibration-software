/*
    dbo.CrmOrderAttachmentPart                                                          MBA-930
    ---------------------------------------------------------------------------------------------
    One row per openable piece of a Priority order attachment, written by ReportArchiveSync
    through dbo.SaveOrderAttachmentConversion. A .msg (99% of order attachments) is the mail body
    plus each real document inside it; any other file is one part.

    A part that could not be produced is a row too, with Error set and no StorageKey. AC #6 of
    MBA-930: the calibrator must see that a document exists even when it cannot be opened.

    Columns
      ORD, EXTFILENUM   The attachment (dbo.CrmOrderAttachmentConversion).
      PartId            "body" for the mail itself, otherwise a hash of the enclosed file's name
                        (Hebrew names cannot be S3 key segments), "-2", "-3" for duplicates.
      Seq               Display order: body first, then documents as the mail lists them.
      Name              What the calibrator sees: the mail subject or the enclosed file's name.
      Kind              MailBody | Document | Error.
      Error             Why the part could not be produced. NULL when it was.
      StorageKey        S3 key, order-attachments/<ORD>/<EXTFILENUM>/<PartId>.pdf.
      FileSize          Bytes of the PDF.

    Idempotent: creates the table only when it is missing.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.CrmOrderAttachmentPart', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CrmOrderAttachmentPart
    (
        ORD         INT            NOT NULL,
        EXTFILENUM  INT            NOT NULL,
        PartId      VARCHAR(40)    NOT NULL,
        Seq         INT            NOT NULL,
        Name        NVARCHAR(400)  NOT NULL,
        Kind        VARCHAR(16)    NOT NULL,
        Error       NVARCHAR(400)  NULL,
        StorageKey  NVARCHAR(400)  NULL,
        FileSize    BIGINT         NULL,
        CONSTRAINT PK_CrmOrderAttachmentPart PRIMARY KEY CLUSTERED (ORD, EXTFILENUM, PartId),
        CONSTRAINT CK_CrmOrderAttachmentPart_Kind CHECK (Kind IN ('MailBody', 'Document', 'Error')),
        /* Exactly one of the two: a part either opens or says why it does not. */
        CONSTRAINT CK_CrmOrderAttachmentPart_KeyOrError CHECK (
            (StorageKey IS NOT NULL AND Error IS NULL AND Kind <> 'Error')
         OR (StorageKey IS NULL AND Error IS NOT NULL AND Kind = 'Error'))
    );
END
GO
