/*
    Backfill — OrderDetailsItems.MbaReportNumber from Priority        (PROD only)
    ============================================================================

    Fills the historical report numbers that the sync never delivered. STAGE does not need this
    (97.2% already populated); this is for CalibratorProd.

    PREREQUISITE: apply FIX_stg.MergeOrdersData.MbaReportNumber.sql FIRST. Without it the hourly
    sync erases MbaReportNumber for every item inside its window, and this backfill is undone
    order by order over the following days.

    SOURCE OF TRUTH
    ---------------
        amaba.dbo.MBA_DOCUMENTS.MBANUM      -- '2608737/1'
                 keyed by MBA_DOCUMENTS.DOC = OrderDetailsItems.Doc

    Reached over the linked server [31.168.173.93], which is already configured on CalibratorProd
    and readable by app_prod. This is the same field the SSIS source view already reads
    (amaba.dbo.vwGetOrders_WorkPlan_Full_new: `mbad.MBANUM AS MbaReportNumber`).

    Measured coverage: 7,607 of 7,674 items with a Doc (99.1%) resolve to a report number.

    WHY THE SOURCE FILTER MATTERS
    -----------------------------
    Two Priority companies feed this database — amaba (Source 1 = MABA) and sepharm (Source 2).
    Each has its OWN MBA_DOCUMENTS with its OWN DOC sequence, and the two sequences occupy the
    same numeric range. Joining on Doc alone would therefore be free to attach an amaba report to
    a sepharm device, silently and with no error.

    Today that cannot happen: all 7,908 items carrying a Doc on PROD are Source 1. But sepharm
    orders are expected later, so the filter goes in now rather than after the first bad row.
    When sepharm is added, repeat this script against sepharm.dbo.MBA_DOCUMENTS with SourceId = 2
    — after first checking whether the DOC ranges actually collide.

    Note also that MBANUM is NOT the same thing as Doc or DOC_N even though all three are
    7-digit numbers in the same range. Doc and DOC_N are Priority document ids; only MBANUM is
    the MABA report number, and only MBANUM matches the archive file names. Roughly 14% of Doc
    values coincidentally look like a valid archive prefix. Do not "optimise" this join to use them.
*/
SET XACT_ABORT ON;
SET NOCOUNT ON;

/* ---------------------------------------------------------------------------------------------
   1. Pull the mapping across the linked server once, into a local temp table.
      OPENQUERY (not a four-part name) keeps the filter on the remote side; a four-part join
      would drag all 2.5M rows of MBA_DOCUMENTS over the wire.
   --------------------------------------------------------------------------------------------- */
DROP TABLE IF EXISTS #PriorityReportNumbers;

SELECT DOC, MBANUM
INTO #PriorityReportNumbers
FROM OPENQUERY([31.168.173.93],
    'SELECT DOC, MBANUM
     FROM amaba.dbo.MBA_DOCUMENTS
     WHERE MBANUM IS NOT NULL AND LEN(MBANUM) > 0');

CREATE UNIQUE CLUSTERED INDEX UC_PriorityReportNumbers ON #PriorityReportNumbers (DOC);

/* ---------------------------------------------------------------------------------------------
   2. DRY RUN — inspect this before running step 3. Nothing is written yet.
   --------------------------------------------------------------------------------------------- */
SELECT
     COUNT(*)                                                        AS ItemsWithDoc
    ,SUM(CASE WHEN p.MBANUM IS NOT NULL THEN 1 ELSE 0 END)           AS WouldResolve
    ,SUM(CASE WHEN p.MBANUM IS NOT NULL
                   AND NULLIF(i.MbaReportNumber, N'') IS NULL
              THEN 1 ELSE 0 END)                                     AS WouldBeUpdated
    ,SUM(CASE WHEN NULLIF(i.MbaReportNumber, N'') IS NOT NULL
              THEN 1 ELSE 0 END)                                     AS AlreadySetLeftAlone
FROM dbo.OrderDetailsItems AS i
JOIN dbo.OrderDetails      AS od ON od.OrderDetailId   = i.OrderDetailId
JOIN dbo.OrderWorkPlans    AS wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
LEFT JOIN #PriorityReportNumbers AS p ON p.DOC = i.Doc
WHERE i.Doc IS NOT NULL
  AND i.IsDeleted = 0
  AND wp.SourceId = 1;          /* MABA only — see header */

/* ---------------------------------------------------------------------------------------------
   3. THE UPDATE. Uncomment to run.

      Wrapped in a transaction that is left OPEN deliberately: check @@ROWCOUNT and the
      verification query against the dry-run numbers, then COMMIT or ROLLBACK by hand.

      NULLIF(...) IS NULL guarantees a number minted by the calibration wizard is never
      overwritten — this only ever fills blanks.
   --------------------------------------------------------------------------------------------- */
/*
BEGIN TRANSACTION;

UPDATE i
SET MbaReportNumber = p.MBANUM
FROM dbo.OrderDetailsItems AS i
JOIN dbo.OrderDetails      AS od ON od.OrderDetailId   = i.OrderDetailId
JOIN dbo.OrderWorkPlans    AS wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
JOIN #PriorityReportNumbers AS p ON p.DOC = i.Doc
WHERE i.Doc IS NOT NULL
  AND i.IsDeleted = 0
  AND wp.SourceId = 1
  AND NULLIF(i.MbaReportNumber, N'') IS NULL;

SELECT @@ROWCOUNT AS RowsUpdated;

-- Expect this to match WouldBeUpdated from the dry run, and the format to be '2608737/1'.
SELECT TOP 20 OrderDetailsItemId, Doc, MbaReportNumber
FROM dbo.OrderDetailsItems
WHERE NULLIF(MbaReportNumber, N'') IS NOT NULL
ORDER BY OrderDetailsItemId DESC;

-- COMMIT TRANSACTION;
-- ROLLBACK TRANSACTION;
*/

DROP TABLE IF EXISTS #PriorityReportNumbers;
GO
