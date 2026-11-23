/*
    Tests for the order-attachment conversion objects                                       MBA-930
    ---------------------------------------------------------------------------------------------
    dbo.SaveOrderAttachmentConversion, dbo.GetOrderAttachmentsToConvert and
    dbo.GetOrderAttachmentDocuments, against a database where the two tables
    (dbo.CrmOrderAttachmentConversion, dbo.CrmOrderAttachmentPart) are deployed and
    dbo.CrmOrderAttachments holds at least one servable file of a live work plan.

    Anything other than 'PASS' in Result is a failure; 'SKIP' means no suitable row exists.
    Every write is inside one transaction that is rolled back. @Out is a table variable, so its
    rows survive the rollback.
*/
SET NOCOUNT ON;

DECLARE @Out TABLE (Seq INT IDENTITY, Test NVARCHAR(80), Expected NVARCHAR(60), Actual NVARCHAR(60), Result NVARCHAR(10));

DECLARE @Ord INT, @FileNum INT, @Path NVARCHAR(200), @Wp INT;

/* A servable file of a live work plan that has no conversion yet. */
SELECT TOP (1) @Ord = a.ORD, @FileNum = a.EXTFILENUM, @Path = a.FilePath, @Wp = wp.OrderWorkPlanId
FROM dbo.CrmOrderAttachments AS a
JOIN dbo.OrderWorkPlans AS wp ON wp.OrderSourceId = a.ORD AND ISNULL(wp.IsCancelled, 0) = 0
WHERE a.IsPathTruncated = 0
  AND NOT EXISTS (SELECT 1 FROM dbo.CrmOrderAttachmentConversion c WHERE c.ORD = a.ORD AND c.EXTFILENUM = a.EXTFILENUM)
  /* one file on that order, so the counts below are this file's */
  AND (SELECT COUNT(*) FROM dbo.CrmOrderAttachments x WHERE x.ORD = a.ORD) = 1
ORDER BY a.ORD DESC;

IF @Ord IS NULL
BEGIN
    INSERT INTO @Out VALUES (N'pick a file', N'a row', N'none', N'SKIP');
    SELECT Test, Expected, Actual, Result FROM @Out ORDER BY Seq;
    RETURN;
END

DECLARE @Docs TABLE (OrderWorkPlanId INT, OrderNumber NVARCHAR(50), FileNumber INT, FileName NVARCHAR(200),
                     FileDescription NVARCHAR(200), FileStatus VARCHAR(12), FileDetail NVARCHAR(400),
                     MergedStorageKey NVARCHAR(400), PartId VARCHAR(40), PartSeq INT, PartName NVARCHAR(400),
                     PartKind VARCHAR(16), PartError NVARCHAR(400), PartStorageKey NVARCHAR(400), PartFileSize BIGINT);
DECLARE @Due TABLE (ORD INT, EXTFILENUM INT, FilePath NVARCHAR(200), FileExtension NVARCHAR(20),
                    SourceKind VARCHAR(20), Description NVARCHAR(200));
DECLARE @n INT, @s NVARCHAR(60);

BEGIN TRAN;

/* 1. Before any attempt: pending, and due. */
INSERT INTO @Docs EXEC dbo.GetOrderAttachmentDocuments @OrderWorkPlanId = @Wp;
SELECT @s = MAX(FileStatus), @n = COUNT(*) FROM @Docs;
INSERT INTO @Out VALUES (N'not tried: one row, Pending', N'1 Pending', CONCAT(@n, ' ', @s),
                         IIF(@n = 1 AND @s = 'Pending', 'PASS', 'FAIL'));

INSERT INTO @Due EXEC dbo.GetOrderAttachmentsToConvert @BatchSize = 100000;
SELECT @n = COUNT(*) FROM @Due WHERE ORD = @Ord AND EXTFILENUM = @FileNum;
INSERT INTO @Out VALUES (N'not tried: due', N'1', @n, IIF(@n = 1, 'PASS', 'FAIL'));

/* 2. Converted: a body and an enclosure that failed. */
DECLARE @Parts NVARCHAR(MAX) = CONCAT(N'[{"partId":"body","seq":0,"name":"RE: test","kind":"MailBody","error":null,',
    N'"storageKey":"order-attachments/', @Ord, '/', @FileNum, N'/body.pdf","fileSize":100},',
    N'{"partId":"abc","seq":1,"name":"PO.docx","kind":"Error","error":"LibreOffice is not installed","storageKey":null,"fileSize":null}]');

EXEC dbo.SaveOrderAttachmentConversion @ORD = @Ord, @EXTFILENUM = @FileNum, @SourcePath = @Path, @Outcome = 1,
     @MergedStorageKey = N'order-attachments/x/body.pdf', @PartsJson = @Parts;

DELETE FROM @Docs;
INSERT INTO @Docs EXEC dbo.GetOrderAttachmentDocuments @OrderWorkPlanId = @Wp;
SELECT @n = COUNT(*) FROM @Docs WHERE FileStatus = 'Ready';
INSERT INTO @Out VALUES (N'converted: both parts listed, Ready', N'2', @n, IIF(@n = 2, 'PASS', 'FAIL'));
SELECT @s = PartError FROM @Docs WHERE PartId = 'abc';
INSERT INTO @Out VALUES (N'the failed part keeps its reason (AC #6)', N'LibreOffice is not installed', @s,
                         IIF(@s = N'LibreOffice is not installed', 'PASS', 'FAIL'));
SELECT @s = MIN(PartId) FROM @Docs WHERE PartSeq = 0;
INSERT INTO @Out VALUES (N'body first', N'body', @s, IIF(@s = 'body', 'PASS', 'FAIL'));

DELETE FROM @Due;
INSERT INTO @Due EXEC dbo.GetOrderAttachmentsToConvert @BatchSize = 100000;
SELECT @n = COUNT(*) FROM @Due WHERE ORD = @Ord AND EXTFILENUM = @FileNum;
INSERT INTO @Out VALUES (N'converted: no longer due', N'0', @n, IIF(@n = 0, 'PASS', 'FAIL'));

/* 2b. It has an error part, so it is due again after @RetryErrorPartsDays: the error may have
       been the server's, e.g. LibreOffice installed since (review of PR #69). */
UPDATE dbo.CrmOrderAttachmentConversion SET AttemptedAt = DATEADD(DAY, -8, SYSUTCDATETIME())
WHERE ORD = @Ord AND EXTFILENUM = @FileNum;
DELETE FROM @Due;
INSERT INTO @Due EXEC dbo.GetOrderAttachmentsToConvert @BatchSize = 100000, @RetryErrorPartsDays = 7;
SELECT @n = COUNT(*) FROM @Due WHERE ORD = @Ord AND EXTFILENUM = @FileNum;
INSERT INTO @Out VALUES (N'error part: due again after 7 days', N'1', @n, IIF(@n = 1, 'PASS', 'FAIL'));

DELETE FROM dbo.CrmOrderAttachmentPart WHERE ORD = @Ord AND EXTFILENUM = @FileNum AND Kind = 'Error';
DELETE FROM @Due;
INSERT INTO @Due EXEC dbo.GetOrderAttachmentsToConvert @BatchSize = 100000, @RetryErrorPartsDays = 7;
SELECT @n = COUNT(*) FROM @Due WHERE ORD = @Ord AND EXTFILENUM = @FileNum;
INSERT INTO @Out VALUES (N'no error part: never due again', N'0', @n, IIF(@n = 0, 'PASS', 'FAIL'));

/* back to both parts for the steps below */
EXEC dbo.SaveOrderAttachmentConversion @ORD = @Ord, @EXTFILENUM = @FileNum, @SourcePath = @Path, @Outcome = 1,
     @MergedStorageKey = N'order-attachments/x/body.pdf', @PartsJson = @Parts;

/* 3. A later attempt cannot read the file: the parts stay served. */
EXEC dbo.SaveOrderAttachmentConversion @ORD = @Ord, @EXTFILENUM = @FileNum, @SourcePath = @Path, @Outcome = 2,
     @Detail = N'IOException: locked';
SELECT @n = COUNT(*) FROM dbo.CrmOrderAttachmentPart WHERE ORD = @Ord AND EXTFILENUM = @FileNum;
INSERT INTO @Out VALUES (N'unreadable later: parts kept', N'2', @n, IIF(@n = 2, 'PASS', 'FAIL'));
SELECT @s = MergedStorageKey FROM dbo.CrmOrderAttachmentConversion WHERE ORD = @Ord AND EXTFILENUM = @FileNum;
INSERT INTO @Out VALUES (N'unreadable later: merged key kept', N'order-attachments/x/body.pdf', @s,
                         IIF(@s = N'order-attachments/x/body.pdf', 'PASS', 'FAIL'));

/* 4. Due again only after the retry window. */
DELETE FROM @Due;
INSERT INTO @Due EXEC dbo.GetOrderAttachmentsToConvert @BatchSize = 100000, @RetryAfterHours = 6;
SELECT @n = COUNT(*) FROM @Due WHERE ORD = @Ord AND EXTFILENUM = @FileNum;
INSERT INTO @Out VALUES (N'unreadable: not due within 6 h', N'0', @n, IIF(@n = 0, 'PASS', 'FAIL'));

UPDATE dbo.CrmOrderAttachmentConversion SET AttemptedAt = DATEADD(HOUR, -7, SYSUTCDATETIME())
WHERE ORD = @Ord AND EXTFILENUM = @FileNum;
DELETE FROM @Due;
INSERT INTO @Due EXEC dbo.GetOrderAttachmentsToConvert @BatchSize = 100000, @RetryAfterHours = 6;
SELECT @n = COUNT(*) FROM @Due WHERE ORD = @Ord AND EXTFILENUM = @FileNum;
INSERT INTO @Out VALUES (N'unreadable: due after 6 h', N'1', @n, IIF(@n = 1, 'PASS', 'FAIL'));

/* 5. A file that never converted and cannot be read shows Failed with its reason. */
DELETE FROM dbo.CrmOrderAttachmentPart WHERE ORD = @Ord AND EXTFILENUM = @FileNum;
DELETE FROM @Docs;
INSERT INTO @Docs EXEC dbo.GetOrderAttachmentDocuments @OrderWorkPlanId = @Wp;
SELECT @s = CONCAT(MAX(FileStatus), ' / ', MAX(FileDetail)) FROM @Docs;
INSERT INTO @Out VALUES (N'never converted + unreadable: Failed with detail', N'Failed / IOException: locked', @s,
                         IIF(@s = N'Failed / IOException: locked', 'PASS', 'FAIL'));

/* 6. Priority re-attaches the file under a new path: due again at once. */
UPDATE dbo.CrmOrderAttachmentConversion SET Outcome = 1, AttemptedAt = SYSUTCDATETIME(), SourcePath = N'\\old\path.msg'
WHERE ORD = @Ord AND EXTFILENUM = @FileNum;
DELETE FROM @Due;
INSERT INTO @Due EXEC dbo.GetOrderAttachmentsToConvert @BatchSize = 100000;
SELECT @n = COUNT(*) FROM @Due WHERE ORD = @Ord AND EXTFILENUM = @FileNum;
INSERT INTO @Out VALUES (N'new path in Priority: due again', N'1', @n, IIF(@n = 1, 'PASS', 'FAIL'));

ROLLBACK;

/* 7. Refusals, each in its own transaction (XACT_ABORT dooms the one it happens in). */
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.SaveOrderAttachmentConversion @ORD = @Ord, @EXTFILENUM = @FileNum, @SourcePath = @Path, @Outcome = 1;
    ROLLBACK;
    INSERT INTO @Out VALUES (N'converted without parts is refused', N'51133', N'no error', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT INTO @Out VALUES (N'converted without parts is refused', N'51133', ERROR_NUMBER(), IIF(ERROR_NUMBER() = 51133, 'PASS', 'FAIL'));
END CATCH

BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.SaveOrderAttachmentConversion @ORD = @Ord, @EXTFILENUM = @FileNum, @SourcePath = @Path, @Outcome = 1,
         @PartsJson = N'[{"partId":"x","seq":0,"name":"n","kind":"Document","error":null,"storageKey":null}]';
    ROLLBACK;
    INSERT INTO @Out VALUES (N'a part with neither key nor error is refused', N'547', N'no error', 'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT INTO @Out VALUES (N'a part with neither key nor error is refused', N'547', ERROR_NUMBER(), IIF(ERROR_NUMBER() = 547, 'PASS', 'FAIL'));
END CATCH

SELECT @n = COUNT(*) FROM dbo.CrmOrderAttachmentConversion WHERE ORD = @Ord AND EXTFILENUM = @FileNum;
INSERT INTO @Out VALUES (N'rolled back: nothing left behind', N'0', @n, IIF(@n = 0, 'PASS', 'FAIL'));

SELECT Test, Expected, Actual, Result FROM @Out ORDER BY Seq;
