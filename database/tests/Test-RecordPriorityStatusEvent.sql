/*
    Tests for dbo.RecordPriorityStatusEvent                                                MBA-911
    ---------------------------------------------------------------------------------------------
    Run against a database where dbo.PriorityStatusWriteMode, dbo.PriorityStatusOutbox,
    dbo.PriorityCalibrationStatusCodes (seeded) and dbo.PriorityCalibrationStatusLog (refreshed at
    least once) are deployed. Anything other than 'PASS' in Result is a failure; 'SKIP' means the
    database has no suitable Doc for that section.

    Every write happens inside one transaction that is rolled back, so the file leaves the database
    as it found it - including the mode switch and the fake TX it adds to the log mirror. The two
    calls that are expected to THROW run in transactions of their own, because the procedure runs
    with XACT_ABORT ON and an error dooms the transaction it happens in.

    Picks its own rows:
      @Item      a device whose Doc Priority shows with no calibration-software step and no TX
                 (received, not yet calibrated): the app may open it.
      @ItemMaba  a device whose Doc already has calibration-software steps (MABA 2000 owns it).
      @ItemNoDoc a device with no Doc yet.
*/
SET NOCOUNT ON;

DECLARE @Out TABLE (Seq INT IDENTITY, Section NVARCHAR(14), Test NVARCHAR(70),
                    Expected NVARCHAR(60), Actual NVARCHAR(60), Result NVARCHAR(10));

DROP TABLE IF EXISTS #R;
CREATE TABLE #R (Seq INT IDENTITY, OutboxId INT, Doc INT, StatusCode CHAR(2), State VARCHAR(12),
                 Reason VARCHAR(40), IsDuplicate BIT);

DECLARE @Item INT, @Doc INT, @ItemMaba INT, @ItemNoDoc INT;

SELECT TOP (1) @Item = i.OrderDetailsItemId, @Doc = i.Doc
FROM dbo.OrderDetailsItems AS i
WHERE i.IsDeleted = 0 AND i.Doc IS NOT NULL
  AND (SELECT COUNT(*) FROM dbo.OrderDetailsItems x WHERE x.Doc = i.Doc AND x.IsDeleted = 0) = 1
  AND EXISTS (SELECT 1 FROM dbo.PriorityCalibrationStatusLog g WHERE g.Doc = i.Doc)
  AND NOT EXISTS (SELECT 1 FROM dbo.PriorityCalibrationStatusLog g
                  JOIN dbo.PriorityCalibrationStatusCodes c ON c.StatusCode = g.StatusCode
                  WHERE g.Doc = i.Doc AND (c.WrittenBy = 'CalibrationSoftware' OR g.StatusCode = 'TX'))
  AND NOT EXISTS (SELECT 1 FROM dbo.PriorityStatusOutbox o WHERE o.Doc = i.Doc)
ORDER BY i.OrderDetailsItemId DESC;

SELECT TOP (1) @ItemMaba = i.OrderDetailsItemId
FROM dbo.OrderDetailsItems AS i
WHERE i.IsDeleted = 0
  AND EXISTS (SELECT 1 FROM dbo.PriorityCalibrationStatusLog g
              WHERE g.Doc = i.Doc AND g.StatusCode = 'GR')
  AND NOT EXISTS (SELECT 1 FROM dbo.PriorityStatusOutbox o WHERE o.Doc = i.Doc)
ORDER BY i.OrderDetailsItemId DESC;

SELECT TOP (1) @ItemNoDoc = i.OrderDetailsItemId
FROM dbo.OrderDetailsItems AS i
WHERE i.IsDeleted = 0 AND i.Doc IS NULL
ORDER BY i.OrderDetailsItemId DESC;

DECLARE @Err NVARCHAR(400), @Before INT, @After INT, @FirstAC INT;

BEGIN TRAN;

/* Every test runs in ReportOnly, whatever the database is set to. */
UPDATE dbo.PriorityStatusWriteMode SET Mode = 'ReportOnly' WHERE Id = 1;

IF @Item IS NULL
    INSERT @Out VALUES (N'setup', N'a received, not yet calibrated Doc to open', N'found', N'none', N'SKIP');
ELSE
BEGIN
    /* ---- 1. opening, idempotency ------------------------------------------------------------- */
    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'AC', @EventKey = N't:ac:1';
    SELECT TOP (1) @FirstAC = OutboxId FROM #R ORDER BY Seq DESC;
    INSERT @Out SELECT TOP 1 N'1 open', N'AC is accepted', N'ReportOnly', State,
           CASE WHEN State = 'ReportOnly' THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;

    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'AC', @EventKey = N't:ac:1';
    INSERT @Out SELECT TOP 1 N'1 open', N'same key again returns the first row', N'duplicate of first',
           CONCAT(State, N' dup=', IsDuplicate),
           CASE WHEN IsDuplicate = 1 AND OutboxId = @FirstAC THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;

    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'ac', @EventKey = N't:ac:2';
    INSERT @Out SELECT TOP 1 N'1 open', N'a second AC (lower case code) is refused', N'ACAlreadyRecorded', Reason,
           CASE WHEN Reason = 'ACAlreadyRecorded' THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;

    /* ---- 2. report and signatures ------------------------------------------------------------ */
    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'H1', @EventKey = N't:h1:0';
    INSERT @Out SELECT TOP 1 N'2 report', N'H1 before any report is refused', N'H1WithoutReport', Reason,
           CASE WHEN Reason = 'H1WithoutReport' THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;

    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'GR', @EventKey = N't:gr:1';
    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'CD', @EventKey = N't:cd:1';
    INSERT @Out SELECT N'2 report', N'GR and the first CD are accepted', N'2 x ReportOnly',
           CONCAT(SUM(CASE WHEN State = 'ReportOnly' THEN 1 ELSE 0 END), N' x ReportOnly'),
           CASE WHEN SUM(CASE WHEN State = 'ReportOnly' THEN 1 ELSE 0 END) = 2 THEN N'PASS' ELSE N'FAIL' END
    FROM (SELECT TOP 2 State FROM #R ORDER BY Seq DESC) AS t;

    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'CD', @EventKey = N't:cd:2';
    INSERT @Out SELECT TOP 1 N'2 report', N'a second CD is refused', N'CDAlreadyRecorded', Reason,
           CASE WHEN Reason = 'CDAlreadyRecorded' THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;

    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'H2', @EventKey = N't:h2:0';
    INSERT @Out SELECT TOP 1 N'2 report', N'H2 before H1 is refused', N'H2WithoutH1', Reason,
           CASE WHEN Reason = 'H2WithoutH1' THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;

    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'H1', @EventKey = N't:h1:1';
    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'HR', @EventKey = N't:hr:1';
    INSERT @Out SELECT N'2 report', N'H1, then a rejection, are accepted', N'2 x ReportOnly',
           CONCAT(SUM(CASE WHEN State = 'ReportOnly' THEN 1 ELSE 0 END), N' x ReportOnly'),
           CASE WHEN SUM(CASE WHEN State = 'ReportOnly' THEN 1 ELSE 0 END) = 2 THEN N'PASS' ELSE N'FAIL' END
    FROM (SELECT TOP 2 State FROM #R ORDER BY Seq DESC) AS t;

    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'H1', @EventKey = N't:h1:2';
    INSERT @Out SELECT TOP 1 N'2 report', N'after HR, H1 needs a new report first', N'H1WithoutReport', Reason,
           CASE WHEN Reason = 'H1WithoutReport' THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;

    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'GR', @EventKey = N't:gr:2';
    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'H1', @EventKey = N't:h1:2';
    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'H2', @EventKey = N't:h2:1';
    INSERT @Out SELECT N'2 report', N'regenerated report, H1 (same key, now allowed), H2', N'3 x ReportOnly',
           CONCAT(SUM(CASE WHEN State = 'ReportOnly' THEN 1 ELSE 0 END), N' x ReportOnly'),
           CASE WHEN SUM(CASE WHEN State = 'ReportOnly' THEN 1 ELSE 0 END) = 3 THEN N'PASS' ELSE N'FAIL' END
    FROM (SELECT TOP 3 State FROM #R ORDER BY Seq DESC) AS t;

    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'HR', @EventKey = N't:hr:2';
    INSERT @Out SELECT TOP 1 N'2 report', N'HR after the second signature is refused', N'HRWithoutH1', Reason,
           CASE WHEN Reason = 'HRWithoutH1' THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;

    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'TX', @EventKey = N't:tx:1';
    INSERT @Out SELECT TOP 1 N'2 report', N'TX is Priority''s own code', N'NotAppCode', Reason,
           CASE WHEN Reason = 'NotAppCode' THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;

    /* ---- 3. holds ------------------------------------------------------------------------------ */
    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'DC', @EventKey = N't:dc:1';
    INSERT @Out SELECT TOP 1 N'3 hold', N'on hold (customer) is accepted', N'ReportOnly', State,
           CASE WHEN State = 'ReportOnly' THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;
    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'DM', @EventKey = N't:dm:1';
    INSERT @Out SELECT TOP 1 N'3 hold', N'a second hold is refused', N'AlreadyOnHold', Reason,
           CASE WHEN Reason = 'AlreadyOnHold' THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;
    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'FC', @EventKey = N't:fc:1';
    INSERT @Out SELECT TOP 1 N'3 hold', N'resume is accepted', N'ReportOnly', State,
           CASE WHEN State = 'ReportOnly' THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;
    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'FC', @EventKey = N't:fc:2';
    INSERT @Out SELECT TOP 1 N'3 hold', N'resume when not on hold is refused', N'NotOnHold', Reason,
           CASE WHEN Reason = 'NotOnHold' THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;

    /* ---- 4. after TX: only update reports ------------------------------------------------------ */
    INSERT INTO dbo.PriorityCalibrationStatusLog (Doc, Kline, StatusCode, StatusDate, LoadedAt)
    VALUES (@Doc, 9999, 'TX', SYSDATETIME(), SYSDATETIME());   /* rolled back with everything else */

    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'GR', @EventKey = N't:gr:3';
    INSERT @Out SELECT TOP 1 N'4 after TX', N'a normal report after TX is refused', N'LockedAfterTX', Reason,
           CASE WHEN Reason = 'LockedAfterTX' THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;
    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'UG', @EventKey = N't:ug:0';
    INSERT @Out SELECT TOP 1 N'4 after TX', N'update report generated before opened', N'UGWithoutUC', Reason,
           CASE WHEN Reason = 'UGWithoutUC' THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;
    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'UC', @EventKey = N't:uc:1',
                                                 @UpdateReportNumber = N'a';
    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'UG', @EventKey = N't:ug:1',
                                                 @UpdateReportNumber = N'a';
    INSERT @Out SELECT N'4 after TX', N'update report opened, then generated', N'2 x ReportOnly',
           CONCAT(SUM(CASE WHEN State = 'ReportOnly' THEN 1 ELSE 0 END), N' x ReportOnly'),
           CASE WHEN SUM(CASE WHEN State = 'ReportOnly' THEN 1 ELSE 0 END) = 2 THEN N'PASS' ELSE N'FAIL' END
    FROM (SELECT TOP 2 State FROM #R ORDER BY Seq DESC) AS t;

    /* ---- 5. the record ------------------------------------------------------------------------- */
    INSERT @Out SELECT N'5 record', N'every non-duplicate call left one row, refusals included',
           CONCAT((SELECT COUNT(*) FROM #R WHERE IsDuplicate = 0), N' rows'),
           CONCAT(COUNT(*), N' rows'),
           CASE WHEN COUNT(*) = (SELECT COUNT(*) FROM #R WHERE IsDuplicate = 0) THEN N'PASS' ELSE N'FAIL' END
    FROM dbo.PriorityStatusOutbox WHERE Doc = @Doc;

    INSERT @Out SELECT N'5 record', N'the update report number is carried', N'a',
           MAX(UpdateReportNumber),
           CASE WHEN MAX(UpdateReportNumber) = N'a' THEN N'PASS' ELSE N'FAIL' END
    FROM dbo.PriorityStatusOutbox WHERE Doc = @Doc AND StatusCode = 'UG' AND State = 'ReportOnly';

    /* ---- 6. the switch ------------------------------------------------------------------------- */
    UPDATE dbo.PriorityStatusWriteMode SET Mode = 'Off' WHERE Id = 1;
    SELECT @Before = COUNT(*) FROM dbo.PriorityStatusOutbox;
    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'UC', @EventKey = N't:uc:off';
    SELECT @After = COUNT(*) FROM dbo.PriorityStatusOutbox;
    INSERT @Out SELECT TOP 1 N'6 switch', N'Off records nothing', N'Off, 0 new rows',
           CONCAT(State, N', ', @After - @Before, N' new rows'),
           CASE WHEN State = 'Off' AND @After = @Before THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;
    UPDATE dbo.PriorityStatusWriteMode SET Mode = 'ReportOnly' WHERE Id = 1;
END

/* ---- 7. ownership ------------------------------------------------------------------------------ */
IF @ItemMaba IS NULL
    INSERT @Out VALUES (N'7 ownership', N'a Doc MABA 2000 has already worked on', N'found', N'none', N'SKIP');
ELSE
BEGIN
    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @ItemMaba, @StatusCode = 'AC', @EventKey = N't:own:ac';
    INSERT @Out SELECT TOP 1 N'7 ownership', N'opening a Doc MABA 2000 already worked on', N'OwnedByMABA2000', Reason,
           CASE WHEN Reason = 'OwnedByMABA2000' THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;
    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @ItemMaba, @StatusCode = 'GR', @EventKey = N't:own:gr';
    INSERT @Out SELECT TOP 1 N'7 ownership', N'any other step on it', N'NotOpenedInApp', Reason,
           CASE WHEN Reason = 'NotOpenedInApp' THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;
END

IF @ItemNoDoc IS NULL
    INSERT @Out VALUES (N'7 ownership', N'a device with no Doc', N'found', N'none', N'SKIP');
ELSE
BEGIN
    SELECT @Before = COUNT(*) FROM dbo.PriorityStatusOutbox;
    INSERT #R EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @ItemNoDoc, @StatusCode = 'AC', @EventKey = N't:nodoc';
    SELECT @After = COUNT(*) FROM dbo.PriorityStatusOutbox;
    INSERT @Out SELECT TOP 1 N'7 ownership', N'a device with no Doc is refused, not recorded', N'NoDoc, 0 new rows',
           CONCAT(Reason, N', ', @After - @Before, N' new rows'),
           CASE WHEN Reason = 'NoDoc' AND @After = @Before THEN N'PASS' ELSE N'FAIL' END FROM #R ORDER BY Seq DESC;
END

ROLLBACK;

/* ---- 8. broken calls throw, each in its own transaction ------------------------------------------ */
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = -1, @StatusCode = 'AC', @EventKey = N't:x';
    ROLLBACK;
    INSERT @Out VALUES (N'8 errors', N'unknown device row throws', N'error 51000', N'no error', N'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out VALUES (N'8 errors', N'unknown device row throws', N'error 51000',
                        CONCAT(N'error ', ERROR_NUMBER()),
                        CASE WHEN ERROR_NUMBER() = 51000 THEN N'PASS' ELSE N'FAIL' END);
END CATCH

BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.RecordPriorityStatusEvent @OrderDetailsItemId = @Item, @StatusCode = 'AC', @EventKey = N'  ';
    ROLLBACK;
    INSERT @Out VALUES (N'8 errors', N'an empty EventKey throws', N'error 51000', N'no error', N'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out VALUES (N'8 errors', N'an empty EventKey throws', N'error 51000',
                        CONCAT(N'error ', ERROR_NUMBER()),
                        CASE WHEN ERROR_NUMBER() = 51000 THEN N'PASS' ELSE N'FAIL' END);
END CATCH

BEGIN TRY
    BEGIN TRAN;
    UPDATE dbo.PriorityStatusWriteMode SET Mode = 'Send' WHERE Id = 1;
    ROLLBACK;
    INSERT @Out VALUES (N'8 errors', N'the switch cannot be set to Send yet', N'error 547', N'no error', N'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out VALUES (N'8 errors', N'the switch cannot be set to Send yet', N'error 547',
                        CONCAT(N'error ', ERROR_NUMBER()),
                        CASE WHEN ERROR_NUMBER() = 547 THEN N'PASS' ELSE N'FAIL' END);
END CATCH

SELECT Section, Test, Expected, Actual, Result FROM @Out ORDER BY Seq;
SELECT SUM(CASE WHEN Result = N'PASS' THEN 1 ELSE 0 END) AS Passed,
       SUM(CASE WHEN Result = N'FAIL' THEN 1 ELSE 0 END) AS Failed,
       SUM(CASE WHEN Result = N'SKIP' THEN 1 ELSE 0 END) AS Skipped
FROM @Out;
