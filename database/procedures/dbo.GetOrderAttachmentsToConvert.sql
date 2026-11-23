/*
    dbo.GetOrderAttachmentsToConvert                                                    MBA-930
    ---------------------------------------------------------------------------------------------
    The order attachments ReportArchiveSync should convert to PDF this cycle, newest order first.
    Read-only; served from the local cache dbo.CrmOrderAttachments, so it never crosses the
    linked server.

    A file is due when
      - it has never been tried, or
      - Priority now stores a different path for it (a re-attached file), or
      - its last attempt could not read the file (Outcome 2) and @RetryAfterHours have passed, or
      - its last attempt found no file (Outcome 3) and @RetryNotFoundDays have passed, or
      - it was converted but some parts are still errors and @RetryErrorPartsDays have passed:
        the error may have been the server's (LibreOffice not installed yet), and installing the
        missing piece has to reach files converted before it (review of PR #69). A document that
        is simply unconvertible is converted again that often too; there are few of them.
    A file whose path Priority truncated (IsPathTruncated) is never due: it cannot be found. The
    read procedure lists it as unavailable.

    Size on 22/11/2026: PROD 3,078 files in the cache, STAGE 1,306. So the first run is a few
    batches and every later one carries the day's new orders.

    Params
      @BatchSize          INT = 200
      @RetryAfterHours    INT = 6
      @RetryNotFoundDays  INT = 7
      @RetryErrorPartsDays INT = 7
    Returns: ORD, EXTFILENUM, FilePath, FileExtension, SourceKind, Description
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.GetOrderAttachmentsToConvert
    @BatchSize         INT = 200,
    @RetryAfterHours   INT = 6,
    @RetryNotFoundDays INT = 7,
    @RetryErrorPartsDays INT = 7
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Now DATETIME2(3) = SYSUTCDATETIME();

    SELECT TOP (@BatchSize)
         a.ORD
        ,a.EXTFILENUM
        ,a.FilePath
        ,a.FileExtension
        /* Same classification as dbo.GetOrderAttachmentsByOrder. */
        ,SourceKind = CASE
                        WHEN a.FileExtension = 'msg'   THEN 'OutlookMessage'
                        WHEN a.FileExtension = 'pdf'   THEN 'Pdf'
                        WHEN a.FileExtension IN ('jpeg','jpg','tif','tiff','png','bmp','gif')
                                                       THEN 'Image'
                        WHEN a.FileExtension IN ('xls','xlsx','doc','docx','rtf','htm','html','txt')
                                                       THEN 'Document'
                        ELSE 'Other'
                      END
        ,a.Description
    FROM dbo.CrmOrderAttachments AS a
    LEFT JOIN dbo.CrmOrderAttachmentConversion AS c
           ON c.ORD = a.ORD AND c.EXTFILENUM = a.EXTFILENUM
    WHERE a.IsPathTruncated = 0
      AND a.FilePath IS NOT NULL
      AND (    c.ORD IS NULL
            OR c.SourcePath <> a.FilePath
            OR (c.Outcome = 2 AND c.AttemptedAt < DATEADD(HOUR, -@RetryAfterHours, @Now))
            OR (c.Outcome = 3 AND c.AttemptedAt < DATEADD(DAY, -@RetryNotFoundDays, @Now))
            OR (c.Outcome = 1 AND c.AttemptedAt < DATEADD(DAY, -@RetryErrorPartsDays, @Now)
                AND EXISTS (SELECT 1 FROM dbo.CrmOrderAttachmentPart AS p
                            WHERE p.ORD = c.ORD AND p.EXTFILENUM = c.EXTFILENUM AND p.Kind = 'Error')))
    ORDER BY a.ORD DESC, a.EXTFILENUM;
END
GO
