/*
    Tests for the Report screen's saved display options                                    MBA-1004
    ---------------------------------------------------------------------------------------------
    dbo.OrderDetailsItems.ShouldShowPercentOfSpec, dbo.SetReportDisplayOptions, and the column in
    dbo.GetOrderDetailsDevices' result.

    Run against a database where the column and both procedures are deployed. Anything other than
    'PASS' in Result is a failure, except 'SKIP', which only appears when the database has no
    example of that case (no duplicated OrderDetailsItemId, no inactive user) and says so.
    Every write happens inside a transaction that is rolled back, so the file leaves the database
    as it found it. Each refusal runs in a transaction of its own, because the procedure runs with
    XACT_ABORT ON and an error dooms the transaction it happens in.
*/
SET NOCOUNT ON;

DECLARE @Out TABLE (Seq INT IDENTITY, Test NVARCHAR(90), Expected NVARCHAR(70), Actual NVARCHAR(200),
                    Result NVARCHAR(10));

DROP TABLE IF EXISTS #R;
CREATE TABLE #R (OrderDetailId INT, OrderDetailsItemId INT, ShouldShowPercentOfSpec BIT, Outcome NVARCHAR(10));

DECLARE @Email NVARCHAR(255), @UserId INT;
SELECT TOP (1) @Email = u.Email, @UserId = u.ID
FROM dbo.Users AS u
WHERE u.Email IS NOT NULL AND u.IsActive = 1 AND u.ID > 0   /* 0 is the procs' "no user" sentinel */
  AND NOT EXISTS (SELECT 1 FROM dbo.Users AS d WHERE d.Email = u.Email AND d.ID <> u.ID)
ORDER BY u.ID;

/* a live, unchecked, unsigned line */
DECLARE @Od INT, @Item INT;
SELECT TOP (1) @Od = i.OrderDetailId, @Item = i.OrderDetailsItemId
FROM dbo.OrderDetailsItems AS i
WHERE i.IsDeleted = 0 AND i.ShouldShowPercentOfSpec = 0 AND i.RemarksLockedDate IS NULL
ORDER BY i.OrderDetailsItemId DESC;

DECLARE @Err NVARCHAR(400), @V NVARCHAR(200);

INSERT @Out SELECT N'a test user and a test line were found', N'both found',
       CONCAT('user=', @UserId, ' line=', @Od, '/', @Item),
       CASE WHEN @UserId IS NOT NULL AND @Item IS NOT NULL THEN N'PASS' ELSE N'FAIL' END;

/* ---- the column ------------------------------------------------------------------------------ */
SELECT @V = CONCAT('nullable=', c.is_nullable, ' default=', dc.definition)
FROM sys.columns AS c
LEFT JOIN sys.default_constraints AS dc ON dc.object_id = c.default_object_id
WHERE c.object_id = OBJECT_ID('dbo.OrderDetailsItems') AND c.name = 'ShouldShowPercentOfSpec';
INSERT @Out SELECT N'column is NOT NULL with default 0', N'nullable=0 default=((0))', @V,
       CASE WHEN @V = N'nullable=0 default=((0))' THEN N'PASS' ELSE N'FAIL' END;

/* ---- the read procedure returns it, never NULL ----------------------------------------------- */
SELECT @V = MAX(CONCAT(name, ':', system_type_name, ' nullable=', CAST(is_nullable AS INT)))
FROM sys.dm_exec_describe_first_result_set(N'EXEC dbo.GetOrderDetailsDevices @OrderWorkPlanId = 1', NULL, 0)
WHERE name = 'ShouldShowPercentOfSpec';
INSERT @Out SELECT N'GetOrderDetailsDevices returns it as a non-null bit', N'ShouldShowPercentOfSpec:bit nullable=0', @V,
       CASE WHEN @V = N'ShouldShowPercentOfSpec:bit nullable=0' THEN N'PASS' ELSE N'FAIL' END;

IF @UserId IS NOT NULL AND @Item IS NOT NULL
BEGIN
    /* ---- writes, rolled back ----------------------------------------------------------------- */
    DECLARE @Updated DATETIME;
    BEGIN TRANSACTION;

        SELECT @Updated = UpdatedDate FROM dbo.OrderDetailsItems WHERE OrderDetailId = @Od AND OrderDetailsItemId = @Item;

        INSERT #R EXEC dbo.SetReportDisplayOptions @Email, @Od, @Item, 1;
        INSERT @Out SELECT N'check it', N'1 Updated', CONCAT(ShouldShowPercentOfSpec, ' ', Outcome),
               CASE WHEN ShouldShowPercentOfSpec = 1 AND Outcome = N'Updated'
                     AND (SELECT ShouldShowPercentOfSpec FROM dbo.OrderDetailsItems
                          WHERE OrderDetailId = @Od AND OrderDetailsItemId = @Item) = 1
                    THEN N'PASS' ELSE N'FAIL' END
        FROM #R;
        DELETE #R;

        INSERT #R EXEC dbo.SetReportDisplayOptions @Email, @Od, @Item, 1;
        INSERT @Out SELECT N'check it again is idempotent', N'1 NoChange', CONCAT(ShouldShowPercentOfSpec, ' ', Outcome),
               CASE WHEN ShouldShowPercentOfSpec = 1 AND Outcome = N'NoChange' THEN N'PASS' ELSE N'FAIL' END
        FROM #R;
        DELETE #R;

        INSERT #R EXEC dbo.SetReportDisplayOptions @Email, @Od, @Item, NULL;
        INSERT @Out SELECT N'NULL keeps the stored value', N'1 NoChange', CONCAT(ShouldShowPercentOfSpec, ' ', Outcome),
               CASE WHEN ShouldShowPercentOfSpec = 1 AND Outcome = N'NoChange' THEN N'PASS' ELSE N'FAIL' END
        FROM #R;
        DELETE #R;

        INSERT #R EXEC dbo.SetReportDisplayOptions @Email, @Od, @Item, 0;
        INSERT @Out SELECT N'uncheck it', N'0 Updated', CONCAT(ShouldShowPercentOfSpec, ' ', Outcome),
               CASE WHEN ShouldShowPercentOfSpec = 0 AND Outcome = N'Updated' THEN N'PASS' ELSE N'FAIL' END
        FROM #R;
        DELETE #R;

        INSERT @Out SELECT N'UpdatedDate untouched (sync health check reads it)', N'same',
               IIF(EXISTS (SELECT 1 FROM dbo.OrderDetailsItems WHERE OrderDetailId = @Od AND OrderDetailsItemId = @Item
                           AND (UpdatedDate = @Updated OR (UpdatedDate IS NULL AND @Updated IS NULL))), N'same', N'changed'),
               IIF(EXISTS (SELECT 1 FROM dbo.OrderDetailsItems WHERE OrderDetailId = @Od AND OrderDetailsItemId = @Item
                           AND (UpdatedDate = @Updated OR (UpdatedDate IS NULL AND @Updated IS NULL))), N'PASS', N'FAIL');

        /* signed report: re-sending the stored value is accepted */
        UPDATE dbo.OrderDetailsItems SET RemarksLockedDate = GETDATE()
        WHERE OrderDetailId = @Od AND OrderDetailsItemId = @Item;
        INSERT #R EXEC dbo.SetReportDisplayOptions @Email, @Od, @Item, 0;
        INSERT @Out SELECT N'signed report: re-sending the same value is accepted', N'0 NoChange',
               CONCAT(ShouldShowPercentOfSpec, ' ', Outcome),
               CASE WHEN ShouldShowPercentOfSpec = 0 AND Outcome = N'NoChange' THEN N'PASS' ELSE N'FAIL' END
        FROM #R;
        DELETE #R;

        /* the main calibrator who is also the second calibrator may change it */
        UPDATE dbo.OrderDetailsItems SET RemarksLockedDate = NULL, MainCalibratorId = @UserId, SecondCalibratorId = @UserId
        WHERE OrderDetailId = @Od AND OrderDetailsItemId = @Item;
        INSERT #R EXEC dbo.SetReportDisplayOptions @Email, @Od, @Item, 1;
        INSERT @Out SELECT N'main calibrator who is also second may change it', N'1 Updated',
               CONCAT(ShouldShowPercentOfSpec, ' ', Outcome),
               CASE WHEN ShouldShowPercentOfSpec = 1 AND Outcome = N'Updated' THEN N'PASS' ELSE N'FAIL' END
        FROM #R;
        DELETE #R;

    ROLLBACK TRANSACTION;

    /* ---- the same OrderDetailsItemId on two order lines -------------------------------------- */
    DECLARE @DupOdA INT, @DupOdB INT, @DupItem INT;
    SELECT TOP (1) @DupItem = a.OrderDetailsItemId, @DupOdA = a.OrderDetailId, @DupOdB = b.OrderDetailId
    FROM dbo.OrderDetailsItems AS a
    JOIN dbo.OrderDetailsItems AS b
      ON b.OrderDetailsItemId = a.OrderDetailsItemId AND b.OrderDetailId <> a.OrderDetailId AND b.IsDeleted = 0
    WHERE a.IsDeleted = 0 AND a.ShouldShowPercentOfSpec = 0 AND b.ShouldShowPercentOfSpec = 0
      AND a.RemarksLockedDate IS NULL
    ORDER BY a.OrderDetailsItemId;

    IF @DupItem IS NULL
        INSERT @Out SELECT N'duplicated id: only the addressed line changes', N'other line 0',
               N'no duplicated OrderDetailsItemId on this database', N'SKIP';
    ELSE
    BEGIN
        BEGIN TRANSACTION;
            INSERT #R EXEC dbo.SetReportDisplayOptions @Email, @DupOdA, @DupItem, 1;
            INSERT @Out SELECT N'duplicated id: only the addressed line changes', N'this 1, other 0, 1 row',
                   CONCAT('this ', (SELECT ShouldShowPercentOfSpec FROM dbo.OrderDetailsItems WHERE OrderDetailId = @DupOdA AND OrderDetailsItemId = @DupItem),
                          ', other ', (SELECT ShouldShowPercentOfSpec FROM dbo.OrderDetailsItems WHERE OrderDetailId = @DupOdB AND OrderDetailsItemId = @DupItem),
                          ', ', (SELECT COUNT(*) FROM #R), ' row'),
                   CASE WHEN (SELECT ShouldShowPercentOfSpec FROM dbo.OrderDetailsItems WHERE OrderDetailId = @DupOdA AND OrderDetailsItemId = @DupItem) = 1
                         AND (SELECT ShouldShowPercentOfSpec FROM dbo.OrderDetailsItems WHERE OrderDetailId = @DupOdB AND OrderDetailsItemId = @DupItem) = 0
                         AND (SELECT COUNT(*) FROM #R) = 1
                        THEN N'PASS' ELSE N'FAIL' END;
            DELETE #R;
        ROLLBACK TRANSACTION;
    END;

    /* ---- refusals, each in its own transaction ------------------------------------------------ */
    SET @Err = NULL;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.OrderDetailsItems SET RemarksLockedDate = GETDATE() WHERE OrderDetailId = @Od AND OrderDetailsItemId = @Item;
        INSERT #R EXEC dbo.SetReportDisplayOptions @Email, @Od, @Item, 1;
        ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    END CATCH;
    INSERT @Out SELECT N'signed report: a change is refused', N'The report is signed; ...', @Err,
           CASE WHEN @Err = N'The report is signed; its options can no longer change.' THEN N'PASS' ELSE N'FAIL' END;

    SET @Err = NULL;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.OrderDetailsItems SET MainCalibratorId = NULL, SecondCalibratorId = @UserId
        WHERE OrderDetailId = @Od AND OrderDetailsItemId = @Item;
        INSERT #R EXEC dbo.SetReportDisplayOptions @Email, @Od, @Item, 1;
        ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    END CATCH;
    INSERT @Out SELECT N'the second calibrator is refused', N'The second calibrator cannot ...', @Err,
           CASE WHEN @Err = N'The second calibrator cannot change the report options.' THEN N'PASS' ELSE N'FAIL' END;

    SET @Err = NULL;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.OrderDetailsItems SET IsDeleted = 1 WHERE OrderDetailId = @Od AND OrderDetailsItemId = @Item;
        INSERT #R EXEC dbo.SetReportDisplayOptions @Email, @Od, @Item, 1;
        ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    END CATCH;
    INSERT @Out SELECT N'a deleted line is refused', N'Unknown order line.', @Err,
           CASE WHEN @Err = N'Unknown order line.' THEN N'PASS' ELSE N'FAIL' END;

    SET @Err = NULL;
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT #R EXEC dbo.SetReportDisplayOptions @Email, -1, @Item, 1;
        ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    END CATCH;
    INSERT @Out SELECT N'the item id on the wrong order line is refused', N'Unknown order line.', @Err,
           CASE WHEN @Err = N'Unknown order line.' THEN N'PASS' ELSE N'FAIL' END;

    SET @Err = NULL;
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT #R EXEC dbo.SetReportDisplayOptions N'nobody@invalid.example', @Od, @Item, 1;
        ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    END CATCH;
    INSERT @Out SELECT N'unknown user is refused', N'Unknown user.', @Err,
           CASE WHEN @Err = N'Unknown user.' THEN N'PASS' ELSE N'FAIL' END;

    DECLARE @Inactive NVARCHAR(255) = (
        SELECT TOP (1) u.Email FROM dbo.Users AS u
        WHERE u.IsActive = 0 AND u.Email IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM dbo.Users AS a WHERE a.Email = u.Email AND a.IsActive = 1)
        ORDER BY u.ID);
    IF @Inactive IS NULL
        INSERT @Out SELECT N'inactive user is refused', N'Inactive user.', N'no inactive user on this database', N'SKIP';
    ELSE
    BEGIN
        SET @Err = NULL;
        BEGIN TRY
            BEGIN TRANSACTION;
            INSERT #R EXEC dbo.SetReportDisplayOptions @Inactive, @Od, @Item, 1;
            ROLLBACK TRANSACTION;
        END TRY
        BEGIN CATCH
            SET @Err = ERROR_MESSAGE();
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        END CATCH;
        INSERT @Out SELECT N'inactive user is refused', N'Inactive user.', @Err,
               CASE WHEN @Err = N'Inactive user.' THEN N'PASS' ELSE N'FAIL' END;
    END;

    /* ---- nothing left behind ------------------------------------------------------------------ */
    INSERT @Out SELECT N'rolled back: the test line is as it was', N'0, unsigned, live',
           (SELECT CONCAT(ShouldShowPercentOfSpec, ', ', IIF(RemarksLockedDate IS NULL, 'unsigned', 'signed'), ', ',
                          IIF(IsDeleted = 0, 'live', 'deleted'))
            FROM dbo.OrderDetailsItems WHERE OrderDetailId = @Od AND OrderDetailsItemId = @Item),
           CASE WHEN EXISTS (SELECT 1 FROM dbo.OrderDetailsItems WHERE OrderDetailId = @Od AND OrderDetailsItemId = @Item
                             AND ShouldShowPercentOfSpec = 0 AND RemarksLockedDate IS NULL AND IsDeleted = 0)
                THEN N'PASS' ELSE N'FAIL' END;
END;

SELECT Seq, Test, Expected, Actual, Result FROM @Out ORDER BY Seq;
