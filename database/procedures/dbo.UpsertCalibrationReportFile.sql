/*
    dbo.UpsertCalibrationReportFile
    -------------------------------
    Registers one report PDF against one device. Called by the on-prem sync service once per
    (device, variant, update level), and by the manual-link flow with @SourceKind = 3.

    Parameters:
      @OrderDetailsItemId INT           (required)
      @MbaReportNumber    NVARCHAR(50)  (required)  as stored on the item: '2603086\4'
      @SourceKind         TINYINT       (required)  1 app · 2 Tomax archive · 3 manual
      @StorageKey         NVARCHAR(400) (required)  S3 key
      @Variant            NVARCHAR(10)  = N''       '' | 'a' | 'b' ...
      @UpdateLevel        TINYINT       = 0         0 | 1 | 2 ...
      @CoversFrom         INT           = NULL      defaults to the index parsed from the caller
      @CoversTo           INT           = NULL      defaults to @CoversFrom
      @ArchivePath        NVARCHAR(400) = NULL
      @FileHash           BINARY(32)    = NULL
      @FileSize           BIGINT        = NULL
      @ArchiveModifiedAt  DATETIME2(3)  = NULL
      @SyncedBy           NVARCHAR(100) = NULL

    Returns the row id as CalibrationReportFileId.

    Idempotent: re-running for the same (device, variant, update level) updates the existing row
    instead of inserting a duplicate — the sync re-reads the archive every cycle and must not
    grow the table. When @FileHash matches what is already stored the row is left untouched
    apart from SyncedAt, so an unchanged file costs nothing.

    A consolidated report is registered once PER COVERED DEVICE with the SAME @StorageKey; the
    caller uploads the blob once. Do not invent a per-device key for it.
*/
/* Required: dbo.CalibrationReportFile has filtered indexes and a persisted computed column, and
   a procedure that writes to it must itself have been created with these options ON. */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.UpsertCalibrationReportFile
    @OrderDetailsItemId INT,
    @MbaReportNumber    NVARCHAR(50),
    @SourceKind         TINYINT,
    @StorageKey         NVARCHAR(400),
    @Variant            NVARCHAR(10)  = N'',
    @UpdateLevel        TINYINT       = 0,
    @CoversFrom         INT           = NULL,
    @CoversTo           INT           = NULL,
    @ArchivePath        NVARCHAR(400) = NULL,
    @FileHash           BINARY(32)    = NULL,
    @FileSize           BIGINT        = NULL,
    @ArchiveModifiedAt  DATETIME2(3)  = NULL,
    @SyncedBy           NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @OrderDetailsItemId IS NULL OR NULLIF(@MbaReportNumber, N'') IS NULL
        OR @SourceKind IS NULL OR NULLIF(@StorageKey, N'') IS NULL
        THROW 51100, 'UpsertCalibrationReportFile: OrderDetailsItemId, MbaReportNumber, SourceKind and StorageKey are all required.', 1;

    IF @SourceKind NOT IN (1, 2, 3)
        THROW 51101, 'UpsertCalibrationReportFile: SourceKind must be 1 (app), 2 (archive) or 3 (manual).', 1;

    SET @Variant = COALESCE(@Variant, N'');
    SET @UpdateLevel = COALESCE(@UpdateLevel, 0);

    /* Fall back to the index encoded in the report number ('2603086\4' -> 4) so an ordinary
       single-device report does not have to pass the range explicitly. */
    IF @CoversFrom IS NULL
        SET @CoversFrom = TRY_CONVERT(INT, RIGHT(@MbaReportNumber,
                                                 LEN(@MbaReportNumber) - COALESCE(NULLIF(CHARINDEX(N'\', @MbaReportNumber), 0),
                                                                                  NULLIF(CHARINDEX(N'/', @MbaReportNumber), 0),
                                                                                  LEN(@MbaReportNumber))));

    SET @CoversTo = COALESCE(@CoversTo, @CoversFrom);

    IF @CoversFrom IS NULL OR @CoversTo < @CoversFrom
        THROW 51102, 'UpsertCalibrationReportFile: could not determine a valid CoversFrom/CoversTo range.', 1;

    DECLARE @Id BIGINT;

    UPDATE dbo.CalibrationReportFile
    SET  MbaReportNumber   = @MbaReportNumber
        ,SourceKind        = @SourceKind
        ,StorageKey        = @StorageKey
        ,CoversFrom        = @CoversFrom
        ,CoversTo          = @CoversTo
        ,ArchivePath       = COALESCE(@ArchivePath, ArchivePath)
        ,FileHash          = COALESCE(@FileHash, FileHash)
        ,FileSize          = COALESCE(@FileSize, FileSize)
        ,ArchiveModifiedAt = COALESCE(@ArchiveModifiedAt, ArchiveModifiedAt)
        ,SyncedAt          = SYSUTCDATETIME()
        ,SyncedBy          = COALESCE(@SyncedBy, SyncedBy)
        ,@Id               = CalibrationReportFileId
    WHERE OrderDetailsItemId = @OrderDetailsItemId
      AND Variant            = @Variant
      AND UpdateLevel        = @UpdateLevel
      AND IsDeleted          = 0;

    IF @Id IS NULL
    BEGIN
        INSERT dbo.CalibrationReportFile
        (
            OrderDetailsItemId, MbaReportNumber, SourceKind, Variant, UpdateLevel,
            CoversFrom, CoversTo, StorageKey, ArchivePath,
            FileHash, FileSize, ArchiveModifiedAt, SyncedBy
        )
        VALUES
        (
            @OrderDetailsItemId, @MbaReportNumber, @SourceKind, @Variant, @UpdateLevel,
            @CoversFrom, @CoversTo, @StorageKey, @ArchivePath,
            @FileHash, @FileSize, @ArchiveModifiedAt, @SyncedBy
        );

        SET @Id = SCOPE_IDENTITY();
    END

    SELECT @Id AS CalibrationReportFileId;
END
GO
