/*
    Restoring device MABA Nos that the wizard overwrote, from Priority            (MBA-1002)
    ---------------------------------------------------------------------------------------------
    Two bugs wrote a wrong value over OrderDetailsItems.MbaReportNumber:

      1. dbo.GetOrderDetailsDevices, for a calibrator with no MABA prefix on the work plan,
         returned CONCAT(NULL, '', ROW_NUMBER()) = a bare '1', '2', ..., and page 1 saved it back.
         An older version of the same code put a '\' in front, which left '\1', '\11', ...
         Fixed in MBA-1002.
      2. dbo.AssignMeasurmentPointsToOrderDetailsItemsV2 wrote the smallest MABA No among ALL the
         device's sensor-table rows back onto the device, so a row with another device's number
         gave the device that number. Fixed in MBA-855 (PR #37).

    The fixes stop new damage; this script repairs what is already stored.

    SOURCE OF TRUTH: Priority amaba.dbo.MBA_DOCUMENTS.MBANUM, keyed by DOC = OrderDetailsItems.Doc,
    Source 1 (MABA) only - the same mapping and the same reasons as dbo.BackfillMbaReportNumber
    (sepharm's DOC sequence overlaps amaba's). DOC is unique in MBA_DOCUMENTS (1,896,773 rows with
    an MBANUM = 1,896,773 distinct DOCs, 2026-10-26).

    WHY THE HOURLY SYNC DOES NOT FIX IT: stg.MergeOrdersData does copy MBANUM (and the serial) onto
    every item still inside the stg_Orders window, every run. On STAGE that window held 398 items
    on 2026-10-26, and none of the damaged rows was among them. Outside the window nothing restores
    the value.

    Measured on STAGE 2026-10-26 (live Source 1 items with a Doc):
        5,425  match Priority                               left alone
           99  differ from Priority                         restored by this script
                 20 a bare 1-3 digit number   (bug 1)
                 73 '\n'                      (bug 1, older version)
                  5 'no slash': 5-digit values (20054, 12314, ...) on May test devices
                  1 another device's number: test device 'test3', which also has a report file
        Sensor rows carrying the same wrong value: 17 on the plan's items, 15 restored, 2 left
        because their OrderDetailsItemId is in the plan twice. Report files with it: 1.
           24  blank here, MBANUM in Priority               left alone: dbo.BackfillMbaReportNumber's job
           45  no MBANUM in Priority                        left alone
    Measured on PROD 2026-10-28: 9,915 match, 5 differ - items 514, 517, 519 ('\1'), 3921
    ('2603086\4', Priority says 2603086/1) and 2833 ('123'), all saved March-April 2026. None has
    sensor rows or report files, and no live device holds any of the five Priority numbers.
    Not repaired on PROD: 3 hand-added devices with no Doc (11268 '99', 11270 '1', 11285
    '260999252', serial '1234' on all three) - most likely test devices.

    Not repairable on STAGE: 160 devices with a damaged value and no Doc. All are IsManuallyAdded = 1,
    added in the app, so Priority has nothing to restore them from.

    WHAT IT CHANGES
      - OrderDetailsItems.MbaReportNumber := MBANUM, only where it is non-empty and differs.
      - With @IncludeSensorRows = 1 (default), that device's live sensor-table rows
        (MeasurmentPointsToOrderDetailsItems) that carry the SAME wrong value get MBANUM too. They
        were copied from the device; leaving them would make them look like another device's rows
        to the MBA-855 write-back and page-1 serial sync.
      - NOT the serial. Page 1 lets a user edit the serial on purpose (MBA-855 decisions), so a
        serial that differs from Priority is not evidence of damage.
      - NOT CalibrationReportFile / CalibrationReportSendLog. An issued report is a historical
        record; the plan only counts how many carry the wrong value so they can be looked at.

    ADDRESSED BY PRIORITY KEY. Items are found by Doc and Source, never by an id list; ids differ
    between STAGE and PROD. The primary key of OrderDetailsItems is (OrderDetailId,
    OrderDetailsItemId) - OrderDetailsItemId alone repeats - so the update joins on both.

    Run with @Apply = 0 first: the last result set is the plan, one row per item, touching nothing.
    @Apply = 1 writes inside one transaction and rolls back if the row count is not the plan's.
    A second run reports nothing to restore.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Apply             BIT = 0,
        @IncludeSensorRows BIT = 1;

/* 1. Priority's MABA Nos for the Doc range this database holds, pulled once. OPENQUERY keeps the
      filter on the Priority side; the range keeps it from dragging all 1.9M rows across. */
DROP TABLE IF EXISTS #Priority;
CREATE TABLE #Priority
(
    DOC    INT           NOT NULL PRIMARY KEY,
    MBANUM NVARCHAR(200) COLLATE DATABASE_DEFAULT NOT NULL
);

DECLARE @MinDoc INT = (SELECT MIN(Doc) FROM dbo.OrderDetailsItems WHERE Doc IS NOT NULL);
IF @MinDoc IS NULL
BEGIN
    RAISERROR('No item carries a Doc; nothing to compare.', 16, 1);
    RETURN;
END

DECLARE @Sql NVARCHAR(MAX) = N'
INSERT INTO #Priority (DOC, MBANUM)
SELECT DOC, MBANUM
FROM OPENQUERY([31.168.173.93],
    ''SELECT DOC, MBANUM FROM amaba.dbo.MBA_DOCUMENTS
      WHERE DOC >= ' + CAST(@MinDoc AS NVARCHAR(20)) + N' AND MBANUM > '''' '''' '');';
EXEC sys.sp_executesql @Sql;

/* 2. The plan: every live Source 1 item whose stored MABA No is non-empty and differs. */
DROP TABLE IF EXISTS #Plan;
SELECT  i.OrderDetailId,
        i.OrderDetailsItemId,
        i.Doc,
        i.MbaReportNumber AS StoredMbaNo,
        p.MBANUM          AS PriorityMbaNo,
        CASE
            WHEN i.MbaReportNumber NOT LIKE '%[^0-9]%' AND LEN(i.MbaReportNumber) <= 3 THEN 'bare number'
            WHEN i.MbaReportNumber LIKE '%\%'                                        THEN 'backslash'
            WHEN i.MbaReportNumber NOT LIKE '%[^0-9]%'                               THEN 'no slash'
            WHEN EXISTS (SELECT 1 FROM dbo.OrderDetailsItems o
                         WHERE o.IsDeleted = 0
                           AND o.MbaReportNumber = i.MbaReportNumber
                           AND NOT (o.OrderDetailId = i.OrderDetailId
                                    AND o.OrderDetailsItemId = i.OrderDetailsItemId)) THEN 'another device''s number'
            ELSE 'other'
        END AS Kind,
        i.SerialNumber,
        i.UpdatedDate,
        i.UpdateUserID,
        (SELECT COUNT(*) FROM dbo.MeasurmentPointsToOrderDetailsItems m
         WHERE m.OrderDetailsItemId = i.OrderDetailsItemId AND m.IsDeleted = 0
           AND m.MbaReportNumber = i.MbaReportNumber)       AS SensorRowsWithStoredNo,
        (SELECT COUNT(*) FROM dbo.CalibrationReportFile f
         WHERE f.OrderDetailsItemId = i.OrderDetailsItemId AND f.IsDeleted = 0
           AND f.MbaReportNumber = i.MbaReportNumber)       AS ReportFilesWithStoredNo
INTO #Plan
FROM dbo.OrderDetailsItems AS i
JOIN #Priority             AS p ON p.DOC = i.Doc
WHERE i.IsDeleted = 0
  AND NULLIF(i.MbaReportNumber, N'') IS NOT NULL
  AND i.MbaReportNumber COLLATE Latin1_General_100_BIN2 <> p.MBANUM COLLATE Latin1_General_100_BIN2
  /* EXISTS, not a join: one OrderDetailId can sit on two work plans, which would double the row. */
  AND EXISTS (SELECT 1
              FROM dbo.OrderDetails   AS od
              JOIN dbo.OrderWorkPlans AS wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
              WHERE od.OrderDetailId = i.OrderDetailId
                AND wp.SourceId = 1);   /* MABA only - see header */

/* Sensor rows and report files point at OrderDetailsItemId alone. When that id is in the plan
   twice (two order lines), the rows cannot be told apart, so they are left for a person. */
ALTER TABLE #Plan ADD SensorRowsSkipped BIT NOT NULL DEFAULT 0;
UPDATE p SET SensorRowsSkipped = 1
FROM #Plan AS p
WHERE (SELECT COUNT(*) FROM #Plan AS q WHERE q.OrderDetailsItemId = p.OrderDetailsItemId) > 1;

DECLARE @PlanItems      INT = (SELECT COUNT(*) FROM #Plan),
        @PlanSensorRows INT = (SELECT ISNULL(SUM(SensorRowsWithStoredNo), 0) FROM #Plan
                               WHERE SensorRowsSkipped = 0);

IF @Apply = 1 AND @PlanItems > 0
BEGIN
    BEGIN TRAN;

    UPDATE i
    SET    i.MbaReportNumber = p.PriorityMbaNo,
           i.UpdatedDate     = GETDATE()
    FROM   dbo.OrderDetailsItems AS i
    JOIN   #Plan                 AS p ON p.OrderDetailId      = i.OrderDetailId
                                     AND p.OrderDetailsItemId = i.OrderDetailsItemId
    WHERE  i.MbaReportNumber COLLATE Latin1_General_100_BIN2 = p.StoredMbaNo COLLATE Latin1_General_100_BIN2;

    IF @@ROWCOUNT <> @PlanItems
    BEGIN
        ROLLBACK;
        RAISERROR('Item row count differs from the plan; rolled back.', 16, 1);
        RETURN;
    END

    IF @IncludeSensorRows = 1
    BEGIN
        UPDATE m
        SET    m.MbaReportNumber = p.PriorityMbaNo,
               m.UpdatedDate     = GETDATE()
        FROM   dbo.MeasurmentPointsToOrderDetailsItems AS m
        JOIN   #Plan AS p ON p.OrderDetailsItemId = m.OrderDetailsItemId
                         AND p.SensorRowsSkipped  = 0
        WHERE  m.IsDeleted = 0
          AND  m.MbaReportNumber COLLATE Latin1_General_100_BIN2 = p.StoredMbaNo COLLATE Latin1_General_100_BIN2;

        IF @@ROWCOUNT <> @PlanSensorRows
        BEGIN
            ROLLBACK;
            RAISERROR('Sensor row count differs from the plan; rolled back.', 16, 1);
            RETURN;
        END
    END

    COMMIT;
END

SELECT CASE WHEN @Apply = 1 THEN 'APPLIED' ELSE 'DRY RUN' END AS Mode, *
FROM #Plan
ORDER BY Kind, Doc;
GO
