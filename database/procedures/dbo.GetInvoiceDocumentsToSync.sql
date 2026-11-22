/*
    dbo.GetInvoiceDocumentsToSync                                                       MBA-998
    ---------------------------------------------------------------------------------------------
    The invoice PDFs the on-prem sync (ReportArchiveSync) should copy to S3 this cycle, newest
    first. Reads Priority once per call, in one OPENQUERY round-trip, and compares with
    dbo.CustomerInvoiceDocument locally.

    An invoice is returned when:
      - it has never been tried;
      - its attachment changed in Priority (another EXTFILENUM: a re-issued PDF);
      - the last attempt failed and is at least @RetryAfterDays old. A PDF that is not in its
        directory yet usually appears later; retrying every hour would only repeat the same miss.

    Which attachment: the same rule the portal used before MBA-998 - the newest PDF attached to
    the invoice (CURDATE, then EXTFILENUM), with a directory in its path. EXTFILES.TYPE = 'I'
    keeps it to invoice attachments: EXTFILES.IV is shared with orders, parts and others, so
    matching on IV alone can attach another document to an invoice whose number collides
    (measured 2026-11-22: 89 PDFs of other types share an invoice's IV on PROD). OTYPE C keeps it to customer-side documents, as on the
    portal's invoice screen.

    Returns: IV, InvoiceNumber, ExtFileNum, ExtFileName, FileSize (Priority's recorded size,
    which for TYPE 'I' is the real byte count), CurDate (minutes since 1988-01-01).

    Reads only; writes nothing. The Priority server comes from dbo.PriorityLinkedServer (MBA-1028).
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.GetInvoiceDocumentsToSync
    @BatchSize      INT = 1000,
    @RetryAfterDays INT = 7
AS
BEGIN
    SET NOCOUNT ON;

    IF @BatchSize IS NULL OR @BatchSize < 1
        THROW 51110, N'GetInvoiceDocumentsToSync: @BatchSize must be at least 1.', 1;

    /* NVARCHAR, not Priority's varchar: in this database's Latin collation a varchar column would
       turn the Hebrew in EXTFILENAME into question marks. */
    CREATE TABLE #Remote
    (
        IV            INT            NOT NULL PRIMARY KEY,
        InvoiceNumber NVARCHAR(4000) COLLATE DATABASE_DEFAULT NOT NULL,
        ExtFileNum    INT            NOT NULL,
        ExtFileName   NVARCHAR(4000) COLLATE DATABASE_DEFAULT NOT NULL,
        FileSize      BIGINT         NULL,
        CurDate       INT            NULL
    );

    DECLARE @Oq NVARCHAR(MAX), @Sql NVARCHAR(MAX);
    EXEC dbo.BuildPriorityOpenQuery @OpenQuery = @Oq OUTPUT, @RemoteQuery = N'
        SELECT a.IV, InvoiceNumber = iv.IVNUM, ExtFileNum = a.EXTFILENUM, ExtFileName = a.EXTFILENAME,
               FileSize = a.FILESIZE, CurDate = a.CURDATE
        FROM (SELECT x.IV, x.EXTFILENUM, x.EXTFILENAME, x.FILESIZE, x.CURDATE,
                     rn = ROW_NUMBER() OVER (PARTITION BY x.IV ORDER BY x.CURDATE DESC, x.EXTFILENUM DESC)
              FROM amaba.dbo.EXTFILES AS x
              WHERE x.TYPE = ''I''
                AND x.EXTFILENAME LIKE ''%.pdf''
                AND CHARINDEX(CHAR(92), x.EXTFILENAME) > 0) AS a
        JOIN amaba.dbo.INVOICES AS iv ON iv.IV = a.IV
        LEFT JOIN amaba.dbo.IVTYPES AS t ON t.TYPE = iv.TYPE AND t.FNCPATTERN = iv.FNCPATTERN
        WHERE a.rn = 1
          AND ISNULL(t.OTYPE, ''C'') = ''C''
    ';
    SET @Sql = N'SELECT IV, InvoiceNumber, ExtFileNum, ExtFileName, FileSize, CurDate FROM ' + @Oq;

    INSERT INTO #Remote (IV, InvoiceNumber, ExtFileNum, ExtFileName, FileSize, CurDate)
    EXEC sys.sp_executesql @Sql;

    SELECT TOP (@BatchSize)
           r.IV, r.InvoiceNumber, r.ExtFileNum, r.ExtFileName, r.FileSize, r.CurDate
    FROM #Remote AS r
    LEFT JOIN dbo.CustomerInvoiceDocument AS d ON d.IV = r.IV
    WHERE d.IV IS NULL
       OR d.ExtFileNum <> r.ExtFileNum
       OR (d.Outcome <> 1 AND d.AttemptedAt < DATEADD(DAY, -@RetryAfterDays, SYSUTCDATETIME()))
    ORDER BY r.CurDate DESC, r.IV DESC;
END
GO
