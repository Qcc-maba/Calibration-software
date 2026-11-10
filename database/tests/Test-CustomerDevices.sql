/*
    Tests for the device entity                                                          MBA-996
    ---------------------------------------------------------------------------------------------
    dbo.CustomerDevices (its unique and foreign-key rules), dbo.trCustomerDevices_PriorityOwned,
    dbo.vwCustomerDevices and the claim step of dbo.RefreshCustomerDevicesFromPriority.

    Run against a database where all of them are deployed and the refresh has loaded the register
    at least once (EXEC dbo.RefreshCustomerDevicesFromPriority @Apply = 1). Anything other than
    'PASS' in Result is a failure; 'SKIP' means the database has no suitable row for that test.

    EVERY TEST RUNS IN ITS OWN TRANSACTION AND IS ROLLED BACK. An error thrown inside a trigger
    always dooms the transaction around it, whatever XACT_ABORT says, so the refusal tests cannot
    share one: each does its setup, tries the statement, records the error number, and rolls back.
    Results go to a table variable, which a rollback does not touch. The file leaves the database
    as it found it.

    The claim tests call the refresh, which reads Priority over the linked server (one incremental
    round-trip each) and prints its own result sets before the table below.

    Markers: test values start with 'MBA996T-' - no Priority serial or model does.

    Picks its own rows:
      @Dev    the registered device Priority changed most recently, whose serial carries its
              customer's code prefix: an incremental refresh is certain to fetch it again.
      @OtherSite  a site of a customer other than @Dev's.
*/
SET NOCOUNT ON;
SET XACT_ABORT OFF;

DECLARE @Out TABLE (Seq INT IDENTITY, Section NVARCHAR(10), Test NVARCHAR(80),
                    Expected NVARCHAR(40), Actual NVARCHAR(60), Result NVARCHAR(6));

DECLARE @Dev INT, @Sern INT, @Cust INT, @Serial NVARCHAR(50), @Body NVARCHAR(50),
        @OtherSite INT, @Typed INT, @Typed2 INT, @Err INT, @n INT, @n2 INT, @v NVARCHAR(60), @Flag NVARCHAR(40);

SELECT TOP (1) @Dev = d.CustomerDeviceID, @Sern = d.SERN, @Cust = d.CustomerId, @Serial = d.SerialNumber,
               @Body = SUBSTRING(d.SerialNumber, LEN(c.CustomerCode) + 2, 50)
FROM dbo.CustomerDevices AS d
JOIN dbo.Customers AS c ON c.CustomerId = d.CustomerId
WHERE d.SERN IS NOT NULL AND d.IsInactiveInSource = 0 AND d.IsDeleted = 0 AND c.IsInactiveInSource = 0
  AND d.SerialNumber LIKE c.CustomerCode + N'-%' AND LEN(d.SerialNumber) > LEN(c.CustomerCode) + 3
ORDER BY d.SourceUpdatedAt DESC, d.SERN DESC;

SELECT TOP (1) @OtherSite = s.CustomerSiteId FROM dbo.CustomerSites AS s WHERE s.CustomerId <> @Cust;

IF @Dev IS NULL
BEGIN
    SELECT Result = 'SKIP', Reason = 'no registered device loaded - run the refresh first';
    RETURN;
END

/* ============================== trigger ============================== */

/* T1: each Priority-owned field of a registered device, without the refresh's flag */
DECLARE @Cols TABLE (c SYSNAME);
INSERT @Cols VALUES (N'Model'), (N'SerialNumber'), (N'OrdersDeviceManufacturer'), (N'CalibrationIntervalMonths'),
                    (N'NextCalibrationDate'), (N'OrdersProductTypeId'), (N'DeviceDescription'),
                    (N'IsInactiveInSource'), (N'SERN');
DECLARE @c SYSNAME, @sql NVARCHAR(400), @refused INT = 0, @tried INT = 0;
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT c FROM @Cols;
OPEN cur; FETCH NEXT FROM cur INTO @c;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'UPDATE dbo.CustomerDevices SET ' + QUOTENAME(@c) + N' = '
             + CASE @c WHEN N'CalibrationIntervalMonths' THEN N'ISNULL(CalibrationIntervalMonths, 0) % 200 + 1'
                       WHEN N'NextCalibrationDate'       THEN N'''2099-01-01'''
                       WHEN N'OrdersProductTypeId'       THEN N'(SELECT MIN(OrdersProductTypeId) FROM dbo.OrdersProductTypes)'
                       WHEN N'IsInactiveInSource'        THEN N'1 - IsInactiveInSource'
                       WHEN N'SERN'                      THEN N'2147483000'
                       ELSE N'N''MBA996T-' + @c + N'''' END
             + N' WHERE CustomerDeviceID = @d';
    SET @tried += 1;
    BEGIN TRAN;
    BEGIN TRY EXEC sys.sp_executesql @sql, N'@d INT', @Dev; END TRY
    BEGIN CATCH IF ERROR_NUMBER() = 54208 SET @refused += 1; END CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    FETCH NEXT FROM cur INTO @c;
END
CLOSE cur; DEALLOCATE cur;
INSERT @Out VALUES (N'trigger', N'registered: each Priority-owned field is refused (54208)',
                    CONCAT(@tried, N' of ', @tried), CONCAT(@refused, N' of ', @tried),
                    CASE WHEN @refused = @tried THEN 'PASS' ELSE 'FAIL' END);

/* T2: a portal-owned field of a registered device is fine */
SET @Err = 0;
BEGIN TRAN;
BEGIN TRY UPDATE dbo.CustomerDevices SET DeviceLocation = N'MBA996T-LAB' WHERE CustomerDeviceID = @Dev; END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out VALUES (N'trigger', N'registered: changing DeviceLocation is allowed', N'0', CAST(@Err AS NVARCHAR(10)),
                    CASE WHEN @Err = 0 THEN 'PASS' ELSE 'FAIL' END);

/* T3: nobody but the refresh inserts a registered row */
SET @Err = 0;
BEGIN TRAN;
BEGIN TRY INSERT dbo.CustomerDevices (CustomerId, SERN, SerialNumber) VALUES (@Cust, 2147483000, N'MBA996T-SERN'); END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out VALUES (N'trigger', N'inserting a row with SERN is refused', N'54208', CAST(@Err AS NVARCHAR(10)),
                    CASE WHEN @Err = 54208 THEN 'PASS' ELSE 'FAIL' END);

/* T4: a typed row can be inserted and edited freely */
SET @Err = 0; SET @Typed = NULL;
BEGIN TRAN;
BEGIN TRY
    INSERT dbo.CustomerDevices (CustomerId, SerialNumber, Model) VALUES (@Cust, N'  mba996t-typed-001 ', N'MBA996T-M1');
    SET @Typed = SCOPE_IDENTITY();
    UPDATE dbo.CustomerDevices SET Model = N'MBA996T-M2', SerialNumber = N'mba996t-typed-001' WHERE CustomerDeviceID = @Typed;
END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out VALUES (N'trigger', N'typed: insert, then edit Model and SerialNumber', N'0', CAST(@Err AS NVARCHAR(10)),
                    CASE WHEN @Err = 0 AND @Typed IS NOT NULL THEN 'PASS' ELSE 'FAIL' END);

/* T5: but not set its SERN by hand - claiming is the refresh's job */
SET @Err = 0;
BEGIN TRAN;
INSERT dbo.CustomerDevices (CustomerId, SerialNumber) VALUES (@Cust, N'MBA996T-TYPED-001');
SET @Typed = SCOPE_IDENTITY();
BEGIN TRY UPDATE dbo.CustomerDevices SET SERN = 2147483000 WHERE CustomerDeviceID = @Typed; END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out VALUES (N'trigger', N'typed: setting SERN by hand is refused', N'54208', CAST(@Err AS NVARCHAR(10)),
                    CASE WHEN @Err = 54208 THEN 'PASS' ELSE 'FAIL' END);

/* T6: rows are never deleted */
SET @Err = 0;
BEGIN TRAN;
INSERT dbo.CustomerDevices (CustomerId, SerialNumber) VALUES (@Cust, N'MBA996T-TYPED-001');
SET @Typed = SCOPE_IDENTITY();
BEGIN TRY DELETE FROM dbo.CustomerDevices WHERE CustomerDeviceID = @Typed; END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out VALUES (N'trigger', N'DELETE is refused', N'54208', CAST(@Err AS NVARCHAR(10)),
                    CASE WHEN @Err = 54208 THEN 'PASS' ELSE 'FAIL' END);

/* ============================== table rules ============================== */

/* T7: one typed device per customer and serial - SerialKey ignores case and outer spaces */
SET @Err = 0;
BEGIN TRAN;
INSERT dbo.CustomerDevices (CustomerId, SerialNumber) VALUES (@Cust, N'mba996t-typed-001');
BEGIN TRY INSERT dbo.CustomerDevices (CustomerId, SerialNumber) VALUES (@Cust, N' MBA996T-TYPED-001  '); END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out VALUES (N'table', N'typed: the same serial twice for one customer', N'2601', CAST(@Err AS NVARCHAR(10)),
                    CASE WHEN @Err IN (2601, 2627) THEN 'PASS' ELSE 'FAIL' END);

/* T8: ... but a hidden one does not block it */
SET @Err = 0;
BEGIN TRAN;
INSERT dbo.CustomerDevices (CustomerId, SerialNumber, IsDeleted) VALUES (@Cust, N'MBA996T-TYPED-001', 1);
BEGIN TRY INSERT dbo.CustomerDevices (CustomerId, SerialNumber) VALUES (@Cust, N'MBA996T-TYPED-001'); END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out VALUES (N'table', N'typed: same serial again when the first one is hidden', N'0', CAST(@Err AS NVARCHAR(10)),
                    CASE WHEN @Err = 0 THEN 'PASS' ELSE 'FAIL' END);

/* T9: a site must belong to the device's own customer */
IF @OtherSite IS NULL
    INSERT @Out VALUES (N'table', N'site of another customer is refused', N'547', N'-', 'SKIP');
ELSE
BEGIN
    SET @Err = 0;
    BEGIN TRAN;
    BEGIN TRY INSERT dbo.CustomerDevices (CustomerId, SerialNumber, CustomerSiteId) VALUES (@Cust, N'MBA996T-TYPED-002', @OtherSite); END TRY
    BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out VALUES (N'table', N'site of another customer is refused', N'547', CAST(@Err AS NVARCHAR(10)),
                        CASE WHEN @Err = 547 THEN 'PASS' ELSE 'FAIL' END);
END

/* ============================== view ============================== */

BEGIN TRAN;
INSERT dbo.CustomerDevices (CustomerId, SerialNumber) VALUES (@Cust, N'MBA996T-TYPED-003');
SET @Typed = SCOPE_IDENTITY();
INSERT dbo.CustomerDevices (CustomerId, SerialNumber, IsDeleted) VALUES (@Cust, N'MBA996T-TYPED-004', 1);
SET @Typed2 = SCOPE_IDENTITY();

/* T10: a typed device shows at once, unregistered, with no visits */
SELECT @n = COUNT(*), @v = MAX(CONCAT(CAST(IsRegistered AS INT), N'/', VisitCount, N'/',
                                      ISNULL(CAST(LatestOrderDetailsItemId AS NVARCHAR(12)), N'null')))
FROM dbo.vwCustomerDevices WHERE CustomerDeviceID = @Typed;

/* T11: a hidden device is not */
SELECT @n2 = COUNT(*) FROM dbo.vwCustomerDevices WHERE CustomerDeviceID = @Typed2;
ROLLBACK;

INSERT @Out VALUES (N'view', N'typed device: shown; IsRegistered/VisitCount/LatestVisit', N'1 row 0/0/null', CONCAT(@n, N' row ', @v),
                    CASE WHEN @n = 1 AND @v = N'0/0/null' THEN 'PASS' ELSE 'FAIL' END);
INSERT @Out VALUES (N'view', N'hidden (IsDeleted) device is not shown', N'0', CAST(@n2 AS NVARCHAR(10)),
                    CASE WHEN @n2 = 0 THEN 'PASS' ELSE 'FAIL' END);

/* T12: a registered device is shown exactly when it has a visit under its own customer */
SELECT @n = COUNT(*) FROM dbo.CustomerDevices AS d
WHERE d.SERN IS NOT NULL AND d.IsDeleted = 0 AND d.IsInactiveInSource = 0
  AND (CASE WHEN EXISTS (SELECT 1 FROM dbo.OrderDetailsItems i
                         JOIN dbo.OrderDetails od ON od.OrderDetailId = i.OrderDetailId
                         JOIN dbo.OrderWorkPlans wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
                         WHERE i.SERN = d.SERN AND i.IsDeleted = 0 AND wp.CustomerId = d.CustomerId)
            THEN 1 ELSE 0 END)
   <> (CASE WHEN EXISTS (SELECT 1 FROM dbo.vwCustomerDevices v WHERE v.CustomerDeviceID = d.CustomerDeviceID)
            THEN 1 ELSE 0 END)
  AND d.CustomerId IN (SELECT TOP (20) wp.CustomerId FROM dbo.OrderWorkPlans wp GROUP BY wp.CustomerId ORDER BY COUNT(*) DESC);
INSERT @Out VALUES (N'view', N'registered devices of the 20 busiest customers: shown iff visited', N'0 mismatches', CONCAT(@n, N' mismatches'),
                    CASE WHEN @n = 0 THEN 'PASS' ELSE 'FAIL' END);

/* ============================== claim (calls the refresh) ============================== */

/* T13-T15: @Dev turned back into a typed row - as if the customer had typed it before MABA
   registered it - with the serial as a customer types it: no "<CustomerCode>-" prefix, lower
   case. The refresh's flag is set for that one statement only. */
SET @Err = 0;
BEGIN TRAN;
BEGIN TRY
    EXEC sys.sp_set_session_context N'CustomerDevices.Writer', N'PriorityRefresh';
    UPDATE dbo.CustomerDevices
       SET SERN = NULL, SerialNumber = LOWER(@Body), DevicePart = NULL, DeviceTypeName = NULL, DeviceDescription = NULL,
           SourceUpdatedAt = NULL, RefreshedAt = NULL, CustomerSiteId = NULL, DeviceLocation = N'MBA996T-KEEP'
     WHERE CustomerDeviceID = @Dev;
    EXEC sys.sp_set_session_context N'CustomerDevices.Writer', NULL;

    EXEC dbo.RefreshCustomerDevicesFromPriority @Apply = 1;
    SET @Flag = ISNULL(CAST(SESSION_CONTEXT(N'CustomerDevices.Writer') AS NVARCHAR(40)), N'null');

    SELECT @v = CONCAT(ISNULL(CAST(SERN AS NVARCHAR(12)), N'null'), N'/', DeviceLocation, N'/', CAST(NeedsReview AS INT))
    FROM dbo.CustomerDevices WHERE CustomerDeviceID = @Dev;
    SELECT @n = COUNT(*) FROM dbo.CustomerDevices WHERE SERN = @Sern;
    SELECT @Body = SerialNumber FROM dbo.CustomerDevices WHERE CustomerDeviceID = @Dev;  /* reused: the serial after the claim */
END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); SET @v = LEFT(ERROR_MESSAGE(), 60); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
EXEC sys.sp_set_session_context N'CustomerDevices.Writer', NULL;

INSERT @Out VALUES (N'claim', N'typed row without prefix is claimed: SERN/kept field/review, rows',
                    CONCAT(@Sern, N'/MBA996T-KEEP/0, 1'), CONCAT(@v, N', ', @n),
                    CASE WHEN @Err = 0 AND @v = CONCAT(@Sern, N'/MBA996T-KEEP/0') AND @n = 1 THEN 'PASS' ELSE 'FAIL' END);
INSERT @Out VALUES (N'claim', N'the claimed row carries Priority''s SERNUM again', LEFT(@Serial, 40), LEFT(@Body, 60),
                    CASE WHEN @Body = @Serial COLLATE Latin1_General_100_BIN2 THEN 'PASS' ELSE 'FAIL' END);

/* T16: two typed rows that both match: neither is claimed, both flagged, Priority's device added */
SET @Err = 0; SET @n = NULL; SET @n2 = NULL;
SET @Body = SUBSTRING(@Serial, CHARINDEX(N'-', @Serial) + 1, 50);
BEGIN TRAN;
BEGIN TRY
    EXEC sys.sp_set_session_context N'CustomerDevices.Writer', N'PriorityRefresh';
    UPDATE dbo.CustomerDevices
       SET SERN = NULL, SerialNumber = @Body, DevicePart = NULL, DeviceTypeName = NULL, DeviceDescription = NULL,
           SourceUpdatedAt = NULL, RefreshedAt = NULL
     WHERE CustomerDeviceID = @Dev;
    EXEC sys.sp_set_session_context N'CustomerDevices.Writer', NULL;
    INSERT dbo.CustomerDevices (CustomerId, SerialNumber) VALUES (@Cust, @Serial);   /* the full SERNUM */
    SET @Typed = SCOPE_IDENTITY();

    EXEC dbo.RefreshCustomerDevicesFromPriority @Apply = 1;

    SELECT @n = COUNT(*) FROM dbo.CustomerDevices WHERE CustomerDeviceID IN (@Dev, @Typed) AND SERN IS NULL AND NeedsReview = 1;
    SELECT @n2 = COUNT(*) FROM dbo.CustomerDevices WHERE SERN = @Sern AND CustomerDeviceID NOT IN (@Dev, @Typed);
END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
EXEC sys.sp_set_session_context N'CustomerDevices.Writer', NULL;

INSERT @Out VALUES (N'claim', N'ambiguous: both typed rows flagged, Priority''s added as its own row',
                    N'2 flagged, 1 added', CONCAT(@n, N' flagged, ', @n2, N' added', CASE WHEN @Err <> 0 THEN CONCAT(N', error ', @Err) END),
                    CASE WHEN @Err = 0 AND @n = 2 AND @n2 = 1 THEN 'PASS' ELSE 'FAIL' END);

/* T17: the refresh that wrote (T13) left no writer flag behind on the connection */
INSERT @Out VALUES (N'claim', N'session flag cleared after a writing refresh', N'null', @Flag,
                    CASE WHEN @Flag = N'null' THEN 'PASS' ELSE 'FAIL' END);

SELECT Section, Test, Expected, Actual, Result FROM @Out ORDER BY Seq;
SELECT Passed  = SUM(CASE WHEN Result = 'PASS' THEN 1 ELSE 0 END),
       Failed  = SUM(CASE WHEN Result = 'FAIL' THEN 1 ELSE 0 END),
       Skipped = SUM(CASE WHEN Result = 'SKIP' THEN 1 ELSE 0 END)
FROM @Out;
