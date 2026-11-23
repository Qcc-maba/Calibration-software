/*
    dbo.SaveOrderAttachmentConversion                                                   MBA-930
    ---------------------------------------------------------------------------------------------
    Records one attempt of ReportArchiveSync to convert a Priority order attachment, in
    dbo.CrmOrderAttachmentConversion, and for a successful one replaces its parts in
    dbo.CrmOrderAttachmentPart. Called only AFTER every PDF is in S3, so the screen can never
    offer a part that opens nothing.

    Parameters
      @ORD, @EXTFILENUM  INT            (required) the attachment
      @SourcePath        NVARCHAR(200)  (required) the path converted, as Priority stores it
      @Outcome           TINYINT        (required) 1 converted, 2 temporary failure, 3 not found
      @Detail            NVARCHAR(400)  = NULL     why, for 2-3
      @MergedStorageKey  NVARCHAR(400)  = NULL     for 1
      @PartsJson         NVARCHAR(MAX)  = NULL     for 1, required: a JSON array of
                         {"partId","seq","name","kind","error","storageKey","fileSize"}

    Outcome 1 replaces the parts as a whole, in one transaction. Outcomes 2-3 keep the parts and
    MergedStorageKey of an earlier success, so a PDF that was served once stays served.

    Idempotent: one row per attachment, updated in place. The caller is a service, so there is no
    @Apply dry run here; ReportArchiveSync has its own DryRun, which skips this call entirely.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.SaveOrderAttachmentConversion
    @ORD              INT,
    @EXTFILENUM       INT,
    @SourcePath       NVARCHAR(200),
    @Outcome          TINYINT,
    @Detail           NVARCHAR(400) = NULL,
    @MergedStorageKey NVARCHAR(400) = NULL,
    @PartsJson        NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ORD IS NULL OR @EXTFILENUM IS NULL OR NULLIF(@SourcePath, N'') IS NULL OR @Outcome IS NULL
        THROW 51131, N'SaveOrderAttachmentConversion: ORD, EXTFILENUM, SourcePath and Outcome are required.', 1;

    IF @Outcome NOT IN (1, 2, 3)
        THROW 51132, N'SaveOrderAttachmentConversion: Outcome must be 1 (converted), 2 (unreadable) or 3 (not found).', 1;

    IF @Outcome = 1 AND (@PartsJson IS NULL OR ISJSON(@PartsJson) = 0)
        THROW 51133, N'SaveOrderAttachmentConversion: a converted attachment needs its parts as a JSON array.', 1;

    DECLARE @Parts TABLE
    (
        PartId     VARCHAR(40)   NOT NULL PRIMARY KEY,
        Seq        INT           NOT NULL,
        Name       NVARCHAR(400) NOT NULL,
        Kind       VARCHAR(16)   NOT NULL,
        Error      NVARCHAR(400) NULL,
        StorageKey NVARCHAR(400) NULL,
        FileSize   BIGINT        NULL
    );

    IF @Outcome = 1
    BEGIN
        INSERT INTO @Parts (PartId, Seq, Name, Kind, Error, StorageKey, FileSize)
        SELECT j.partId, j.seq, LEFT(j.name, 400), j.kind, LEFT(j.error, 400), j.storageKey, j.fileSize
        FROM OPENJSON(@PartsJson)
             WITH (partId     VARCHAR(40)    '$.partId',
                   seq        INT            '$.seq',
                   name       NVARCHAR(1000) '$.name',
                   kind       VARCHAR(16)    '$.kind',
                   error      NVARCHAR(1000) '$.error',
                   storageKey NVARCHAR(400)  '$.storageKey',
                   fileSize   BIGINT         '$.fileSize') AS j;

        IF NOT EXISTS (SELECT 1 FROM @Parts)
            THROW 51134, N'SaveOrderAttachmentConversion: a converted attachment has at least one part (an error part counts).', 1;
    END

    DECLARE @IsConverted BIT = IIF(@Outcome = 1, 1, 0);

    BEGIN TRAN;

    UPDATE dbo.CrmOrderAttachmentConversion
    SET SourcePath       = @SourcePath,
        Outcome          = @Outcome,
        Detail           = IIF(@IsConverted = 1, NULL, @Detail),
        MergedStorageKey = IIF(@IsConverted = 1, @MergedStorageKey, MergedStorageKey),
        AttemptedAt      = SYSUTCDATETIME(),
        ConvertedAt      = IIF(@IsConverted = 1, SYSUTCDATETIME(), ConvertedAt)
    WHERE ORD = @ORD AND EXTFILENUM = @EXTFILENUM;

    IF @@ROWCOUNT = 0
        INSERT INTO dbo.CrmOrderAttachmentConversion
            (ORD, EXTFILENUM, SourcePath, Outcome, Detail, MergedStorageKey, ConvertedAt)
        VALUES
            (@ORD, @EXTFILENUM, @SourcePath, @Outcome,
             IIF(@IsConverted = 1, NULL, @Detail),
             IIF(@IsConverted = 1, @MergedStorageKey, NULL),
             IIF(@IsConverted = 1, SYSUTCDATETIME(), NULL));

    IF @IsConverted = 1
    BEGIN
        DELETE FROM dbo.CrmOrderAttachmentPart WHERE ORD = @ORD AND EXTFILENUM = @EXTFILENUM;

        INSERT INTO dbo.CrmOrderAttachmentPart
            (ORD, EXTFILENUM, PartId, Seq, Name, Kind, Error, StorageKey, FileSize)
        SELECT @ORD, @EXTFILENUM, PartId, Seq, Name, Kind, Error, StorageKey, FileSize
        FROM @Parts;
    END

    COMMIT;
END
GO
