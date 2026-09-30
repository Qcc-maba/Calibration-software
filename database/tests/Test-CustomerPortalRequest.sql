/*
    Tests for the customer-portal write procedures                                     MBA-903
        dbo.CreateCustomerPortalRequest, dbo.ResolveCustomerPortalRequest, dbo.DuplicateCustomerDevice
    ---------------------------------------------------------------------------------------------
    Run against a database where the three procedures and dbo.GetPortalCustomerIds are deployed.
    Anything other than 'PASS' in Result is a failure; 'SKIP' means the database holds no row that
    fits the case, and says which.

    Every case runs in its own transaction and is rolled back, so the file leaves the database as it
    found it. Each case needs its own: the procedures run with XACT_ABORT ON, so a THROW inside one
    rolls back the whole transaction it is in. Results are kept in a table variable, which a
    rollback does not touch.

    Fixtures are picked from the data, never hard-coded - identities differ between STAGE and PROD.
    No address is printed; the output names cases, not people.

        @Multi   an active address whose customer set holds live items under at least two customers
        @ItemA   a live item of the first of those customers, @ItemB of the second
        @Foreign a live item of a customer outside @Multi's set
        @Other   another active address whose set does not include @ItemA's customer
        @Staff   an MBA user (dbo.Users) who is not a customer contact
*/
SET NOCOUNT ON;
SET XACT_ABORT OFF;   /* the procedures set their own; the harness must survive their THROWs */

DECLARE @Out TABLE (Seq INT IDENTITY, Section NVARCHAR(14), Test NVARCHAR(100),
                    Expected NVARCHAR(80), Actual NVARCHAR(80), Result NVARCHAR(80));

DROP TABLE IF EXISTS #R;
CREATE TABLE #R (customerPortalRequestId BIGINT, customerId INT, customerName NVARCHAR(200),
                 itemCount INT, rejectedItemCount INT);
DROP TABLE IF EXISTS #Res;
CREATE TABLE #Res (customerPortalRequestId BIGINT, status NVARCHAR(20));
DROP TABLE IF EXISTS #Dup;
CREATE TABLE #Dup (customerDeviceId INT, serialNumber NVARCHAR(100));

/* ---------------------------------------------------------------------------------------------
   Fixtures
   --------------------------------------------------------------------------------------------- */
DECLARE @Multi NVARCHAR(100), @CustA INT, @CustB INT, @ItemA INT, @ItemB INT, @Foreign INT,
        @Other NVARCHAR(100), @Staff NVARCHAR(100), @PrimaryCust INT,
        @OwnSite INT, @ForeignSite INT;

;WITH live AS
(
    SELECT wp.CustomerId, MIN(it.OrderDetailsItemId) AS ItemId
    FROM dbo.OrderWorkPlans AS wp
    INNER JOIN dbo.OrderDetails      AS od ON od.OrderWorkPlanId = wp.OrderWorkPlanId AND ISNULL(od.IsDeleted, 0) = 0
    INNER JOIN dbo.OrderDetailsItems AS it ON it.OrderDetailId   = od.OrderDetailId   AND ISNULL(it.IsDeleted, 0) = 0
    GROUP BY wp.CustomerId
)
SELECT TOP (1) @Multi = LOWER(LTRIM(RTRIM(cc.CustomerContactEmail)))
FROM dbo.CustomerContacts AS cc
INNER JOIN live ON live.CustomerId = cc.CustomerId
LEFT JOIN (SELECT DISTINCT CustomerId FROM dbo.CustomerSites WHERE ISNULL(IsDeleted, 0) = 0) AS sited
    ON sited.CustomerId = cc.CustomerId
WHERE cc.IsDeleted = 0 AND ISNULL(cc.IsActive, 1) = 1 AND cc.CustomerContactEmail LIKE N'%_@_%'
GROUP BY LOWER(LTRIM(RTRIM(cc.CustomerContactEmail)))
HAVING COUNT(DISTINCT cc.CustomerId) >= 2
ORDER BY MAX(CASE WHEN sited.CustomerId IS NOT NULL THEN 1 ELSE 0 END) DESC,   /* one of them owns a site */
         COUNT(DISTINCT cc.CustomerId), LOWER(LTRIM(RTRIM(cc.CustomerContactEmail)));

/* the two customers of @Multi's set that hold live items, and one item of each */
DECLARE @Pair TABLE (Rn INT IDENTITY, CustomerId INT, ItemId INT);
INSERT @Pair (CustomerId, ItemId)
SELECT TOP (2) mine.CustomerId, x.ItemId
FROM dbo.GetPortalCustomerIds(@Multi) AS mine
CROSS APPLY (SELECT MIN(it.OrderDetailsItemId) AS ItemId
             FROM dbo.OrderWorkPlans AS wp
             INNER JOIN dbo.OrderDetails      AS od ON od.OrderWorkPlanId = wp.OrderWorkPlanId AND ISNULL(od.IsDeleted, 0) = 0
             INNER JOIN dbo.OrderDetailsItems AS it ON it.OrderDetailId   = od.OrderDetailId   AND ISNULL(it.IsDeleted, 0) = 0
             WHERE wp.CustomerId = mine.CustomerId) AS x
WHERE x.ItemId IS NOT NULL
ORDER BY CASE WHEN EXISTS (SELECT 1 FROM dbo.CustomerSites AS cs
                           WHERE cs.CustomerId = mine.CustomerId AND ISNULL(cs.IsDeleted, 0) = 0) THEN 0 ELSE 1 END,
         mine.CustomerId;

SELECT @CustA = CustomerId, @ItemA = ItemId FROM @Pair WHERE Rn = 1;
SELECT @CustB = CustomerId, @ItemB = ItemId FROM @Pair WHERE Rn = 2;
SELECT @PrimaryCust = CustomerId FROM dbo.GetPortalCustomerIds(@Multi) WHERE IsPrimary = 1;

SELECT TOP (1) @Foreign = it.OrderDetailsItemId
FROM dbo.OrderWorkPlans AS wp
INNER JOIN dbo.OrderDetails      AS od ON od.OrderWorkPlanId = wp.OrderWorkPlanId AND ISNULL(od.IsDeleted, 0) = 0
INNER JOIN dbo.OrderDetailsItems AS it ON it.OrderDetailId   = od.OrderDetailId   AND ISNULL(it.IsDeleted, 0) = 0
WHERE wp.CustomerId NOT IN (SELECT CustomerId FROM dbo.GetPortalCustomerIds(@Multi))
ORDER BY it.OrderDetailsItemId;

SELECT TOP (1) @Other = LOWER(LTRIM(RTRIM(cc.CustomerContactEmail)))
FROM dbo.CustomerContacts AS cc
WHERE cc.IsDeleted = 0 AND ISNULL(cc.IsActive, 1) = 1 AND cc.CustomerContactEmail LIKE N'%_@_%'
  AND cc.CustomerId <> @CustA
  AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) <> @Multi
  AND NOT EXISTS (SELECT 1 FROM dbo.CustomerContacts AS c2
                  WHERE c2.CustomerId = @CustA AND c2.IsDeleted = 0
                    AND LOWER(LTRIM(RTRIM(c2.CustomerContactEmail))) = LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))))
ORDER BY cc.CustomerContactId;

SELECT TOP (1) @Staff = LOWER(LTRIM(RTRIM(u.Email)))
FROM dbo.Users AS u
WHERE u.Email LIKE N'%_@_%'
  AND NOT EXISTS (SELECT 1 FROM dbo.CustomerContacts AS cc
                  WHERE LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = LOWER(LTRIM(RTRIM(u.Email))))
ORDER BY u.ID;

SELECT TOP (1) @OwnSite = cs.CustomerSiteId
FROM dbo.CustomerSites AS cs
WHERE cs.CustomerId IN (SELECT CustomerId FROM dbo.GetPortalCustomerIds(@Multi)) AND ISNULL(cs.IsDeleted, 0) = 0
ORDER BY cs.CustomerSiteId;

SELECT TOP (1) @ForeignSite = cs.CustomerSiteId
FROM dbo.CustomerSites AS cs
WHERE cs.CustomerId NOT IN (SELECT CustomerId FROM dbo.GetPortalCustomerIds(@Multi)) AND ISNULL(cs.IsDeleted, 0) = 0
ORDER BY cs.CustomerSiteId;

INSERT @Out SELECT N'0 fixtures', N'a multi-customer address with items under two customers',
       N'found', IIF(@ItemB IS NULL, N'missing', N'found'), IIF(@ItemB IS NULL, N'FAIL - nothing below can run', N'PASS');

DECLARE @Ids NVARCHAR(200), @Err INT, @Before INT, @After INT, @Req BIGINT, @N INT, @M INT;


/* =============================================================================================
   Section 1 - CreateCustomerPortalRequest
   ============================================================================================= */

/* 1a  items of two customers -> two requests, each with its own item */
BEGIN TRY
    BEGIN TRAN;
    SET @Ids = CONCAT(@ItemA, N',', @ItemB);
    TRUNCATE TABLE #R;
    INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = @Multi,
        @RequestType = N'Quote', @ItemIds = @Ids, @DeviceCount = 2, @CalibrationLocation = N'lab';

    INSERT @Out SELECT N'1 create', N'1a split: one result row per owning customer', N'2 rows A,B',
           CONCAT((SELECT COUNT(*) FROM #R), N' rows'),
           IIF((SELECT COUNT(*) FROM #R) = 2
               AND EXISTS (SELECT 1 FROM #R WHERE customerId = @CustA AND itemCount = 1)
               AND EXISTS (SELECT 1 FROM #R WHERE customerId = @CustB AND itemCount = 1), N'PASS', N'FAIL');

    SELECT @N = COUNT(*)
    FROM #R AS r
    INNER JOIN dbo.CustomerPortalRequest     AS q ON q.CustomerPortalRequestId = r.customerPortalRequestId
    INNER JOIN dbo.CustomerPortalRequestItem AS i ON i.CustomerPortalRequestId = q.CustomerPortalRequestId
    INNER JOIN dbo.OrderDetailsItems  AS it ON it.OrderDetailsItemId = i.OrderDetailsItemId
    INNER JOIN dbo.OrderDetails       AS od ON od.OrderDetailId      = it.OrderDetailId
    INNER JOIN dbo.OrderWorkPlans     AS wp ON wp.OrderWorkPlanId    = od.OrderWorkPlanId
    WHERE q.CustomerId = wp.CustomerId AND q.CustomerId = r.customerId;
    INSERT @Out SELECT N'1 create', N'1a each stored item sits under the request of its own customer',
           N'2', CAST(@N AS NVARCHAR(10)), IIF(@N = 2, N'PASS', N'FAIL');

    SELECT @N = COUNT(*) FROM #R AS r
    INNER JOIN dbo.CustomerPortalRequest AS q ON q.CustomerPortalRequestId = r.customerPortalRequestId
    WHERE q.DeviceCount = 1 AND q.CustomerContactId IS NOT NULL AND q.Status = N'New';
    INSERT @Out SELECT N'1 create', N'1a split requests: DeviceCount = own items, contact set, New',
           N'2', CAST(@N AS NVARCHAR(10)), IIF(@N = 2, N'PASS', N'FAIL');

    SELECT @N = COUNT(*) FROM #R WHERE rejectedItemCount = 0;
    INSERT @Out SELECT N'1 create', N'1a rejectedItemCount 0 on every row', N'2',
           CAST(@N AS NVARCHAR(10)), IIF(@N = 2, N'PASS', N'FAIL');
    ROLLBACK;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out SELECT N'1 create', N'1a split', N'no error', LEFT(ERROR_MESSAGE(), 80), N'FAIL';
END CATCH;

/* 1b  one owned item + one foreign -> one request, the foreign one reported */
BEGIN TRY
    BEGIN TRAN;
    SET @Ids = CONCAT(@ItemA, N',', @Foreign);
    TRUNCATE TABLE #R;
    INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = @Multi,
        @RequestType = N'CalibrationExtension', @ItemIds = @Ids, @RequestedDate = '2027-01-01',
        @Reason = N'MBA-903 test';
    INSERT @Out SELECT N'1 create', N'1b partial: 1 request, itemCount 1, rejectedItemCount 1',
           N'1/1/1', CONCAT((SELECT COUNT(*) FROM #R), N'/', MAX(itemCount), N'/', MAX(rejectedItemCount)),
           IIF(COUNT(*) = 1 AND MAX(itemCount) = 1 AND MAX(rejectedItemCount) = 1 AND MAX(customerId) = @CustA,
               N'PASS', N'FAIL')
    FROM #R;
    ROLLBACK;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out SELECT N'1 create', N'1b partial', N'no error', LEFT(ERROR_MESSAGE(), 80), N'FAIL';
END CATCH;

/* 1c  only foreign ids -> 52004, raised before anything is written (the empty-request bug: the
       old procedure filed a request with zero items here). If the procedure wrongly succeeds, the
       rows it wrote are counted inside the transaction and then rolled back like every case. */
SET @Err = NULL; SET @N = NULL;
BEGIN TRY
    BEGIN TRAN;
    SET @Ids = CAST(@Foreign AS NVARCHAR(12));
    SELECT @Before = COUNT(*) FROM dbo.CustomerPortalRequest;
    INSERT @Out SELECT N'1 create', N'1c (probe) foreign item id resolved', N'found',
           IIF(@Foreign IS NULL, N'missing', N'found'), IIF(@Foreign IS NULL, N'FAIL', N'PASS');
    TRUNCATE TABLE #R;
    INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = @Multi,
        @RequestType = N'CalibrationCancellation', @ItemIds = @Ids, @Reason = N'MBA-903 test';
    SELECT @N = COUNT(*) - @Before FROM dbo.CustomerPortalRequest;
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @Err = ERROR_NUMBER();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH;
INSERT @Out SELECT N'1 create', N'1c all ids foreign -> THROW 52004, no request written', N'52004',
       COALESCE(CAST(@Err AS NVARCHAR(10)), CONCAT(N'no error, ', @N, N' request(s) written')),
       IIF(@Err = 52004, N'PASS', N'FAIL');

/* 1d  no ids at all is still legitimate -> one request under the primary customer */
BEGIN TRY
    BEGIN TRAN;
    TRUNCATE TABLE #R;
    INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = @Multi,
        @RequestType = N'ReportUpdate', @Reason = N'MBA-903 test';
    INSERT @Out SELECT N'1 create', N'1d no ids: 1 request, primary customer, 0 items',
           N'1/primary/0', CONCAT(COUNT(*), N'/', IIF(MAX(customerId) = @PrimaryCust, N'primary', N'other'), N'/', MAX(itemCount)),
           IIF(COUNT(*) = 1 AND MAX(customerId) = @PrimaryCust AND MAX(itemCount) = 0, N'PASS', N'FAIL')
    FROM #R;
    ROLLBACK;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out SELECT N'1 create', N'1d no ids', N'no error', LEFT(ERROR_MESSAGE(), 80), N'FAIL';
END CATCH;

/* 1e  single-customer request keeps @DeviceCount as passed; junk ids are dropped, not counted */
BEGIN TRY
    BEGIN TRAN;
    SET @Ids = CONCAT(N' , abc, 99999999999, ', @ItemA);
    TRUNCATE TABLE #R;
    INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = @Multi,
        @RequestType = N'Quote', @ItemIds = @Ids, @DeviceCount = 7, @CalibrationLocation = N'customer';
    SELECT @N = q.DeviceCount FROM #R INNER JOIN dbo.CustomerPortalRequest AS q
        ON q.CustomerPortalRequestId = #R.customerPortalRequestId;
    INSERT @Out SELECT N'1 create', N'1e one customer: DeviceCount 7 kept, junk ids dropped (0 rejected)',
           N'7/1/0', CONCAT(@N, N'/', MAX(itemCount), N'/', MAX(rejectedItemCount)),
           IIF(@N = 7 AND MAX(itemCount) = 1 AND MAX(rejectedItemCount) = 0, N'PASS', N'FAIL')
    FROM #R;
    ROLLBACK;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out SELECT N'1 create', N'1e device count / junk ids', N'no error', LEFT(ERROR_MESSAGE(), 80), N'FAIL';
END CATCH;

/* 1f  unknown address -> 52003 */
SET @Err = NULL;
BEGIN TRY
    BEGIN TRAN;
    TRUNCATE TABLE #R;
    INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = N'nobody.mba903@example.invalid',
        @RequestType = N'ReportUpdate', @Reason = N'MBA-903 test';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @Err = ERROR_NUMBER();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH;
INSERT @Out SELECT N'1 create', N'1f unknown address -> THROW 52003', N'52003',
       ISNULL(CAST(@Err AS NVARCHAR(10)), N'no error'), IIF(@Err = 52003, N'PASS', N'FAIL');

/* 1g  a site outside the caller's set -> 52005; one inside it is accepted */
IF @ForeignSite IS NULL
    INSERT @Out SELECT N'1 create', N'1g foreign site -> THROW 52005', N'52005', N'-', N'SKIP - no foreign site';
ELSE
BEGIN
    SET @Err = NULL;
    BEGIN TRY
        BEGIN TRAN;
        SET @Ids = CAST(@ItemA AS NVARCHAR(12));
        TRUNCATE TABLE #R;
        INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = @Multi,
            @RequestType = N'Shipment', @ItemIds = @Ids, @ShippingMethod = N'DHL',
            @RequestedDate = '2027-01-01', @CustomerSiteId = @ForeignSite;
        ROLLBACK;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_NUMBER();
        IF @@TRANCOUNT > 0 ROLLBACK;
    END CATCH;
    INSERT @Out SELECT N'1 create', N'1g foreign site -> THROW 52005', N'52005',
           ISNULL(CAST(@Err AS NVARCHAR(10)), N'no error'), IIF(@Err = 52005, N'PASS', N'FAIL');
END;

IF @OwnSite IS NULL
    INSERT @Out SELECT N'1 create', N'1g own site accepted', N'1 row', N'-', N'SKIP - caller has no site';
ELSE
BEGIN
    BEGIN TRY
        BEGIN TRAN;
        SET @Ids = CAST(@ItemA AS NVARCHAR(12));
        TRUNCATE TABLE #R;
        INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = @Multi,
            @RequestType = N'Shipment', @ItemIds = @Ids, @ShippingMethod = N'DHL',
            @RequestedDate = '2027-01-01', @CustomerSiteId = @OwnSite;
        INSERT @Out SELECT N'1 create', N'1g own site accepted', N'1 row',
               CONCAT((SELECT COUNT(*) FROM #R), N' row'), IIF((SELECT COUNT(*) FROM #R) = 1, N'PASS', N'FAIL');
        ROLLBACK;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        INSERT @Out SELECT N'1 create', N'1g own site accepted', N'no error', LEFT(ERROR_MESSAGE(), 80), N'FAIL';
    END CATCH;
END;


/* =============================================================================================
   Section 1b - review of PR #19: a split must not carry one customer's objects onto another's
   request, and every reference must be the caller's
   ============================================================================================= */
DECLARE @SiteA INT, @SiteALabelPart NVARCHAR(200), @NonPrimarySite INT, @NonPrimarySiteCust INT, @SiteCaller NVARCHAR(100),
        @ReportNo NVARCHAR(100), @ReportItem INT, @ReportCust INT, @ForeignReportNo NVARCHAR(100),
        @OrderB INT, @ForeignOrder INT;

SELECT TOP (1) @SiteA = cs.CustomerSiteId,
       @SiteALabelPart = LTRIM(RTRIM(COALESCE(cs.CustomerSiteDescription, cs.CustomerSiteAddress, N'')))
FROM dbo.CustomerSites AS cs
WHERE cs.CustomerId = @CustA AND ISNULL(cs.IsDeleted, 0) = 0
  AND LTRIM(RTRIM(COALESCE(cs.CustomerSiteDescription, cs.CustomerSiteAddress, N''))) <> N''
ORDER BY cs.CustomerSiteId;

/* 1i needs its own caller: an address with a site under a NON-primary customer of its set */
;WITH live AS
(
    SELECT DISTINCT wp.CustomerId
    FROM dbo.OrderWorkPlans AS wp
    INNER JOIN dbo.OrderDetails      AS od ON od.OrderWorkPlanId = wp.OrderWorkPlanId
    INNER JOIN dbo.OrderDetailsItems AS it ON it.OrderDetailId   = od.OrderDetailId
),
multi AS
(
    SELECT LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) AS Email
    FROM dbo.CustomerContacts AS cc
    INNER JOIN live ON live.CustomerId = cc.CustomerId
    WHERE cc.IsDeleted = 0 AND ISNULL(cc.IsActive, 1) = 1 AND cc.CustomerContactEmail LIKE N'%_@_%'
    GROUP BY LOWER(LTRIM(RTRIM(cc.CustomerContactEmail)))
    HAVING COUNT(DISTINCT cc.CustomerId) >= 2
)
SELECT TOP (1) @SiteCaller = multi.Email, @NonPrimarySite = cs.CustomerSiteId, @NonPrimarySiteCust = cs.CustomerId
FROM multi
CROSS APPLY dbo.GetPortalCustomerIds(multi.Email) AS mine
INNER JOIN dbo.CustomerSites AS cs ON cs.CustomerId = mine.CustomerId AND ISNULL(cs.IsDeleted, 0) = 0
WHERE mine.IsPrimary = 0
ORDER BY multi.Email, cs.CustomerSiteId;

/* a report number carried by exactly one live item, of a customer in the set */
SELECT TOP (1) @ReportNo = LTRIM(RTRIM(it.MbaReportNumber)), @ReportItem = MIN(it.OrderDetailsItemId), @ReportCust = MIN(wp.CustomerId)
FROM dbo.OrderDetailsItems AS it
INNER JOIN dbo.OrderDetails   AS od ON od.OrderDetailId   = it.OrderDetailId AND ISNULL(od.IsDeleted, 0) = 0
INNER JOIN dbo.OrderWorkPlans AS wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
WHERE ISNULL(it.IsDeleted, 0) = 0 AND NULLIF(LTRIM(RTRIM(it.MbaReportNumber)), N'') IS NOT NULL
  AND wp.CustomerId IN (SELECT CustomerId FROM dbo.GetPortalCustomerIds(@Multi))
GROUP BY LTRIM(RTRIM(it.MbaReportNumber))
HAVING COUNT(*) = 1
ORDER BY LTRIM(RTRIM(it.MbaReportNumber));

SELECT TOP (1) @ForeignReportNo = LTRIM(RTRIM(it.MbaReportNumber))
FROM dbo.OrderDetailsItems AS it
INNER JOIN dbo.OrderDetails   AS od ON od.OrderDetailId   = it.OrderDetailId
INNER JOIN dbo.OrderWorkPlans AS wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
WHERE NULLIF(LTRIM(RTRIM(it.MbaReportNumber)), N'') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.OrderDetailsItems AS i2
                  INNER JOIN dbo.OrderDetails   AS o2 ON o2.OrderDetailId   = i2.OrderDetailId
                  INNER JOIN dbo.OrderWorkPlans AS w2 ON w2.OrderWorkPlanId = o2.OrderWorkPlanId
                  WHERE LTRIM(RTRIM(i2.MbaReportNumber)) = LTRIM(RTRIM(it.MbaReportNumber))
                    AND w2.CustomerId IN (SELECT CustomerId FROM dbo.GetPortalCustomerIds(@Multi)))
ORDER BY it.OrderDetailsItemId;

SELECT @OrderB = od.OrderWorkPlanId
FROM dbo.OrderDetailsItems AS it INNER JOIN dbo.OrderDetails AS od ON od.OrderDetailId = it.OrderDetailId
WHERE it.OrderDetailsItemId = @ItemB;

SELECT @ForeignOrder = od.OrderWorkPlanId
FROM dbo.OrderDetailsItems AS it INNER JOIN dbo.OrderDetails AS od ON od.OrderDetailId = it.OrderDetailId
WHERE it.OrderDetailsItemId = @Foreign;

/* 1h  split + A's site: the site only on A's request; B's request has no site id and names it */
IF @SiteA IS NULL
    INSERT @Out SELECT N'1b review', N'1h split with a site', N'-', N'-', N'SKIP - customer A has no named site';
ELSE
BEGIN
    BEGIN TRY
        BEGIN TRAN;
        SET @Ids = CONCAT(@ItemA, N',', @ItemB);
        TRUNCATE TABLE #R;
        INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = @Multi,
            @RequestType = N'Shipment', @ItemIds = @Ids, @ShippingMethod = N'DHL', @RequestedDate = '2027-01-01',
            @CustomerSiteId = @SiteA, @DeviceLocation = N'gate 3';
        SELECT @N = COUNT(*) FROM #R INNER JOIN dbo.CustomerPortalRequest AS q ON q.CustomerPortalRequestId = #R.customerPortalRequestId
        WHERE q.CustomerId = @CustA AND q.CustomerSiteId = @SiteA AND q.DeviceLocation = N'gate 3';
        SELECT @M = COUNT(*) FROM #R INNER JOIN dbo.CustomerPortalRequest AS q ON q.CustomerPortalRequestId = #R.customerPortalRequestId
        WHERE q.CustomerId = @CustB AND q.CustomerSiteId IS NULL
          AND q.DeviceLocation LIKE N'gate 3 | %' AND CHARINDEX(@SiteALabelPart, q.DeviceLocation) > 0;
        INSERT @Out SELECT N'1b review', N'1h A keeps its site; B gets no site id, location names it', N'1/1',
               CONCAT(@N, N'/', @M), IIF(@N = 1 AND @M = 1, N'PASS', N'FAIL');
        ROLLBACK;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        INSERT @Out SELECT N'1b review', N'1h split with a site', N'no error', LEFT(ERROR_MESSAGE(), 80), N'FAIL';
    END CATCH;
END;

/* 1i  no items, a non-primary customer's site -> filed under the site's customer */
IF @NonPrimarySite IS NULL
    INSERT @Out SELECT N'1b review', N'1i no items + site', N'-', N'-', N'SKIP - no site of a non-primary customer';
ELSE
BEGIN
    BEGIN TRY
        BEGIN TRAN;
        TRUNCATE TABLE #R;
        INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = @SiteCaller,
            @RequestType = N'Quote', @CalibrationLocation = N'customer', @CustomerSiteId = @NonPrimarySite;
        INSERT @Out SELECT N'1b review', N'1i no items + site -> the site''s customer, not the primary',
               N'site customer', IIF(MAX(customerId) = @NonPrimarySiteCust, N'site customer', N'other'),
               IIF(COUNT(*) = 1 AND MAX(customerId) = @NonPrimarySiteCust, N'PASS', N'FAIL')
        FROM #R;
        ROLLBACK;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        INSERT @Out SELECT N'1b review', N'1i no items + site', N'no error', LEFT(ERROR_MESSAGE(), 80), N'FAIL';
    END CATCH;
END;

/* 1j  own report number -> its item, under the item's customer */
IF @ReportNo IS NULL
    INSERT @Out SELECT N'1b review', N'1j own report number', N'-', N'-', N'SKIP - no single-item report in the set';
ELSE
BEGIN
    BEGIN TRY
        BEGIN TRAN;
        TRUNCATE TABLE #R;
        INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = @Multi,
            @RequestType = N'ReportUpdate', @MbaReportNumber = @ReportNo, @Reason = N'MBA-903 test';
        INSERT @Out SELECT N'1b review', N'1j own report number -> 1 item, the item''s customer',
               N'1/1/owner', CONCAT(COUNT(*), N'/', MAX(itemCount), N'/', IIF(MAX(customerId) = @ReportCust, N'owner', N'other')),
               IIF(COUNT(*) = 1 AND MAX(itemCount) = 1 AND MAX(customerId) = @ReportCust, N'PASS', N'FAIL')
        FROM #R;
        ROLLBACK;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        INSERT @Out SELECT N'1b review', N'1j own report number', N'no error', LEFT(ERROR_MESSAGE(), 80), N'FAIL';
    END CATCH;
END;

/* 1k  another customer's report number -> 52007 */
SET @Err = NULL;
BEGIN TRY
    BEGIN TRAN;
    TRUNCATE TABLE #R;
    INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = @Multi,
        @RequestType = N'ReportUpdate', @MbaReportNumber = @ForeignReportNo, @Reason = N'MBA-903 test';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @Err = ERROR_NUMBER();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH;
INSERT @Out SELECT N'1b review', N'1k foreign report number -> THROW 52007', N'52007',
       ISNULL(CAST(@Err AS NVARCHAR(10)), N'no error'), IIF(@Err = 52007, N'PASS', N'FAIL');

/* 1l  another customer's order -> 52008 */
SET @Err = NULL;
BEGIN TRY
    BEGIN TRAN;
    TRUNCATE TABLE #R;
    INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = @Multi,
        @RequestType = N'Shipment', @OrderWorkPlanId = @ForeignOrder, @ShippingMethod = N'DHL', @RequestedDate = '2027-01-01';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @Err = ERROR_NUMBER();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH;
INSERT @Out SELECT N'1b review', N'1l foreign order -> THROW 52008', N'52008',
       ISNULL(CAST(@Err AS NVARCHAR(10)), N'no error'), IIF(@Err = 52008, N'PASS', N'FAIL');

/* 1m  own order of B, no items -> filed under B, not the primary */
BEGIN TRY
    BEGIN TRAN;
    TRUNCATE TABLE #R;
    INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = @Multi,
        @RequestType = N'Shipment', @OrderWorkPlanId = @OrderB, @ShippingMethod = N'DHL', @RequestedDate = '2027-01-01';
    INSERT @Out SELECT N'1b review', N'1m own order, no items -> the order''s customer',
           N'B', IIF(MAX(customerId) = @CustB, N'B', N'other'),
           IIF(COUNT(*) = 1 AND MAX(customerId) = @CustB, N'PASS', N'FAIL')
    FROM #R;
    ROLLBACK;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out SELECT N'1b review', N'1m own order', N'no error', LEFT(ERROR_MESSAGE(), 80), N'FAIL';
END CATCH;

/* 1n  B's order together with A's item -> 52010, not copied onto A's request */
SET @Err = NULL;
BEGIN TRY
    BEGIN TRAN;
    SET @Ids = CAST(@ItemA AS NVARCHAR(12));
    TRUNCATE TABLE #R;
    INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = @Multi,
        @RequestType = N'Shipment', @ItemIds = @Ids, @OrderWorkPlanId = @OrderB, @ShippingMethod = N'DHL', @RequestedDate = '2027-01-01';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @Err = ERROR_NUMBER();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH;
INSERT @Out SELECT N'1b review', N'1n B''s order + A''s item -> THROW 52010', N'52010',
       ISNULL(CAST(@Err AS NVARCHAR(10)), N'no error'), IIF(@Err = 52010, N'PASS', N'FAIL');

/* 1o  another customer's device -> 52009 (CustomerDevices is empty, so the case makes its own) */
SET @Err = NULL;
BEGIN TRY
    BEGIN TRAN;
    INSERT dbo.CustomerDevices (CustomerId, SerialNumber)
    SELECT wp.CustomerId, N'MBA903-FOREIGN-SRC'
    FROM dbo.OrderDetailsItems AS it
    INNER JOIN dbo.OrderDetails   AS od ON od.OrderDetailId   = it.OrderDetailId
    INNER JOIN dbo.OrderWorkPlans AS wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
    WHERE it.OrderDetailsItemId = @Foreign;
    SET @N = CAST(SCOPE_IDENTITY() AS INT);
    TRUNCATE TABLE #R;
    INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = @Multi,
        @RequestType = N'DeviceRemoval', @CustomerDeviceId = @N, @Reason = N'MBA-903 test';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @Err = ERROR_NUMBER();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH;
INSERT @Out SELECT N'1b review', N'1o foreign device -> THROW 52009', N'52009',
       ISNULL(CAST(@Err AS NVARCHAR(10)), N'no error'), IIF(@Err = 52009, N'PASS', N'FAIL');


/* =============================================================================================
   Section 2 - ResolveCustomerPortalRequest
   Each case files a fresh request for @CustA's item, then acts on it, inside one transaction.
   ============================================================================================= */

/* 2a  the filer cancels a New request -> Cancelled */
BEGIN TRY
    BEGIN TRAN;
    SET @Ids = CAST(@ItemA AS NVARCHAR(12));
    TRUNCATE TABLE #R;
    INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = @Multi,
        @RequestType = N'CalibrationExtension', @ItemIds = @Ids, @RequestedDate = '2027-01-01', @Reason = N'MBA-903 test';
    SELECT @Req = customerPortalRequestId FROM #R;
    TRUNCATE TABLE #Res;
    INSERT #Res EXEC dbo.ResolveCustomerPortalRequest @LoggedInUserEmail = @Multi,
        @CustomerPortalRequestId = @Req, @Status = N'Cancelled';
    INSERT @Out SELECT N'2 resolve', N'2a customer cancels own New request', N'Cancelled',
           q.Status, IIF(q.Status = N'Cancelled' AND q.ResolvedDate IS NOT NULL, N'PASS', N'FAIL')
    FROM dbo.CustomerPortalRequest AS q WHERE q.CustomerPortalRequestId = @Req;
    ROLLBACK;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out SELECT N'2 resolve', N'2a customer cancels own New request', N'no error', LEFT(ERROR_MESSAGE(), 80), N'FAIL';
END CATCH;

/* 2b  once MBA has moved it to InProgress, the customer can no longer cancel -> 52016 */
IF @Staff IS NULL
    INSERT @Out SELECT N'2 resolve', N'2b cancel after InProgress -> THROW 52016', N'52016', N'-', N'SKIP - no staff user';
ELSE
BEGIN
    SET @Err = NULL;
    BEGIN TRY
        BEGIN TRAN;
        SET @Ids = CAST(@ItemA AS NVARCHAR(12));
        TRUNCATE TABLE #R;
        INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = @Multi,
            @RequestType = N'CalibrationExtension', @ItemIds = @Ids, @RequestedDate = '2027-01-01', @Reason = N'MBA-903 test';
        SELECT @Req = customerPortalRequestId FROM #R;
        TRUNCATE TABLE #Res;
        INSERT #Res EXEC dbo.ResolveCustomerPortalRequest @LoggedInUserEmail = @Staff,
            @CustomerPortalRequestId = @Req, @Status = N'InProgress';
        TRUNCATE TABLE #Res;
        INSERT #Res EXEC dbo.ResolveCustomerPortalRequest @LoggedInUserEmail = @Multi,
            @CustomerPortalRequestId = @Req, @Status = N'Cancelled';
        ROLLBACK;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_NUMBER();
        IF @@TRANCOUNT > 0 ROLLBACK;
    END CATCH;
    INSERT @Out SELECT N'2 resolve', N'2b cancel after InProgress -> THROW 52016', N'52016',
           ISNULL(CAST(@Err AS NVARCHAR(10)), N'no error'), IIF(@Err = 52016, N'PASS', N'FAIL');
END;

/* 2c  an address whose set does not hold the request's customer -> 52014 */
IF @Other IS NULL
    INSERT @Out SELECT N'2 resolve', N'2c stranger cancels -> THROW 52014', N'52014', N'-', N'SKIP - no other address';
ELSE
BEGIN
    SET @Err = NULL;
    BEGIN TRY
        BEGIN TRAN;
        SET @Ids = CAST(@ItemA AS NVARCHAR(12));
        TRUNCATE TABLE #R;
        INSERT #R EXEC dbo.CreateCustomerPortalRequest @LoggedInUserEmail = @Multi,
            @RequestType = N'CalibrationExtension', @ItemIds = @Ids, @RequestedDate = '2027-01-01', @Reason = N'MBA-903 test';
        SELECT @Req = customerPortalRequestId FROM #R;
        TRUNCATE TABLE #Res;
        INSERT #Res EXEC dbo.ResolveCustomerPortalRequest @LoggedInUserEmail = @Other,
            @CustomerPortalRequestId = @Req, @Status = N'Cancelled';
        ROLLBACK;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_NUMBER();
        IF @@TRANCOUNT > 0 ROLLBACK;
    END CATCH;
    INSERT @Out SELECT N'2 resolve', N'2c stranger cancels -> THROW 52014', N'52014',
           ISNULL(CAST(@Err AS NVARCHAR(10)), N'no error'), IIF(@Err = 52014, N'PASS', N'FAIL');
END;


/* =============================================================================================
   Section 3 - DuplicateCustomerDevice
   dbo.CustomerDevices is empty on STAGE (2026-09-30), so each case inserts its own source device -
   only CustomerId is required - inside the transaction it rolls back. The caller's own device is
   put under a customer of the set that the old TOP (1) rule would NOT have picked, so 3a can only
   pass through the set.
   ============================================================================================= */
DECLARE @DevId INT, @ForeignDev INT, @ForeignCust INT, @SiteElsewhere INT, @Serial NVARCHAR(100),
        @Top1Cust INT, @DevCust INT;

SELECT TOP (1) @Top1Cust = cc.CustomerId
FROM dbo.CustomerContacts AS cc
WHERE cc.IsDeleted = 0 AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @Multi
ORDER BY cc.CustomerContactId;
SET @DevCust = IIF(@CustB <> @Top1Cust, @CustB, @CustA);

SELECT @ForeignCust = wp.CustomerId
FROM dbo.OrderDetailsItems AS it
INNER JOIN dbo.OrderDetails   AS od ON od.OrderDetailId   = it.OrderDetailId
INNER JOIN dbo.OrderWorkPlans AS wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
WHERE it.OrderDetailsItemId = @Foreign;

SELECT TOP (1) @SiteElsewhere = cs.CustomerSiteId
FROM dbo.CustomerSites AS cs
WHERE cs.CustomerId <> @DevCust AND ISNULL(cs.IsDeleted, 0) = 0
ORDER BY cs.CustomerSiteId;

/* 3a  copy with a new serial -> one copy, under the source device's customer, no date inherited */
BEGIN TRY
    BEGIN TRAN;
    INSERT dbo.CustomerDevices (CustomerId, SerialNumber, NextCalibrationDate)
    VALUES (@DevCust, N'MBA903-SRC', '2027-06-01');
    SET @DevId = CAST(SCOPE_IDENTITY() AS INT);
    SET @Serial = CONCAT(N'MBA903-', LEFT(REPLACE(CAST(NEWID() AS NVARCHAR(36)), N'-', N''), 12));
    TRUNCATE TABLE #Dup;
    INSERT #Dup EXEC dbo.DuplicateCustomerDevice @LoggedInUserEmail = @Multi,
        @CustomerDeviceId = @DevId, @SerialNumbers = @Serial;
    SELECT @N = COUNT(*) FROM #Dup INNER JOIN dbo.CustomerDevices AS d ON d.CustomerDeviceID = #Dup.customerDeviceId
    WHERE d.CustomerId = @DevCust AND d.NextCalibrationDate IS NULL AND d.SerialNumber = @Serial
      AND d.CustomerDeviceID <> @DevId;
    INSERT @Out SELECT N'3 duplicate', N'3a copy lands under the source device''s customer, no date', N'1',
           CAST(@N AS NVARCHAR(10)), IIF(@N = 1, N'PASS', N'FAIL');
    ROLLBACK;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out SELECT N'3 duplicate', N'3a copy', N'no error', LEFT(ERROR_MESSAGE(), 80), N'FAIL';
END CATCH;

/* 3b  a device of a customer outside the caller's set -> 52022 */
SET @Err = NULL;
BEGIN TRY
    BEGIN TRAN;
    INSERT dbo.CustomerDevices (CustomerId, SerialNumber) VALUES (@ForeignCust, N'MBA903-FOREIGN-SRC');
    SET @ForeignDev = CAST(SCOPE_IDENTITY() AS INT);
    TRUNCATE TABLE #Dup;
    INSERT #Dup EXEC dbo.DuplicateCustomerDevice @LoggedInUserEmail = @Multi,
        @CustomerDeviceId = @ForeignDev, @SerialNumbers = N'MBA903-FOREIGN';
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @Err = ERROR_NUMBER();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH;
INSERT @Out SELECT N'3 duplicate', N'3b foreign device -> THROW 52022', N'52022',
       ISNULL(CAST(@Err AS NVARCHAR(10)), N'no error'), IIF(@Err = 52022, N'PASS', N'FAIL');

/* 3c  a site of another customer -> 52025 */
IF @SiteElsewhere IS NULL
    INSERT @Out SELECT N'3 duplicate', N'3c other customer''s site -> THROW 52025', N'52025', N'-', N'SKIP - no such site';
ELSE
BEGIN
    SET @Err = NULL;
    BEGIN TRY
        BEGIN TRAN;
        INSERT dbo.CustomerDevices (CustomerId, SerialNumber) VALUES (@DevCust, N'MBA903-SRC');
        SET @DevId = CAST(SCOPE_IDENTITY() AS INT);
        TRUNCATE TABLE #Dup;
        INSERT #Dup EXEC dbo.DuplicateCustomerDevice @LoggedInUserEmail = @Multi,
            @CustomerDeviceId = @DevId, @SerialNumbers = N'MBA903-SITE', @CustomerSiteId = @SiteElsewhere;
        ROLLBACK;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_NUMBER();
        IF @@TRANCOUNT > 0 ROLLBACK;
    END CATCH;
    INSERT @Out SELECT N'3 duplicate', N'3c other customer''s site -> THROW 52025', N'52025',
           ISNULL(CAST(@Err AS NVARCHAR(10)), N'no error'), IIF(@Err = 52025, N'PASS', N'FAIL');
END;


SELECT Seq, Section, Test, Expected, Actual, Result FROM @Out ORDER BY Seq;
