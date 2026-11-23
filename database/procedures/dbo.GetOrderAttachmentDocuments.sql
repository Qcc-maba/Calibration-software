/*
    dbo.GetOrderAttachmentDocuments                                                     MBA-930
    ---------------------------------------------------------------------------------------------
    What the work-assignment screen shows behind an order's file button: every file Priority
    attached to the order and every PDF part ReportArchiveSync made of it. The app turns each
    StorageKey into a short-lived signed S3 link, as it does for invoices (MBA-998), so nothing
    on Vercel has to reach Priority's share.

    ONE ROW PER PART, ordered by FileNumber then PartSeq. A file with no parts yet still returns
    one row, with the Part* columns NULL and FileStatus saying why. One result set on purpose:
    Prisma's $queryRaw reads only the first.

    FileStatus
      Ready        Converted. Each part either has a StorageKey or an Error (AC #6: list the
                   error, never hide the part).
      Pending      Not converted yet. Normal for a few minutes after a new order arrives.
      Failed       The last attempt could not read the file (FileDetail says why) and no earlier
                   conversion exists. Retried by the sync.
      Unavailable  Priority truncated the stored path; the file can never be found.

    Param:   @OrderWorkPlanId INT (required)
    Returns: OrderWorkPlanId, OrderNumber, FileNumber, FileName, FileDescription, FileStatus,
             FileDetail, MergedStorageKey, PartId, PartSeq, PartName, PartKind, PartError,
             PartStorageKey, PartFileSize
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.GetOrderAttachmentDocuments
    @OrderWorkPlanId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
         wp.OrderWorkPlanId
        ,wp.OrderNumber
        ,a.EXTFILENUM AS FileNumber
        ,FileName = CASE
                        WHEN a.IsPathTruncated = 1 THEN NULL
                        WHEN CHARINDEX('\', REVERSE(a.FilePath)) = 0 THEN a.FilePath
                        ELSE RIGHT(a.FilePath, CHARINDEX('\', REVERSE(a.FilePath)) - 1)
                    END
        ,a.Description AS FileDescription
        ,FileStatus = CASE
                        WHEN a.IsPathTruncated = 1          THEN 'Unavailable'
                        WHEN p.PartId IS NOT NULL           THEN 'Ready'
                        WHEN c.Outcome IN (2, 3)            THEN 'Failed'
                        ELSE 'Pending'
                      END
        ,FileDetail = CASE
                        WHEN a.IsPathTruncated = 1
                            THEN N'Priority stored a truncated path for this file, so it cannot be located.'
                        WHEN p.PartId IS NULL AND c.Outcome IN (2, 3) THEN c.Detail
                      END
        ,c.MergedStorageKey
        ,p.PartId
        ,p.Seq        AS PartSeq
        ,p.Name       AS PartName
        ,p.Kind       AS PartKind
        ,p.Error      AS PartError
        ,p.StorageKey AS PartStorageKey
        ,p.FileSize   AS PartFileSize
    FROM dbo.OrderWorkPlans      AS wp
    JOIN dbo.CrmOrderAttachments AS a ON a.ORD = wp.OrderSourceId
    LEFT JOIN dbo.CrmOrderAttachmentConversion AS c
           ON c.ORD = a.ORD AND c.EXTFILENUM = a.EXTFILENUM
    LEFT JOIN dbo.CrmOrderAttachmentPart AS p
           ON p.ORD = a.ORD AND p.EXTFILENUM = a.EXTFILENUM
          AND a.IsPathTruncated = 0
    WHERE wp.OrderWorkPlanId = @OrderWorkPlanId
      AND ISNULL(wp.IsCancelled, 0) = 0
    ORDER BY a.EXTFILENUM, p.Seq;
END
GO
