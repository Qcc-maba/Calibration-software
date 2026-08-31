-- =============================================
-- Proc:        dbo.GetOrderAttachmentsByOrder
-- Jira:        MBA-930 ("Work file: show the order's Priority attachments, converted to PDF")
-- Description: The documents Priority hangs off an order — the "נספחים" sub-form of
--              "אישור הזמנה" — for one order, served from dbo.CrmOrderAttachments so the
--              request never crosses the linked server.
--
--              Returns ONE ROW PER FILE, ordered by EXTFILENUM, the file's sequence within
--              the order. Most orders carry one, but 215 carry 3, 39 carry 4, 8 carry 5 and one
--              carries 12 — do NOT assume a small fixed maximum. 13,237 orders carry at least
--              one and many carry none, so an empty result is normal and is what greys out the
--              file button on the work assignment screen.
--
--              LINE is returned for reference only. It is NOT a file index: it takes 3 distinct
--              values across the source table and repeats within an order.
--
--              CanBeServed is the column the UI acts on:
--                1 -> the file is locatable and can be sent to the converter.
--                0 -> IsPathTruncated: Priority's EXTFILENAME is varchar(80) and it cut the
--                     name, so the file cannot be found. 35 rows are in this state.
--                     These MUST still be listed, as an error row. Hiding them leaves the
--                     calibrator with no way to know a document exists.
--
--              SourceKind tells the conversion layer what it is dealing with. 99.3% of order
--              attachments are .msg Outlook messages, not documents — for those the converter
--              has to render the message body AND each attachment carried inside it. Only 62
--              files in the whole system are already PDF.
--
-- Param:       @OrderWorkPlanId INT           -- required
-- Returns:     OrderWorkPlanId, OrderNumber, FileNumber, Line, FileName, FilePath,
--              FileExtension, SourceKind, Description, DescriptionRaw, FileSize,
--              CanBeServed, IsPathTruncated
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetOrderAttachmentsByOrder]
    @OrderWorkPlanId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
         wp.OrderWorkPlanId
        ,wp.OrderNumber
        ,a.EXTFILENUM                               AS FileNumber
        ,a.LINE                                     AS Line
        /* Trailing segment of the UNC path. NULL when truncated — a cut path has no filename. */
        ,FileName = CASE
                        WHEN a.IsPathTruncated = 1 THEN NULL
                        WHEN CHARINDEX('\', REVERSE(a.FilePath)) = 0 THEN a.FilePath
                        ELSE RIGHT(a.FilePath, CHARINDEX('\', REVERSE(a.FilePath)) - 1)
                    END
        ,a.FilePath
        ,a.FileExtension
        ,SourceKind = CASE
                        WHEN a.IsPathTruncated = 1     THEN 'Unreachable'
                        WHEN a.FileExtension = 'msg'   THEN 'OutlookMessage'
                        WHEN a.FileExtension = 'pdf'   THEN 'Pdf'
                        WHEN a.FileExtension IN ('jpeg','jpg','tif','tiff','png','bmp','gif')
                                                       THEN 'Image'
                        WHEN a.FileExtension IN ('xls','xlsx','doc','docx','rtf','htm','html','txt')
                                                       THEN 'Document'
                        ELSE 'Other'
                      END
        ,a.Description          /* un-reversed, safe to display */
        ,a.DescriptionRaw       /* Priority's own text, kept for diagnosis */
        ,a.FileSize
        ,CanBeServed     = CAST(CASE WHEN a.IsPathTruncated = 1 THEN 0 ELSE 1 END AS BIT)
        ,a.IsPathTruncated
    FROM dbo.OrderWorkPlans      AS wp
    JOIN dbo.CrmOrderAttachments AS a ON a.ORD = wp.OrderSourceId
    WHERE wp.OrderWorkPlanId = @OrderWorkPlanId
      AND ISNULL(wp.IsCancelled, 0) = 0
    ORDER BY a.EXTFILENUM;
END
GO
