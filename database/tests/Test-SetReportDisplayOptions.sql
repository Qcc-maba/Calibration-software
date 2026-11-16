/*
    Tests for the Report screen's saved display options                                    MBA-1004
    ---------------------------------------------------------------------------------------------
    dbo.OrderDetailsItems.ShouldShowPercentOfSpec, dbo.SetReportDisplayOptions, and the column in
    dbo.GetOrderDetailsDevices' result.

    Run against a database where the column and both procedures are deployed. Anything other than
    'PASS' in Result is a failure. Every write happens inside a transaction that is rolled back, so
    the file leaves the database as it found it. Each refusal runs in a transaction of its own,
    because the procedure runs with XACT_ABORT ON and an error dooms the transaction it happens in.
*/
SET NOCOUNT ON;

DECLARE @Out TABLE (Seq INT IDENTITY, Test NVARCHAR(90), Expected NVARCHAR(60), Actual NVARCHAR(200),
                    Result NVARCHAR(10));

DROP TABLE IF EXISTS #R;
CREATE TABLE #R (OrderDetailsItemId INT, ShouldShowPercentOfSpec BIT, Outcome NVARCHAR(10));

DECLARE @Email NVARCHAR(255) = (SELECT TOP (1) Email FROM dbo.Users WHERE Email IS NOT NULL ORDER BY ID);

/* a line whose id is unique, currently unchecked */
DECLARE @Item INT = (
    SELECT TOP (1) i.OrderDetailsItemId
    FROM dbo.OrderDetailsItems AS i
    WHERE i.IsDeleted = 0 AND i.ShouldShowPercentOfSpec = 0
      AND (SELECT COUNT(*) FROM dbo.OrderDetailsItems AS j WHERE j.OrderDetailsItemId = i.OrderDetailsItemId) = 1
    ORDER BY i.OrderDetailsItemId DESC);

DECLARE @Updated DATETIME, @Err NVARCHAR(400), @V NVARCHAR(200);

/* ---- the column ------------------------------------------------------------------------------ */
SELECT @V = CONCAT('nullable=', c.is_nullable, ' default=', dc.definition)
FROM sys.columns AS c
LEFT JOIN sys.default_constraints AS dc ON dc.object_id = c.default_object_id
WHERE c.object_id = OBJECT_ID('dbo.OrderDetailsItems') AND c.name = 'ShouldShowPercentOfSpec';
INSERT @Out SELECT N'column is NOT NULL with default 0', N'nullable=0 default=((0))', @V,
       CASE WHEN @V = N'nullable=0 default=((0))' THEN N'PASS' ELSE N'FAIL' END;

SELECT @V = CAST(COUNT(*) AS NVARCHAR(20)) FROM dbo.OrderDetailsItems WHERE ShouldShowPercentOfSpec = 1;
INSERT @Out SELECT N'existing lines are unchecked unless someone checked one', N'(info)', @V + N' checked', N'PASS';

/* ---- the read procedure returns it ----------------------------------------------------------- */
SELECT @V = MAX(CONCAT(name, ':', system_type_name))
FROM sys.dm_exec_describe_first_result_set(N'EXEC dbo.GetOrderDetailsDevices @OrderWorkPlanId = 1', NULL, 0)
WHERE name = 'ShouldShowPercentOfSpec';
INSERT @Out SELECT N'GetOrderDetailsDevices returns ShouldShowPercentOfSpec', N'ShouldShowPercentOfSpec:bit', @V,
       CASE WHEN @V = N'ShouldShowPercentOfSpec:bit' THEN N'PASS' ELSE N'FAIL' END;

/* ---- writes, rolled back --------------------------------------------------------------------- */
BEGIN TRANSACTION;

    SELECT @Updated = UpdatedDate FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @Item;

    INSERT #R EXEC dbo.SetReportDisplayOptions @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Item,
                                               @ShouldShowPercentOfSpec = 1;
    INSERT @Out SELECT N'check it', N'1 Updated', CONCAT(ShouldShowPercentOfSpec, ' ', Outcome),
           CASE WHEN ShouldShowPercentOfSpec = 1 AND Outcome = N'Updated'
                 AND (SELECT ShouldShowPercentOfSpec FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @Item) = 1
                THEN N'PASS' ELSE N'FAIL' END
    FROM #R;
    DELETE #R;

    INSERT #R EXEC dbo.SetReportDisplayOptions @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Item,
                                               @ShouldShowPercentOfSpec = 1;
    INSERT @Out SELECT N'check it again is idempotent', N'1 NoChange', CONCAT(ShouldShowPercentOfSpec, ' ', Outcome),
           CASE WHEN ShouldShowPercentOfSpec = 1 AND Outcome = N'NoChange' THEN N'PASS' ELSE N'FAIL' END
    FROM #R;
    DELETE #R;

    INSERT #R EXEC dbo.SetReportDisplayOptions @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Item,
                                               @ShouldShowPercentOfSpec = NULL;
    INSERT @Out SELECT N'NULL keeps the stored value', N'1 NoChange', CONCAT(ShouldShowPercentOfSpec, ' ', Outcome),
           CASE WHEN ShouldShowPercentOfSpec = 1 AND Outcome = N'NoChange' THEN N'PASS' ELSE N'FAIL' END
    FROM #R;
    DELETE #R;

    INSERT #R EXEC dbo.SetReportDisplayOptions @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Item,
                                               @ShouldShowPercentOfSpec = 0;
    INSERT @Out SELECT N'uncheck it', N'0 Updated', CONCAT(ShouldShowPercentOfSpec, ' ', Outcome),
           CASE WHEN ShouldShowPercentOfSpec = 0 AND Outcome = N'Updated'
                 AND (SELECT ShouldShowPercentOfSpec FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @Item) = 0
                THEN N'PASS' ELSE N'FAIL' END
    FROM #R;
    DELETE #R;

    INSERT @Out SELECT N'UpdatedDate untouched (sync health check reads it)', N'same',
           CASE WHEN EXISTS (SELECT 1 FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @Item
                             AND (UpdatedDate = @Updated OR (UpdatedDate IS NULL AND @Updated IS NULL)))
                THEN N'same' ELSE N'changed' END,
           CASE WHEN EXISTS (SELECT 1 FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @Item
                             AND (UpdatedDate = @Updated OR (UpdatedDate IS NULL AND @Updated IS NULL)))
                THEN N'PASS' ELSE N'FAIL' END;

ROLLBACK TRANSACTION;

/* ---- refusals -------------------------------------------------------------------------------- */
SET @Err = NULL;
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT #R EXEC dbo.SetReportDisplayOptions @LoggedInUserEmail = N'nobody@invalid.example',
                                               @OrderDetailsItemId = @Item, @ShouldShowPercentOfSpec = 1;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SET @Err = ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;
INSERT @Out SELECT N'unknown user is refused', N'Unknown user.', @Err,
       CASE WHEN @Err = N'Unknown user.' THEN N'PASS' ELSE N'FAIL' END;

SET @Err = NULL;
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT #R EXEC dbo.SetReportDisplayOptions @LoggedInUserEmail = @Email,
                                               @OrderDetailsItemId = -1, @ShouldShowPercentOfSpec = 1;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SET @Err = ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;
INSERT @Out SELECT N'unknown line is refused', N'Unknown OrderDetailsItemId.', @Err,
       CASE WHEN @Err = N'Unknown OrderDetailsItemId.' THEN N'PASS' ELSE N'FAIL' END;

/* ---- nothing left behind --------------------------------------------------------------------- */
INSERT @Out SELECT N'rolled back: the test line is unchecked again', N'0',
       CAST((SELECT ShouldShowPercentOfSpec FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @Item) AS NVARCHAR(5)),
       CASE WHEN (SELECT ShouldShowPercentOfSpec FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @Item) = 0
            THEN N'PASS' ELSE N'FAIL' END;

SELECT Seq, Test, Expected, Actual, Result FROM @Out ORDER BY Seq;
