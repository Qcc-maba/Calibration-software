/*
    dbo.RefreshPackingDataFromPriority
    ---------------------------------------------------------------------------------------------
    Fills in the two packing-screen fields that Priority holds but our sync never brought across:
    "אריזת לקוח" (did the device arrive in the customer's own packaging) and the date we booked
    the device in at the lab.

    Why this procedure exists at all
    --------------------------------
    Both values live on the Priority GOODS-RECEIPT document, which is TYPE 'N'. Our orders point
    at a TYPE 'Q' document, and 'Q' never carries the packing flag:

        our 640 documents, all TYPE 'Q'   ->  0 carry MBA_CUSTPACK = 'Y'
        Priority TYPE 'N' documents       ->  7,272 carry MBA_CUSTPACK = 'Y'

    So stg.MergeOrdersData was reading the right column off the wrong document, and
    OrderDetails.CustomerPackingExists came out False (or NULL) for every order in the system.
    The same merge writes `NULL AS CustomerReceivingDate` outright, which is why that column is
    empty on all 3,842 items.

    The link we need is already in place: OrderDetailsItems.DOC_N points at the 'N' document
    (3,604 of 3,842 items carry one, 392 distinct documents). This procedure follows it.

    On the date column
    ------------------
    The value written to CustomerReceivingDate is the date of the goods-receipt document - i.e.
    when MBA booked the device in, not when the customer received anything. The column name is
    inherited and misleading; the screen labels it "תאריך קליטה", which is what it now holds.
    Renaming it is a separate change with front-end fallout, so the name is left alone here.

    Reading only
    ------------
    The Priority side is a plain OPENQUERY read - nothing is written back to the ERP. The pull is
    bounded to the document range we actually reference so it does not scan all 220,888 receipts.

    Idempotent: only rows whose value actually changes are touched, so re-running it is free and
    UpdatedDate does not churn. Pass @ReportOnly = 1 to see what it would do without writing.
*/
CREATE OR ALTER PROCEDURE dbo.RefreshPackingDataFromPriority
    @ReportOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MinDoc BIGINT, @MaxDoc BIGINT;

    SELECT @MinDoc = MIN(DOC_N), @MaxDoc = MAX(DOC_N)
    FROM dbo.OrderDetailsItems
    WHERE DOC_N IS NOT NULL;

    IF @MinDoc IS NULL
    BEGIN
        SELECT 0 AS ReceiptsRead, 0 AS ItemsDated, 0 AS DetailsFlagged,
               N'No item carries a DOC_N - nothing to look up.' AS Note;
        RETURN;
    END

    DROP TABLE IF EXISTS #Receipt;
    CREATE TABLE #Receipt
    (
        DOC        BIGINT   NOT NULL PRIMARY KEY,
        CustPack   BIT      NOT NULL,
        ReceivedAt DATETIME NULL
    );

    /* Bounded pull of the goods-receipt documents we reference. */
    DECLARE @sql NVARCHAR(MAX) = CONCAT(
        N'INSERT #Receipt (DOC, CustPack, ReceivedAt)
          SELECT q.DOC,
                 IIF(LTRIM(RTRIM(q.MBA_CUSTPACK)) = ''Y'', 1, 0),
                 DATEADD(MINUTE, q.CURDATE, ''1988-01-01'')
          FROM OPENQUERY([31.168.173.93], ''
                SELECT DOC, MBA_CUSTPACK, CURDATE
                FROM amaba.dbo.DOCUMENTS
                WHERE TYPE = ''''N'''' AND DOC BETWEEN ', @MinDoc, N' AND ', @MaxDoc, N'
          '') AS q');

    EXEC sp_executesql @sql;

    /* What the receipts say, before anything is written. */
    DECLARE @ReceiptsRead INT = (SELECT COUNT(*) FROM #Receipt);

    /* An order detail counts as customer-packed when ANY device on it arrived that way -
       the flag is per receipt, and one detail can span several receipts. */
    DROP TABLE IF EXISTS #DetailPack;
    SELECT od.OrderDetailId,
           CustomerPackingExists = CAST(MAX(CAST(r.CustPack AS TINYINT)) AS BIT)
    INTO #DetailPack
    FROM dbo.OrderDetails       AS od
    JOIN dbo.OrderDetailsItems  AS itm ON itm.OrderDetailId = od.OrderDetailId
    JOIN #Receipt               AS r   ON r.DOC = itm.DOC_N
    WHERE ISNULL(od.IsDeleted, 0) = 0
      AND ISNULL(itm.IsDeleted, 0) = 0
    GROUP BY od.OrderDetailId;

    IF @ReportOnly = 1
    BEGIN
        SELECT @ReceiptsRead                                              AS ReceiptsRead,
               (SELECT COUNT(*) FROM #Receipt WHERE CustPack = 1)         AS ReceiptsCustomerPacked,
               (SELECT COUNT(*)
                  FROM dbo.OrderDetailsItems AS itm
                  JOIN #Receipt AS r ON r.DOC = itm.DOC_N
                 WHERE ISNULL(itm.IsDeleted, 0) = 0
                   AND (itm.CustomerReceivingDate IS NULL
                        OR itm.CustomerReceivingDate <> r.ReceivedAt))    AS ItemsThatWouldBeDated,
               (SELECT COUNT(*)
                  FROM dbo.OrderDetails AS od
                  JOIN #DetailPack AS dp ON dp.OrderDetailId = od.OrderDetailId
                 WHERE ISNULL(od.CustomerPackingExists, 0)
                       <> dp.CustomerPackingExists)                       AS DetailsThatWouldChange;

        /* the orders that would light the packing icon */
        SELECT DISTINCT wp.OrderNumber, itm.DOC_N, r.ReceivedAt
        FROM dbo.OrderDetailsItems AS itm
        JOIN #Receipt              AS r  ON r.DOC = itm.DOC_N AND r.CustPack = 1
        JOIN dbo.OrderDetails      AS od ON od.OrderDetailId = itm.OrderDetailId
        JOIN dbo.OrderWorkPlans    AS wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
        WHERE ISNULL(itm.IsDeleted, 0) = 0
        ORDER BY wp.OrderNumber;
        RETURN;
    END

    DECLARE @ItemsDated INT = 0, @DetailsFlagged INT = 0;

    BEGIN TRANSACTION;

        UPDATE itm
        SET itm.CustomerReceivingDate = r.ReceivedAt
        FROM dbo.OrderDetailsItems AS itm
        JOIN #Receipt              AS r ON r.DOC = itm.DOC_N
        WHERE ISNULL(itm.IsDeleted, 0) = 0
          AND r.ReceivedAt IS NOT NULL
          AND (itm.CustomerReceivingDate IS NULL
               OR itm.CustomerReceivingDate <> r.ReceivedAt);

        SET @ItemsDated = @@ROWCOUNT;

        UPDATE od
        SET od.CustomerPackingExists = dp.CustomerPackingExists
        FROM dbo.OrderDetails AS od
        JOIN #DetailPack      AS dp ON dp.OrderDetailId = od.OrderDetailId
        WHERE ISNULL(od.CustomerPackingExists, 0) <> dp.CustomerPackingExists;

        SET @DetailsFlagged = @@ROWCOUNT;

    COMMIT TRANSACTION;

    SELECT @ReceiptsRead                                       AS ReceiptsRead,
           (SELECT COUNT(*) FROM #Receipt WHERE CustPack = 1)  AS ReceiptsCustomerPacked,
           @ItemsDated                                         AS ItemsDated,
           @DetailsFlagged                                     AS DetailsFlagged;
END
GO
