/*
    Tests for dbo.fnMasterForOrderItem, dbo.GetMasterForOrderItem, and saving by order item   MBA-816
    ---------------------------------------------------------------------------------------------
    Run against a database where these, dbo.SaveSensorCoefficients and
    dbo.SaveMasterSensorCorrectionsBatch are deployed. Anything other than 'PASS' in Result is a
    failure.

    Neither STAGE nor PROD has a single order for QCC (customer 1) yet, so there is no real item to
    test against. The file builds its own: a QCC order and another customer's order, with items
    whose serial numbers have the shapes found in Priority's 4,615 QCC records - '1-<MabaID>',
    '1-<MabaID>.' with a stray dot, other internal equipment that is no master. Everything is
    written inside transactions that are rolled back.
*/
SET NOCOUNT ON;

DECLARE @Out TABLE (Seq INT IDENTITY, Section NVARCHAR(12), Test NVARCHAR(90),
                    Expected NVARCHAR(60), Actual NVARCHAR(60), Result NVARCHAR(60));
DROP TABLE IF EXISTS #M;
CREATE TABLE #M (OrderDetailsItemId INT, SerialNumber NVARCHAR(100), CustomerCode NVARCHAR(20),
                 MabaID NVARCHAR(50), MeasurementDevicesId INT);
DROP TABLE IF EXISTS #C;
CREATE TABLE #C (Outcome NVARCHAR(10), ConversionParameterId INT, MeasurementDevicesId INT,
                 MabaID NVARCHAR(50), RTP DECIMAL(35,15), A4 DECIMAL(35,15), B4 DECIMAL(35,15),
                 A7 DECIMAL(35,15), B7 DECIMAL(35,15), C7 DECIMAL(35,15), OrderDetailsItemId INT);
DROP TABLE IF EXISTS #R;
CREATE TABLE #R (Outcome NVARCHAR(10), CorVersion INT, Source NVARCHAR(20), MeasurementId INT,
                 Value1 DECIMAL(25,15), Value2 DECIMAL(25,15), Deviation DECIMAL(35,15),
                 Equation NVARCHAR(300));

DECLARE @Email NVARCHAR(255) = (SELECT TOP (1) Email FROM dbo.Users WHERE Email IS NOT NULL ORDER BY ID);

/* QCC, by its Priority code; and one other customer */
DECLARE @QCC INT = (SELECT MIN(CustomerId) FROM dbo.Customers WHERE CustomerIdFromSource = 1);
DECLARE @OtherCust INT, @OtherCode NVARCHAR(20);
SELECT TOP (1) @OtherCust = CustomerId, @OtherCode = CAST(CustomerIdFromSource AS NVARCHAR(20))
FROM dbo.Customers WHERE CustomerIdFromSource > 100 ORDER BY CustomerIdFromSource;

/* a master whose MabaID is its own - 21-214 when it qualifies - a second one, and a shared MabaID */
DECLARE @Unique TABLE (Rn INT IDENTITY, ID INT, MabaID NVARCHAR(50));
INSERT @Unique (ID, MabaID)
SELECT TOP (2) MIN(md.ID), LTRIM(RTRIM(md.MabaID))
FROM dbo.MeasurementDevices AS md
WHERE md.IsDeleted = 0 AND LTRIM(RTRIM(md.MabaID)) LIKE N'[0-9]%-[0-9]%'
GROUP BY LTRIM(RTRIM(md.MabaID)) HAVING COUNT(*) = 1
ORDER BY CASE WHEN LTRIM(RTRIM(md.MabaID)) = N'21-214' THEN 0 ELSE 1 END, MIN(md.ID);
DECLARE @D1 INT, @M1 NVARCHAR(50), @D2 INT, @M2 NVARCHAR(50);
SELECT @D1 = ID, @M1 = MabaID FROM @Unique WHERE Rn = 1;
SELECT @D2 = ID, @M2 = MabaID FROM @Unique WHERE Rn = 2;

DECLARE @DupMaba NVARCHAR(50) =
    (SELECT TOP (1) LTRIM(RTRIM(MabaID)) FROM dbo.MeasurementDevices
     WHERE IsDeleted = 0 AND NULLIF(LTRIM(RTRIM(MabaID)), N'') IS NOT NULL
     GROUP BY LTRIM(RTRIM(MabaID)) HAVING COUNT(*) > 1);

/* the quantity to save ranges for: the master's own, or any, when it names none */
DECLARE @Meas INT = COALESCE((SELECT MeasurementId FROM dbo.MeasurementDevices WHERE ID = @D1),
                             (SELECT MIN(ID) FROM dbo.Measurements));

/* how many live devices share it - the function must return every one of them */
DECLARE @DupCount INT = (SELECT COUNT(*) FROM dbo.MeasurementDevices
                         WHERE IsDeleted = 0 AND LTRIM(RTRIM(MabaID)) = @DupMaba);

DECLARE @Points NVARCHAR(MAX) = N'[{"Reference":0,"Reading":0.03},{"Reference":100,"Reading":100.10}]';

/* the fixture, as a reusable batch of inserts */
DECLARE @Id INT;
DECLARE @WpQ INT, @WpO INT, @OdQ INT, @OdO INT;
DECLARE @Items TABLE (Label NVARCHAR(20) PRIMARY KEY, Serial NVARCHAR(100), Cust NVARCHAR(5), ItemId INT);
INSERT @Items (Label, Serial, Cust) VALUES
 (N'plain',     N'1-' + @M1,           N'QCC'),
 (N'dot',       N'1-' + @M1 + N'.',    N'QCC'),
 (N'dotspace',  N'1-' + @M1 + N'. ',   N'QCC'),
 (N'noprefix',  @M1,                   N'QCC'),
 (N'longer',    N'11-' + @M1,          N'QCC'),
 (N'equipment', N'1-#001',             N'QCC'),
 (N'shared',    N'1-' + ISNULL(@DupMaba, N'none'), N'QCC'),
 (N'other',     @OtherCode + N'-' + @M1, N'OTHER');


/* =============================================================================================
   Section 1 - reading the master off the serial number (no writes to what is read)
   ============================================================================================= */
BEGIN TRANSACTION;

INSERT dbo.OrderWorkPlans (CustomerId, OrderNumber, WorkPlanOpenDate, CreatedDate, IsCancelled)
VALUES (@QCC, N'TEST-MBA-816-QCC', GETDATE(), GETDATE(), 0);
SET @WpQ = SCOPE_IDENTITY();
INSERT dbo.OrderWorkPlans (CustomerId, OrderNumber, WorkPlanOpenDate, CreatedDate, IsCancelled)
VALUES (@OtherCust, N'TEST-MBA-816-OTHER', GETDATE(), GETDATE(), 0);
SET @WpO = SCOPE_IDENTITY();
INSERT dbo.OrderDetails (OrderWorkPlanId, CreatedDate, IsDeleted, IsCancelled) VALUES (@WpQ, GETDATE(), 0, 0);
SET @OdQ = SCOPE_IDENTITY();
INSERT dbo.OrderDetails (OrderWorkPlanId, CreatedDate, IsDeleted, IsCancelled) VALUES (@WpO, GETDATE(), 0, 0);
SET @OdO = SCOPE_IDENTITY();

DECLARE @L NVARCHAR(20), @S NVARCHAR(100), @Cu NVARCHAR(5);
DECLARE f CURSOR LOCAL FAST_FORWARD FOR SELECT Label, Serial, Cust FROM @Items;
OPEN f; FETCH f INTO @L, @S, @Cu;
WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT dbo.OrderDetailsItems (OrderDetailId, SerialNumber, CreatedDate, IsDeleted, IsCancelled, IsManuallyAdded)
    VALUES (CASE WHEN @Cu = N'QCC' THEN @OdQ ELSE @OdO END, @S, GETDATE(), 0, 0, 0);
    UPDATE @Items SET ItemId = SCOPE_IDENTITY() WHERE Label = @L;
    FETCH f INTO @L, @S, @Cu;
END;
CLOSE f; DEALLOCATE f;

/* what the function finds for each shape */
INSERT @Out
SELECT N'1 resolve', CONCAT(N'''', i.Serial, N''' -> ', e.Expect),
       e.Expect,
       ISNULL((SELECT CASE WHEN COUNT(*) > 1 THEN CONCAT(COUNT(*), N' devices')
                           ELSE MAX(m.MabaID) END
               FROM dbo.fnMasterForOrderItem(i.ItemId, N'1') AS m HAVING COUNT(*) > 0), N'no master'),
       CASE WHEN ISNULL((SELECT CASE WHEN COUNT(*) > 1 THEN CONCAT(COUNT(*), N' devices')
                                     ELSE MAX(m.MabaID) END
                         FROM dbo.fnMasterForOrderItem(i.ItemId, N'1') AS m HAVING COUNT(*) > 0), N'no master')
                 = e.Expect THEN N'PASS' ELSE N'FAIL' END
FROM @Items AS i
CROSS APPLY (SELECT Expect = CASE i.Label
                 WHEN N'plain'     THEN @M1
                 WHEN N'dot'       THEN @M1
                 WHEN N'dotspace'  THEN @M1
                 WHEN N'other'     THEN N'no master' /* not QCC's: a customer's asset number is never a lab MabaID */
                 WHEN N'shared'    THEN CASE WHEN @DupMaba IS NULL THEN N'no master' ELSE CONCAT(@DupCount, N' devices') END
                 ELSE N'no master' END) AS e      /* noprefix, longer ('11-' is not '1-'), equipment */
WHERE i.Label <> N'shared' OR @DupMaba IS NOT NULL;

/* the customer list is the gate: opened on purpose, the other customer's item resolves */
SELECT @Id = ItemId FROM @Items WHERE Label = N'other';
INSERT @Out SELECT N'1 resolve', N'...the other customer''s item resolves only when the list is opened (NULL)',
       @M1, ISNULL((SELECT MAX(m.MabaID) FROM dbo.fnMasterForOrderItem(@Id, NULL) AS m), N'no master'),
       CASE WHEN (SELECT MAX(m.MabaID) FROM dbo.fnMasterForOrderItem(@Id, NULL) AS m) = @M1
            THEN N'PASS' ELSE N'FAIL' END;

/* the button: QCC and exactly one master only */
SELECT @Id = ItemId FROM @Items WHERE Label = N'dot';
DELETE #M; INSERT #M EXEC dbo.GetMasterForOrderItem @OrderDetailsItemId = @Id;
INSERT @Out SELECT N'2 button', N'QCC master (with a stray dot): one row, the right device',
       CONCAT(N'1 row ', @D1), CONCAT(COUNT(*), N' row ', MAX(MeasurementDevicesId)),
       CASE WHEN COUNT(*) = 1 AND MAX(MeasurementDevicesId) = @D1 THEN N'PASS' ELSE N'FAIL' END FROM #M;

SELECT @Id = ItemId FROM @Items WHERE Label = N'equipment';
DELETE #M; INSERT #M EXEC dbo.GetMasterForOrderItem @OrderDetailsItemId = @Id;
INSERT @Out SELECT N'2 button', N'QCC equipment that is no master: no button',
       N'0 rows', CONCAT(COUNT(*), N' rows'), CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END FROM #M;

IF @DupMaba IS NOT NULL
BEGIN
    SELECT @Id = ItemId FROM @Items WHERE Label = N'shared';
    DELETE #M; INSERT #M EXEC dbo.GetMasterForOrderItem @OrderDetailsItemId = @Id;
    INSERT @Out SELECT N'2 button', CONCAT(N'shared MabaID ', @DupMaba, N': no button, not a guess'),
           N'0 rows', CONCAT(COUNT(*), N' rows'), CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END FROM #M;
END;

SELECT @Id = ItemId FROM @Items WHERE Label = N'other';
DELETE #M; INSERT #M EXEC dbo.GetMasterForOrderItem @OrderDetailsItemId = @Id;
INSERT @Out SELECT N'2 button', CONCAT(N'customer ', @OtherCode, N'''s master: no button by default (QCC only)'),
       N'0 rows', CONCAT(COUNT(*), N' rows'), CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END FROM #M;

DELETE #M; INSERT #M EXEC dbo.GetMasterForOrderItem @OrderDetailsItemId = @Id, @CustomerCodes = NULL;
INSERT @Out SELECT N'2 button', N'...and a button once every customer is allowed',
       CONCAT(N'1 row ', @D1), CONCAT(COUNT(*), N' row ', MAX(MeasurementDevicesId)),
       CASE WHEN COUNT(*) = 1 AND MAX(MeasurementDevicesId) = @D1 THEN N'PASS' ELSE N'FAIL' END FROM #M;

DECLARE @List NVARCHAR(200) = N'1, ' + @OtherCode;
DELETE #M; INSERT #M EXEC dbo.GetMasterForOrderItem @OrderDetailsItemId = @Id, @CustomerCodes = @List;
INSERT @Out SELECT N'2 button', CONCAT(N'...or when its code is on the list (''', @List, N''')'),
       N'1 row', CONCAT(COUNT(*), N' row'), CASE WHEN COUNT(*) = 1 THEN N'PASS' ELSE N'FAIL' END FROM #M;


/* =============================================================================================
   Section 3 - saving with nothing but the order item
   ============================================================================================= */
SELECT @Id = ItemId FROM @Items WHERE Label = N'plain';

DELETE #C;
INSERT #C EXEC dbo.SaveSensorCoefficients @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Id,
    @RTP = 100.0018614, @A4 = -0.0188349, @B4 = 0.00064590173677, @A7 = -0.01943119,
    @B7 = -0.00032928408, @C7 = 0.00022327774, @Apply = 1;
INSERT @Out SELECT N'3 by item', N'coefficients by item alone: saved against the item''s master',
       CONCAT(N'Saved ', @D1, N' ', @Id), CONCAT(c.Outcome, N' ', cp.MeasurementDevicesId, N' ', cp.OrderDetailsItemId),
       CASE WHEN c.Outcome = N'Saved' AND cp.MeasurementDevicesId = @D1 AND cp.OrderDetailsItemId = @Id
            THEN N'PASS' ELSE N'FAIL' END
FROM #C AS c JOIN dbo.ConversionParameters AS cp ON cp.ConversionParameterId = c.ConversionParameterId;

DELETE #R;
INSERT #R EXEC dbo.SaveMasterSensorCorrectionsBatch @LoggedInUserEmail = @Email, @Data = @Points,
    @MeasurementId = @Meas, @OrderDetailsItemId = @Id, @Apply = 0;
INSERT @Out SELECT N'3 by item', N'ranges by item alone: planned for the item''s master',
       N'1 new range, WouldSave', CONCAT(COUNT(*), N' new range, ', MIN(Outcome)),
       CASE WHEN COUNT(*) = 1 AND MIN(Outcome) = N'WouldSave' THEN N'PASS' ELSE N'FAIL' END
FROM #R WHERE Source = N'new';

/* an explicit MabaID wins over the item - the item then only records where the values came from */
DELETE #C;
INSERT #C EXEC dbo.SaveSensorCoefficients @LoggedInUserEmail = @Email, @MabaID = @M2,
    @OrderDetailsItemId = @Id, @RTP = 25.4011, @A4 = 0, @B4 = 0, @A7 = 0, @B7 = 0, @C7 = 0;
INSERT @Out SELECT N'3 by item', N'an explicit MabaID takes precedence over the item',
       CAST(@D2 AS NVARCHAR(12)), CAST(MeasurementDevicesId AS NVARCHAR(12)),
       CASE WHEN MeasurementDevicesId = @D2 THEN N'PASS' ELSE N'FAIL' END FROM #C;

/* last in this transaction: a refusal dooms it, and the rollback below is what cleans up */
DECLARE @Err NVARCHAR(400) = NULL;
SELECT @Id = ItemId FROM @Items WHERE Label = N'equipment';
BEGIN TRY
    DELETE #C;
    INSERT #C EXEC dbo.SaveSensorCoefficients @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Id,
        @RTP = 100, @A4 = 0, @B4 = 0, @A7 = 0, @B7 = 0, @C7 = 0, @Apply = 1;
END TRY
BEGIN CATCH
    SET @Err = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;   /* the refusal doomed it; roll back before writing results */
END CATCH;
INSERT @Out SELECT N'4 refuse', N'coefficients by an item that is no master: refused',
       N'an error', ISNULL(LEFT(@Err, 50), N'accepted'), CASE WHEN @Err IS NOT NULL THEN N'PASS' ELSE N'FAIL' END;

IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;


/* the same refusal from the ranges procedure needs the fixture again */
BEGIN TRANSACTION;
INSERT dbo.OrderWorkPlans (CustomerId, OrderNumber, WorkPlanOpenDate, CreatedDate, IsCancelled)
VALUES (@QCC, N'TEST-MBA-816-QCC', GETDATE(), GETDATE(), 0);
SET @WpQ = SCOPE_IDENTITY();
INSERT dbo.OrderDetails (OrderWorkPlanId, CreatedDate, IsDeleted, IsCancelled) VALUES (@WpQ, GETDATE(), 0, 0);
SET @OdQ = SCOPE_IDENTITY();
INSERT dbo.OrderDetailsItems (OrderDetailId, SerialNumber, CreatedDate, IsDeleted, IsCancelled, IsManuallyAdded)
VALUES (@OdQ, N'1-#001', GETDATE(), 0, 0, 0);
SET @Id = SCOPE_IDENTITY();

SET @Err = NULL;
BEGIN TRY
    DELETE #R;
    INSERT #R EXEC dbo.SaveMasterSensorCorrectionsBatch @LoggedInUserEmail = @Email, @Data = @Points,
        @OrderDetailsItemId = @Id, @Apply = 1;
END TRY
BEGIN CATCH
    SET @Err = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;   /* the refusal doomed it; roll back before writing results */
END CATCH;
INSERT @Out SELECT N'4 refuse', N'ranges by an item that is no master: refused',
       N'an error', ISNULL(LEFT(@Err, 50), N'accepted'), CASE WHEN @Err IS NOT NULL THEN N'PASS' ELSE N'FAIL' END;

IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;


/* a non-QCC item whose serial matches a lab MabaID once its prefix is removed: the save must
   refuse it exactly as the button hides it - otherwise the customer's calibration lands on the
   lab's master (PR #18 review). One fixture per refusal, since each refusal dooms its transaction. */
DECLARE @Proc NVARCHAR(40);
DECLARE r CURSOR LOCAL FAST_FORWARD FOR SELECT p FROM (VALUES (N'coefficients'), (N'ranges')) AS v (p);
OPEN r; FETCH r INTO @Proc;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRANSACTION;
    INSERT dbo.OrderWorkPlans (CustomerId, OrderNumber, WorkPlanOpenDate, CreatedDate, IsCancelled)
    VALUES (@OtherCust, N'TEST-MBA-816-OTHER', GETDATE(), GETDATE(), 0);
    SET @WpO = SCOPE_IDENTITY();
    INSERT dbo.OrderDetails (OrderWorkPlanId, CreatedDate, IsDeleted, IsCancelled) VALUES (@WpO, GETDATE(), 0, 0);
    SET @OdO = SCOPE_IDENTITY();
    INSERT dbo.OrderDetailsItems (OrderDetailId, SerialNumber, CreatedDate, IsDeleted, IsCancelled, IsManuallyAdded)
    VALUES (@OdO, @OtherCode + N'-' + @M1, GETDATE(), 0, 0, 0);
    SET @Id = SCOPE_IDENTITY();

    SET @Err = NULL;
    BEGIN TRY
        IF @Proc = N'coefficients'
        BEGIN
            DELETE #C;
            INSERT #C EXEC dbo.SaveSensorCoefficients @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Id,
                @RTP = 100, @A4 = 0, @B4 = 0, @A7 = 0, @B7 = 0, @C7 = 0, @Apply = 1;
        END
        ELSE
        BEGIN
            DELETE #R;
            INSERT #R EXEC dbo.SaveMasterSensorCorrectionsBatch @LoggedInUserEmail = @Email, @Data = @Points,
                @MeasurementId = @Meas, @OrderDetailsItemId = @Id, @Apply = 1;
        END
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END CATCH;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

    INSERT @Out SELECT N'4 refuse', CONCAT(@Proc, N' by customer ', @OtherCode, N'''s item ''', @OtherCode, N'-', @M1, N''': refused'),
           N'an error', ISNULL(LEFT(@Err, 50), N'accepted'), CASE WHEN @Err IS NOT NULL THEN N'PASS' ELSE N'FAIL' END;
    FETCH r INTO @Proc;
END;
CLOSE r; DEALLOCATE r;


/* ============================================================================================= */
INSERT @Out SELECT N'5 cleanup', N'no test order is left behind',
       N'0', CAST(COUNT(*) AS NVARCHAR(12)), CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END
FROM dbo.OrderWorkPlans WHERE OrderNumber LIKE N'TEST-MBA-816-%';

SELECT Section, Test, Expected, Actual, Result FROM @Out ORDER BY Seq;

DECLARE @Fail INT = (SELECT COUNT(*) FROM @Out WHERE Result LIKE N'FAIL%');
SELECT Summary = CASE WHEN @Fail = 0 THEN N'ALL PASS'
                      ELSE CAST(@Fail AS NVARCHAR(10)) + N' FAILING' END,
       Cases   = (SELECT COUNT(*) FROM @Out),
       Master  = @M1, OtherCustomer = @OtherCode, SharedMabaID = @DupMaba;
