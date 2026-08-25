/*
    dbo.RefreshCustomerRemarksFromPriority                                              MBA-902
    ---------------------------------------------------------------------------------------------
    Rebuilds dbo.CustomerRemarks.CustomerRemark from Priority, with the word breaks intact.

    953 of the 1,012 active rows have their words glued together - "סעיףתקציבי", "מחיריםמיוחדים",
    "מיוחדותלשינוע", "המתנההמלאה". Priority stores this text one row per wrapped line in
    amaba.dbo.CUSTOMERSTEXT (CUST, TEXT, TEXTLINE, TEXTORD) and wraps at a word boundary WITHOUT
    keeping the space, so joining the lines with nothing welds the last word of each line to the
    first word of the next. Same defect, same cause, as the order instructions in
    dbo.RefreshCrmTextCache - this is the second pipeline carrying it.

    The text is also character-reversed in Priority, hence the REVERSE.

    IMPORTANT - this is a repair, not a cure. The gluing happens BEFORE SQL Server: stg_CustomerRemarks
    already arrives with CompresedText welded (727 of 1,012), so the join is done by the SSIS package
    that fills staging. Until that package uses a separator, every sync will undo this and the
    procedure has to be re-run. Raised separately.

    Only rows whose text actually differs are written, so a re-run after a clean sync is a no-op.
    Run with @Apply = 0 first: it reports what would change and touches nothing.
*/
CREATE OR ALTER PROCEDURE dbo.RefreshCustomerRemarksFromPriority
    @Apply BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    CREATE TABLE #Src (CUST INT PRIMARY KEY, Rebuilt NVARCHAR(MAX));

    /* OPENQUERY so the aggregation runs on the Priority side. */
    INSERT INTO #Src (CUST, Rebuilt)
    SELECT CUST, Rebuilt
    FROM OPENQUERY([31.168.173.93], '
        SELECT CUST,
               STRING_AGG(REVERSE(CAST(TEXT AS NVARCHAR(MAX))), '' '')
                   WITHIN GROUP (ORDER BY TEXTLINE, TEXTORD) AS Rebuilt
        FROM amaba.dbo.CUSTOMERSTEXT
        GROUP BY CUST');

    SELECT r.CustomerId, s.Rebuilt,
           CAST(DECOMPRESS(r.CustomerRemark) AS NVARCHAR(MAX)) AS Current_
    INTO #Diff
    FROM dbo.CustomerRemarks AS r
    INNER JOIN #Src AS s ON s.CUST = r.CustomerId
    WHERE r.IsDeleted = 0
      AND ISNULL(CAST(DECOMPRESS(r.CustomerRemark) AS NVARCHAR(MAX)), N'') <> ISNULL(s.Rebuilt, N'');

    SELECT (SELECT COUNT(*) FROM dbo.CustomerRemarks WHERE IsDeleted = 0) AS ActiveRows,
           (SELECT COUNT(*) FROM #Src)                                    AS FoundInPriority,
           (SELECT COUNT(*) FROM #Diff)                                   AS WouldRewrite;

    IF @Apply = 1
    BEGIN
        UPDATE r
        SET CustomerRemark = COMPRESS(d.Rebuilt),
            UpdatedDate    = GETDATE()
        FROM dbo.CustomerRemarks AS r
        INNER JOIN #Diff AS d ON d.CustomerId = r.CustomerId
        WHERE r.IsDeleted = 0;

        SELECT @@ROWCOUNT AS RowsRewritten;
    END
    ELSE
        SELECT TOP (20) CustomerId, LEFT(Current_, 90) AS before_, LEFT(Rebuilt, 90) AS after_
        FROM #Diff ORDER BY CustomerId;
END
