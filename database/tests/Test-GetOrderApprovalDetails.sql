/*
    Tests for dbo.GetOrderApprovalDetails                                                MBA-888
    ---------------------------------------------------------------------------------------------
    Covers the two rules added on 2026-10-13:
      * the recipient is an active (IsActive = 1), mailable (DoNotMail = 0) contact, and
        RecipientCount counts only such contacts;
      * IsInHouse = 1 exactly when the order has no live (not deleted, not cancelled) line with
        OrderDetails.IsInHouse = 0, which is what keeps an order off the coordinator screen.

    Read-only: the procedure writes nothing, so nothing needs rolling back. Anything other than
    'PASS' in Result is a failure; 'SKIP' means the database holds no row that fits the case, and
    says which.

    Fixtures are picked from the data, never hard-coded - identities differ between STAGE and PROD.
    No address is printed; the output names cases and ids, not people.
*/
SET NOCOUNT ON;

DECLARE @Out TABLE (Seq INT IDENTITY, Test NVARCHAR(100), Fixture NVARCHAR(40),
                    Expected NVARCHAR(60), Actual NVARCHAR(60), Result NVARCHAR(80));

DROP TABLE IF EXISTS #G;
CREATE TABLE #G (
    OrderWorkPlanId INT, OrderNumber NVARCHAR(50), CustomerId INT,
    CustomerName NVARCHAR(400), CustomerNameENG NVARCHAR(400), ClientConfirmationStatus NVARCHAR(200),
    IsCancelled BIT, IsInHouse BIT, PlacementDate DATETIME2, SiteAddress NVARCHAR(MAX),
    CalibrationRange NVARCHAR(MAX), ContactId INT, ContactName NVARCHAR(400), ContactEmail NVARCHAR(400),
    ContactPhone NVARCHAR(400), RecipientCount INT,
    CalibratorsJson NVARCHAR(MAX), DevicesJson NVARCHAR(MAX), SkusJson NVARCHAR(MAX));

/* ---------------------------------------------------------------------------------------------
   Fixtures
   --------------------------------------------------------------------------------------------- */

/* Per active order: its line classification. */
DROP TABLE IF EXISTS #Lines;
SELECT wp.OrderWorkPlanId,
       SUM(CASE WHEN od.IsInHouse = 0    AND od.IsDeleted = 0 AND od.IsCancelled = 0 THEN 1 ELSE 0 END) AS Ext,
       SUM(CASE WHEN od.IsInHouse = 1    AND od.IsDeleted = 0 AND od.IsCancelled = 0 THEN 1 ELSE 0 END) AS InH,
       SUM(CASE WHEN od.IsInHouse IS NULL AND od.IsDeleted = 0 AND od.IsCancelled = 0 THEN 1 ELSE 0 END) AS Nul
INTO #Lines
FROM dbo.OrderWorkPlans AS wp
JOIN dbo.OrderDetails   AS od ON od.OrderWorkPlanId = wp.OrderWorkPlanId
WHERE wp.IsCancelled = 0
GROUP BY wp.OrderWorkPlanId;

DECLARE @AllExternal INT = (SELECT TOP (1) OrderWorkPlanId FROM #Lines WHERE Ext > 0 AND InH = 0 AND Nul = 0 ORDER BY OrderWorkPlanId DESC);
DECLARE @AllInHouse  INT = (SELECT TOP (1) OrderWorkPlanId FROM #Lines WHERE Ext = 0 AND InH > 0 AND Nul = 0 ORDER BY OrderWorkPlanId DESC);
DECLARE @Mixed       INT = (SELECT TOP (1) OrderWorkPlanId FROM #Lines WHERE Ext > 0 AND InH > 0           ORDER BY OrderWorkPlanId DESC);
DECLARE @OnlyNull    INT = (SELECT TOP (1) OrderWorkPlanId FROM #Lines WHERE Ext = 0 AND InH = 0 AND Nul > 0 ORDER BY OrderWorkPlanId DESC);

/* An active order whose recipient under the OLD rule (any contact with an e-mail) is inactive or
   do-not-mail, while the customer also has an eligible contact. */
DROP TABLE IF EXISTS #Ranked;
SELECT wp.OrderWorkPlanId, cc.CustomerContactId,
       CASE WHEN cc.IsActive = 1 AND cc.DoNotMail = 0 THEN 1 ELSE 0 END AS Eligible,
       ROW_NUMBER() OVER (PARTITION BY wp.OrderWorkPlanId
            ORDER BY CASE WHEN EXISTS (SELECT 1 FROM dbo.OrderDetails AS od
                                       WHERE od.OrderWorkPlanId = wp.OrderWorkPlanId AND od.IsDeleted = 0
                                         AND od.CustomerSiteId = cc.CustomerSiteId) THEN 0 ELSE 1 END,
                     cc.CustomerContactId) AS OldRank
INTO #Ranked
FROM dbo.OrderWorkPlans   AS wp
JOIN dbo.CustomerContacts AS cc ON cc.CustomerId = wp.CustomerId AND cc.IsDeleted = 0
                               AND NULLIF(LTRIM(RTRIM(cc.CustomerContactEmail)), N'') IS NOT NULL
WHERE wp.IsCancelled = 0;

DECLARE @Switched INT, @OldPick INT;
SELECT TOP (1) @Switched = r.OrderWorkPlanId, @OldPick = r.CustomerContactId
FROM #Ranked AS r
WHERE r.OldRank = 1 AND r.Eligible = 0
  AND EXISTS (SELECT 1 FROM #Ranked AS e WHERE e.OrderWorkPlanId = r.OrderWorkPlanId AND e.Eligible = 1)
ORDER BY r.OrderWorkPlanId DESC;

/* An active order whose customer has contacts with an e-mail, none of them eligible. */
DECLARE @NoneEligible INT =
(
    SELECT TOP (1) r.OrderWorkPlanId
    FROM #Ranked AS r
    GROUP BY r.OrderWorkPlanId
    HAVING MAX(r.Eligible) = 0
    ORDER BY r.OrderWorkPlanId DESC
);

/* ---------------------------------------------------------------------------------------------
   Cases
   --------------------------------------------------------------------------------------------- */
DECLARE @Got NVARCHAR(60), @Want NVARCHAR(60);

/* 1-4: IsInHouse per line classification */
DECLARE @Cases TABLE (Name NVARCHAR(100), Id INT, Want BIT);
INSERT @Cases VALUES (N'IsInHouse: all lines external',            @AllExternal, 0),
                     (N'IsInHouse: all lines in-house',            @AllInHouse,  1),
                     (N'IsInHouse: mixed order counts as external', @Mixed,       0),
                     (N'IsInHouse: only unclassified (NULL) lines', @OnlyNull,    1);

DECLARE @Name NVARCHAR(100), @Id INT, @WantBit BIT;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT Name, Id, Want FROM @Cases;
OPEN c;
FETCH NEXT FROM c INTO @Name, @Id, @WantBit;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF @Id IS NULL
        INSERT @Out (Test, Fixture, Expected, Actual, Result) VALUES (@Name, NULL, NULL, NULL, N'SKIP: no such order');
    ELSE
    BEGIN
        TRUNCATE TABLE #G;
        INSERT #G EXEC dbo.GetOrderApprovalDetails @OrderWorkPlanId = @Id;
        SET @Got = (SELECT CAST(IsInHouse AS NVARCHAR(5)) FROM #G);
        SET @Want = CAST(@WantBit AS NVARCHAR(5));
        INSERT @Out (Test, Fixture, Expected, Actual, Result)
        VALUES (@Name, CONCAT(N'OrderWorkPlanId ', @Id), @Want, @Got,
                CASE WHEN @Got = @Want THEN N'PASS' ELSE N'FAIL' END);
    END
    FETCH NEXT FROM c INTO @Name, @Id, @WantBit;
END
CLOSE c;
DEALLOCATE c;

/* 5-7: the order whose old-rule recipient was ineligible */
IF @Switched IS NULL
BEGIN
    INSERT @Out (Test, Result) VALUES (N'Recipient skips an inactive / do-not-mail contact', N'SKIP: no order whose first pick is ineligible');
    INSERT @Out (Test, Result) VALUES (N'Recipient is active and mailable',                  N'SKIP: no order whose first pick is ineligible');
    INSERT @Out (Test, Result) VALUES (N'RecipientCount counts eligible contacts only',      N'SKIP: no order whose first pick is ineligible');
END
ELSE
BEGIN
    TRUNCATE TABLE #G;
    INSERT #G EXEC dbo.GetOrderApprovalDetails @OrderWorkPlanId = @Switched;

    DECLARE @NewPick INT = (SELECT ContactId FROM #G);

    INSERT @Out (Test, Fixture, Expected, Actual, Result)
    VALUES (N'Recipient skips an inactive / do-not-mail contact', CONCAT(N'OrderWorkPlanId ', @Switched),
            CONCAT(N'<> ', @OldPick), CAST(@NewPick AS NVARCHAR(20)),
            CASE WHEN @NewPick IS NOT NULL AND @NewPick <> @OldPick THEN N'PASS' ELSE N'FAIL' END);

    SET @Got = (SELECT CONCAT(N'IsActive=', cc.IsActive, N' DoNotMail=', cc.DoNotMail)
                FROM dbo.CustomerContacts AS cc WHERE cc.CustomerContactId = @NewPick);
    INSERT @Out (Test, Fixture, Expected, Actual, Result)
    VALUES (N'Recipient is active and mailable', CONCAT(N'ContactId ', @NewPick),
            N'IsActive=1 DoNotMail=0', @Got,
            CASE WHEN @Got = N'IsActive=1 DoNotMail=0' THEN N'PASS' ELSE N'FAIL' END);

    SET @Want = CAST((SELECT COUNT(*) FROM #Ranked WHERE OrderWorkPlanId = @Switched AND Eligible = 1) AS NVARCHAR(20));
    SET @Got  = (SELECT CAST(RecipientCount AS NVARCHAR(20)) FROM #G);
    INSERT @Out (Test, Fixture, Expected, Actual, Result)
    VALUES (N'RecipientCount counts eligible contacts only', CONCAT(N'OrderWorkPlanId ', @Switched),
            @Want, @Got, CASE WHEN @Got = @Want THEN N'PASS' ELSE N'FAIL' END);
END

/* 8: no eligible contact at all -> no recipient, so the app reports "no contact e-mail" */
IF @NoneEligible IS NULL
    INSERT @Out (Test, Result) VALUES (N'No eligible contact -> ContactEmail is NULL', N'SKIP: every customer with an e-mail contact has an eligible one');
ELSE
BEGIN
    TRUNCATE TABLE #G;
    INSERT #G EXEC dbo.GetOrderApprovalDetails @OrderWorkPlanId = @NoneEligible;
    SET @Got = (SELECT CONCAT(CASE WHEN ContactEmail IS NULL THEN N'NULL' ELSE N'set' END, N' / ', RecipientCount) FROM #G);
    INSERT @Out (Test, Fixture, Expected, Actual, Result)
    VALUES (N'No eligible contact -> ContactEmail is NULL', CONCAT(N'OrderWorkPlanId ', @NoneEligible),
            N'NULL / 0', @Got, CASE WHEN @Got = N'NULL / 0' THEN N'PASS' ELSE N'FAIL' END);
END

SELECT Seq, Test, Fixture, Expected, Actual, Result FROM @Out ORDER BY Seq;
