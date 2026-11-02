/*
    Tests for the customer-portal read procedures                                      MBA-1014
        every read procedure the app's customer router calls, plus dbo.GetCustomerSites
    ---------------------------------------------------------------------------------------------
    The write procedures' ownership checks are covered by Test-CustomerPortalRequest.sql and
    Test-AssignCustomerContactsSitesData.sql. This file covers the reads: a portal caller must get
    back only rows of the customers in dbo.GetPortalCustomerIds(caller), and an address that is not
    a live portal identity must get nothing.

    Run against a database where the procedures and dbo.GetPortalCustomerIds are deployed.
    Anything other than 'PASS' in Result is a failure; 'SKIP' says why the case could not run.

    Every case runs in its own transaction and is rolled back. Only the inactive-contact case
    writes anything (it deactivates one address for the length of its transaction), but the
    pattern is kept for every case so the file can never leave a trace. Results are kept in a
    table variable, which a rollback does not touch; a temp table's rows do not survive it, so
    each case counts what it needs before it rolls back.

    The result tables below take tempdb's collation (Hebrew_CI_AS on STAGE), the database's own is
    Latin1_General_100_CI_AI_SC. Where a check compares one with a table of the database it says
    COLLATE DATABASE_DEFAULT on the result side.

    Fixtures are picked from the data, never hard-coded - identities differ between STAGE and PROD.
    No address is printed; the output names cases, not people.

        @Me          an active address whose portal set holds live items under two customers,
                     preferring a set that also has a site and a report
        @OwnItem     a live item of a customer in @Me's set
        @ForeignItem a live item of a customer outside it - live by every filter the procedures
                     apply, so an empty result can only come from the ownership check
        @Inactive    an active address of somebody else; the inactive case deactivates all of its
                     contact rows inside the transaction. STAGE has no address whose rows are all
                     inactive (2026-11-02), so the case makes one rather than SKIP. A control row
                     shows the same address does see devices while it is active.
        @Staff       an MBA user (dbo.Users) who is not a customer contact and is mapped to no
                     customer. Users.CustomerId is the documented staff path of GetCustomerProfile,
                     GetCustomerSupportData, GetCustomerSites and GetCustomerContacts - a user
                     carrying one is meant to see that customer - so it is left out here.
        @Unknown     an address that exists nowhere
        @OwnOrder, @ForeignOrder, @Calibrator
                     an open order of the set, one of another customer, and a calibrator. STAGE has
                     no calibrator visit dated today or later (2026-11-02), so the upcoming-visit
                     cases book two inside their transaction: one on @OwnOrder in two days and an
                     earlier one on @ForeignOrder tomorrow. Only the first may reach @Me.

    Cases
        R1  @Unknown, @Staff and @Inactive get no rows from every procedure.
        R2  every row @Me gets maps back to a customer of the set: through the customer or item id
            where the result has one, otherwise through the order number, the report path, the
            calibrator assignment or the serial + customer name it carries.
        R3  GetCustomerDeviceDetail: @ForeignItem gives 0 rows, @OwnItem gives 1.
        R4  GetCustomerCalibrationReports: no report of another customer, and every reportPath
            points at the item's own order - getCustomerReportUrl presigns exactly that path.
        R5  GetCustomerSites: no site of another customer, mapped through the site id itself -
            createPortalRequest accepts a site only if it is in this list.
        R6  GetCustomerDashboardData: the search text is searched for, not executed.

    The two *FromPriority procedures read Priority over the linked server. When it does not answer,
    their R2 case is a SKIP. GetCustomerQuotesFromPriority fills a temp table with INSERT ... EXEC
    of its own, and SQL Server does not allow that inside the harness's INSERT ... EXEC (error
    8164), so its R2 rows cannot be captured from T-SQL and the case reports SKIP. Its R1 cases do
    run: for those callers it returns before reaching that statement.
*/
SET NOCOUNT ON;
SET XACT_ABORT OFF;   /* a failing procedure must not take the harness down with it */

DECLARE @Out TABLE (Seq INT IDENTITY, Section NVARCHAR(14), Test NVARCHAR(100),
                    Expected NVARCHAR(80), Actual NVARCHAR(80), Result NVARCHAR(80));

/* One table per procedure, in the shape of its result set */
DROP TABLE IF EXISTS #Dash;
CREATE TABLE #Dash (DeviceStatus NVARCHAR(400), CalibratioinDate DATETIME2, NextCalibrationDate DATETIME2,
                    CalibratioinLocation NVARCHAR(20), DeviceDescription NVARCHAR(400), SerialNumber NVARCHAR(200),
                    ActualReturnDate DATETIME2, CalibratorId INT, CalibratorFirstName NVARCHAR(100),
                    CalibratorLastName NVARCHAR(100), CalibratorPhoneNumber NVARCHAR(50), CalibratorAssigmentDate DATETIME2,
                    CustomerName NVARCHAR(400), OverallDevicesCount INT, ExpiredevicesCount INT, CalibratedDevicesCount INT,
                    DevicesWaitingForCalibrationCount INT, ItemsCount INT);
DROP TABLE IF EXISTS #Up;
CREATE TABLE #Up (FirstName NVARCHAR(50), LastName NVARCHAR(50), Email NVARCHAR(50), Phone NVARCHAR(20),
                  AssigmentDate DATETIME2(0));
DROP TABLE IF EXISTS #Sup;
CREATE TABLE #Sup (FirstName NVARCHAR(50), LastName NVARCHAR(50), Email NVARCHAR(50), Phone NVARCHAR(20));
DROP TABLE IF EXISTS #Prof;
CREATE TABLE #Prof (CustomerId INT, SiteNumber NVARCHAR(50), MainSiteName NVARCHAR(50), MainSiteNameENG NVARCHAR(48),
                    AccountName NVARCHAR(50), AccountNameENG NVARCHAR(48), ReportLanguage NVARCHAR(2),
                    SiteAddress NVARCHAR(132), SiteAddressENG NVARCHAR(122), SitePhone NVARCHAR(50),
                    ReportRequired NVARCHAR(50), ShippingMethod NVARCHAR(50), SignatureAmount TINYINT,
                    SubSitesCount INT, RelatedCompaniesCount INT);
DROP TABLE IF EXISTS #Ship;
CREATE TABLE #Ship (id INT, orderNumber NVARCHAR(20), mbaReportNumber NVARCHAR(100), serialNumber NVARCHAR(50),
                    deviceDescription NVARCHAR(100), deviceManufacturer NVARCHAR(100), deviceModel NVARCHAR(100),
                    sku NVARCHAR(100), site NVARCHAR(50), shippingMethod NVARCHAR(100), shippingDoc NVARCHAR(30),
                    shippingAddress NVARCHAR(150), receivingDate VARCHAR(10), calibrationDate VARCHAR(10),
                    expectedReturnDate VARCHAR(10), deliveryDate VARCHAR(10), status NVARCHAR(402), statusLabel NVARCHAR(255));
DROP TABLE IF EXISTS #Site;
CREATE TABLE #Site (CustomerId INT, CustomerName NVARCHAR(50), CustomerSiteId INT, CustomerSiteAddress NVARCHAR(80),
                    CustomerSiteState NVARCHAR(40), CustomerSiteZIP NVARCHAR(10), CustomerSitePhone NVARCHAR(30),
                    CustomerSiteDescription NVARCHAR(50), CustomerSiteCode INT, CreateDate DATETIME2(0),
                    UpdatedDate DATETIME2(0), UpdateUserID INT, SourceId TINYINT, SourceName NVARCHAR(100),
                    CustomerSiteAddressENG NVARCHAR(80), CustomerSiteStateENG NVARCHAR(40),
                    CustomerSiteDescriptionENG NVARCHAR(50), IsDeleted BIT);
DROP TABLE IF EXISTS #Cont;
CREATE TABLE #Cont (CustomerContactId INT, CustomerId INT, CustomerName NVARCHAR(50), CustomerContactName NVARCHAR(400),
                    CustomerContactPersonRole NVARCHAR(400), CustomerContactPhone NVARCHAR(50),
                    CustomerContactAdditionalPhoneNumber NVARCHAR(50), CustomerContactEmail NVARCHAR(50),
                    SourceId TINYINT, SourceName NVARCHAR(100), CustomerSiteId INT, IsDeleted BIT);
DROP TABLE IF EXISTS #Req;
CREATE TABLE #Req (status NVARCHAR(402), quoteNumber NVARCHAR(20), deviceCount INT, expectedCalibrationDate VARCHAR(10),
                   calibrationLocation VARCHAR(8), price DECIMAL(18,2), note NVARCHAR(255), customerName NVARCHAR(50));
DROP TABLE IF EXISTS #Inv;
CREATE TABLE #Inv (invoiceNumber NVARCHAR(50), invoiceDate VARCHAR(10), totalPrice FLOAT, balance FLOAT, isPaid BIT,
                   documentType NVARCHAR(100), isReceipt BIT, documentDirectory NVARCHAR(400), documentFileSize BIGINT,
                   hasDocument BIT);
DROP TABLE IF EXISTS #Quo;
CREATE TABLE #Quo (quoteNumber NVARCHAR(50), quoteDate VARCHAR(10), validUntil VARCHAR(10), totalPrice FLOAT,
                   finalPrice FLOAT, discount FLOAT, statusCode NVARCHAR(50));
DROP TABLE IF EXISTS #Dev;
CREATE TABLE #Dev (id INT, deviceStatus NVARCHAR(402), lastCalibration VARCHAR(10), nextCalibration VARCHAR(10),
                   serialNumber NVARCHAR(200), calibrationLocation NVARCHAR(20), deviceDescription NVARCHAR(400),
                   deviceManufacturer NVARCHAR(400), deviceModel NVARCHAR(400), sku NVARCHAR(400),
                   shippingMethod NVARCHAR(400), lastReport NVARCHAR(100), customerName NVARCHAR(400));
DROP TABLE IF EXISTS #Rep;
CREATE TABLE #Rep (id INT, orderNumber NVARCHAR(20), reportPath NVARCHAR(59), mbaReportNumber NVARCHAR(100),
                   serialNumber NVARCHAR(50), deviceDescription NVARCHAR(100), deviceManufacturer NVARCHAR(100),
                   deviceModel NVARCHAR(100), calibrationDate VARCHAR(10), reportStatus NVARCHAR(402),
                   reportStatusHeb NVARCHAR(255), customerName NVARCHAR(50));
DROP TABLE IF EXISTS #Det;
CREATE TABLE #Det (id INT, deviceStatus NVARCHAR(402), deviceStatusHeb NVARCHAR(255), lastCalibration VARCHAR(10),
                   nextCalibration VARCHAR(10), serialNumber NVARCHAR(50), sku NVARCHAR(100),
                   additionalDeviceNumber NVARCHAR(100), calibrationLocation NVARCHAR(5), deviceDescription NVARCHAR(100),
                   deviceManufacturer NVARCHAR(100), deviceModel NVARCHAR(100), mainCategory NVARCHAR(50),
                   secondaryCategory NVARCHAR(50), accuracy TINYINT, measurementUnit NVARCHAR(50),
                   productLocation NVARCHAR(50), siteAddress NVARCHAR(100), shippingMethod NVARCHAR(100),
                   orderNumber NVARCHAR(20), lastReport NVARCHAR(100), calibratorFullName NVARCHAR(101),
                   calibratorPhone NVARCHAR(20), customerName NVARCHAR(50), calibrationDate VARCHAR(10),
                   calibrationSpecification NVARCHAR(50), calibrationMethod NVARCHAR(100), referenceDocument NVARCHAR(50),
                   tolerance DECIMAL(18,6), resolution DECIMAL(18,6), requiredProbability TINYINT,
                   visualCheck NVARCHAR(200), reportLanguage NVARCHAR(50), calibrationComment NVARCHAR(1000),
                   measurementUnitLong NVARCHAR(100));

/* ---------------------------------------------------------------------------------------------
   Fixtures
   --------------------------------------------------------------------------------------------- */
DECLARE @Me NVARCHAR(100), @Inactive NVARCHAR(100), @Staff NVARCHAR(100),
        @Unknown NVARCHAR(100) = N'nobody.mba1014@example.invalid',
        @OwnItem INT, @ForeignItem INT, @ForeignReportItem INT, @ForeignSite INT,
        @OwnOrder INT, @ForeignOrder INT, @Calibrator INT;

/* live = what the device screens show: nothing cancelled or deleted at any level */
DROP TABLE IF EXISTS #Live;
SELECT wp.CustomerId, it.OrderDetailsItemId AS ItemId, it.MbaReportNumber
INTO #Live
FROM dbo.OrderWorkPlans AS wp
INNER JOIN dbo.OrderDetails      AS od ON od.OrderWorkPlanId = wp.OrderWorkPlanId
INNER JOIN dbo.OrderDetailsItems AS it ON it.OrderDetailId   = od.OrderDetailId
WHERE wp.IsCancelled = 0
  AND ISNULL(od.IsDeleted, 0) = 0 AND ISNULL(od.IsCancelled, 0) = 0
  AND ISNULL(it.IsDeleted, 0) = 0 AND ISNULL(it.IsCancelled, 0) = 0;

/* candidates for @Me: active addresses that are a contact of two customers with live items,
   expanded to their portal set */
DROP TABLE IF EXISTS #CandSet;
WITH cand AS
(
    SELECT LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) AS Email
    FROM dbo.CustomerContacts AS cc
    WHERE cc.IsDeleted = 0 AND cc.IsActive = 1 AND cc.CustomerContactEmail LIKE N'%_@_%'
      AND cc.CustomerId IN (SELECT CustomerId FROM #Live)
    GROUP BY LOWER(LTRIM(RTRIM(cc.CustomerContactEmail)))
    HAVING COUNT(DISTINCT cc.CustomerId) >= 2
)
SELECT cand.Email, mine.CustomerId
INTO #CandSet
FROM cand
CROSS APPLY dbo.GetPortalCustomerIds(cand.Email) AS mine;

/* what each candidate customer would let R2-R5 actually look at */
DROP TABLE IF EXISTS #CustFlags;
SELECT c.CustomerId,
       CASE WHEN EXISTS (SELECT 1 FROM #Live AS l WHERE l.CustomerId = c.CustomerId) THEN 1 ELSE 0 END AS HasLive,
       CASE WHEN EXISTS (SELECT 1 FROM dbo.CustomerSites AS cs
                         WHERE cs.CustomerId = c.CustomerId AND ISNULL(cs.IsDeleted, 0) = 0) THEN 1 ELSE 0 END AS HasSite,
       CASE WHEN EXISTS (SELECT 1 FROM #Live AS l
                         WHERE l.CustomerId = c.CustomerId AND LEN(l.MbaReportNumber) > 0) THEN 1 ELSE 0 END AS HasReport
INTO #CustFlags
FROM (SELECT DISTINCT CustomerId FROM #CandSet) AS c;

SELECT TOP (1) @Me = s.Email
FROM #CandSet AS s
INNER JOIN #CustFlags AS f ON f.CustomerId = s.CustomerId
GROUP BY s.Email
HAVING SUM(f.HasLive) >= 2
ORDER BY MAX(f.HasSite) DESC, MAX(f.HasReport) DESC, COUNT(*), s.Email;

/* @Me's set, its items and its orders - what every R2 check maps a row back to. Items are taken
   without the live filters: an item of the set is the caller's whatever its state. */
DROP TABLE IF EXISTS #Mine;
SELECT CustomerId INTO #Mine FROM dbo.GetPortalCustomerIds(@Me);

DROP TABLE IF EXISTS #MineItems;
SELECT it.OrderDetailsItemId AS ItemId, c.CustomerName, it.SerialNumber, it.MbaReportNumber, wp.OrderNumber
INTO #MineItems
FROM #Mine AS m
INNER JOIN dbo.OrderWorkPlans    AS wp ON wp.CustomerId      = m.CustomerId
INNER JOIN dbo.OrderDetails      AS od ON od.OrderWorkPlanId = wp.OrderWorkPlanId
INNER JOIN dbo.OrderDetailsItems AS it ON it.OrderDetailId   = od.OrderDetailId
LEFT JOIN dbo.Customers          AS c  ON c.CustomerId       = m.CustomerId;

DROP TABLE IF EXISTS #MineOrders;
SELECT DISTINCT wp.OrderNumber
INTO #MineOrders
FROM #Mine AS m
INNER JOIN dbo.OrderWorkPlans AS wp ON wp.CustomerId = m.CustomerId
WHERE wp.OrderNumber IS NOT NULL;

SELECT TOP (1) @OwnItem = l.ItemId
FROM #Live AS l
WHERE l.CustomerId IN (SELECT CustomerId FROM #Mine)
ORDER BY l.ItemId;

SELECT TOP (1) @ForeignItem = l.ItemId
FROM #Live AS l
WHERE l.CustomerId NOT IN (SELECT CustomerId FROM #Mine)
ORDER BY l.ItemId;

/* a report of another customer whose number no item of the set also carries */
SELECT TOP (1) @ForeignReportItem = l.ItemId
FROM #Live AS l
WHERE l.CustomerId NOT IN (SELECT CustomerId FROM #Mine)
  AND LEN(l.MbaReportNumber) > 0
  AND NOT EXISTS (SELECT 1 FROM #MineItems AS m WHERE m.MbaReportNumber = l.MbaReportNumber)
ORDER BY l.ItemId;

SELECT TOP (1) @OwnOrder = wp.OrderWorkPlanId
FROM dbo.OrderWorkPlans AS wp
WHERE wp.CustomerId IN (SELECT CustomerId FROM #Mine) AND wp.IsCancelled = 0
ORDER BY wp.OrderWorkPlanId;

SELECT TOP (1) @ForeignOrder = wp.OrderWorkPlanId
FROM dbo.OrderWorkPlans AS wp
WHERE wp.CustomerId NOT IN (SELECT CustomerId FROM #Mine) AND wp.IsCancelled = 0
ORDER BY wp.OrderWorkPlanId;

SELECT TOP (1) @Calibrator = u.ID
FROM dbo.Users AS u
WHERE u.Email LIKE N'%_@_%'
  AND EXISTS (SELECT 1 FROM dbo.CalibratorsToWorkPlan AS ctwp WHERE ctwp.CalibratorId = u.ID)
ORDER BY u.ID;

SELECT TOP (1) @ForeignSite = cs.CustomerSiteId
FROM dbo.CustomerSites AS cs
WHERE cs.CustomerId NOT IN (SELECT CustomerId FROM #Mine) AND ISNULL(cs.IsDeleted, 0) = 0
ORDER BY cs.CustomerSiteId;

/* somebody else's active address with live items, and no staff account: once deactivated, no
   path in any procedure may resolve it */
SELECT TOP (1) @Inactive = LOWER(LTRIM(RTRIM(cc.CustomerContactEmail)))
FROM dbo.CustomerContacts AS cc
WHERE cc.IsDeleted = 0 AND cc.IsActive = 1 AND cc.CustomerContactEmail LIKE N'%_@_%'
  AND cc.CustomerId IN (SELECT CustomerId FROM #Live)
  AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) <> ISNULL(@Me, N'')
  AND NOT EXISTS (SELECT 1 FROM dbo.Users AS u
                  WHERE LOWER(LTRIM(RTRIM(u.Email))) = LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))))
ORDER BY LOWER(LTRIM(RTRIM(cc.CustomerContactEmail)));

SELECT TOP (1) @Staff = LOWER(LTRIM(RTRIM(u.Email)))
FROM dbo.Users AS u
WHERE u.Email LIKE N'%_@_%' AND u.CustomerId IS NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.CustomerContacts AS cc
                  WHERE LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = LOWER(LTRIM(RTRIM(u.Email))))
ORDER BY u.ID;

/* Priority: the invoice and quote numbers of the set's customers, read directly. If the linked
   server does not answer, the *FromPriority R2 cases SKIP. */
DECLARE @PriorityUp BIT = 0, @Custs NVARCHAR(MAX), @Sql NVARCHAR(MAX);
DROP TABLE IF EXISTS #MineInvoices;
CREATE TABLE #MineInvoices (DocNo NVARCHAR(50));
DROP TABLE IF EXISTS #MineQuotes;
CREATE TABLE #MineQuotes (DocNo NVARCHAR(50));

SELECT @Custs = STRING_AGG(CAST(TRY_CONVERT(INT, c.CustomerIdFromSource) AS NVARCHAR(20)), N',')
FROM dbo.Customers AS c
INNER JOIN #Mine AS m ON m.CustomerId = c.CustomerId
WHERE TRY_CONVERT(INT, c.CustomerIdFromSource) IS NOT NULL;

BEGIN TRY
    SET @Sql = CONCAT(N'SELECT IVNUM FROM OPENQUERY([31.168.173.93], ''SELECT IVNUM FROM amaba.dbo.INVOICES WHERE CUST IN (',
                      ISNULL(@Custs, N'-1'), N')'')');
    INSERT #MineInvoices EXEC (@Sql);
    SET @Sql = CONCAT(N'SELECT CPROFNUM FROM OPENQUERY([31.168.173.93], ''SELECT CPROFNUM FROM amaba.dbo.CPROF WHERE CUST IN (',
                      ISNULL(@Custs, N'-1'), N')'')');
    INSERT #MineQuotes EXEC (@Sql);
    SET @PriorityUp = 1;
END TRY
BEGIN CATCH
    SET @PriorityUp = 0;
END CATCH;

INSERT @Out SELECT N'0 fixtures', N'@Me with live items under two customers of its set, @OwnItem, @ForeignItem',
       N'found', IIF(@Me IS NULL OR @OwnItem IS NULL OR @ForeignItem IS NULL, N'missing', N'found'),
       IIF(@Me IS NULL OR @OwnItem IS NULL OR @ForeignItem IS NULL, N'FAIL - nothing below can run', N'PASS');
INSERT @Out SELECT N'0 fixtures', N'Priority linked server answers', N'yes',
       IIF(@PriorityUp = 1, N'yes', N'no'), IIF(@PriorityUp = 1, N'PASS', N'SKIP - *FromPriority R2 cases skip');

DECLARE @N INT, @M INT, @Bad INT, @Err INT, @Msg NVARCHAR(4000);

/* control for the inactive case: while still active, @Inactive does see devices, so the zero R1
   expects after deactivating it can only come from the IsActive filter */
IF @Inactive IS NULL
    INSERT @Out SELECT N'0 fixtures', N'@Inactive sees devices while active (control for R1)', N'> 0 rows', N'-',
           N'SKIP - no such address';
ELSE
BEGIN
    BEGIN TRY
        BEGIN TRAN;
        TRUNCATE TABLE #Dev;
        INSERT #Dev EXEC dbo.GetCustomerDeviceList @LoggedInUserEmail = @Inactive;
        SELECT @N = COUNT(*) FROM #Dev;
        ROLLBACK;
        INSERT @Out SELECT N'0 fixtures', N'@Inactive sees devices while active (control for R1)', N'> 0 rows',
               CONCAT(@N, N' rows'), IIF(@N > 0, N'PASS', N'FAIL');
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        INSERT @Out SELECT N'0 fixtures', N'@Inactive sees devices while active (control for R1)', N'no error',
               LEFT(ERROR_MESSAGE(), 80), N'FAIL';
    END CATCH;
END;


/* =============================================================================================
   R1 and R2 - every procedure, every caller

   One row per procedure. OwnershipCheck is run for @Me only: it sets @Bad to the number of
   returned rows that cannot be traced to a customer of the set, by whatever the result carries.
   Setup, when present, runs first inside the same transaction, for every caller.
   ============================================================================================= */
DECLARE @Procs TABLE (Seq INT IDENTITY, ProcName SYSNAME, Tmp SYSNAME, Extra NVARCHAR(200),
                      NeedsPriority BIT, OwnershipCheck NVARCHAR(MAX), Setup NVARCHAR(MAX));
INSERT @Procs (ProcName, Tmp, Extra, NeedsPriority, OwnershipCheck) VALUES
/* no id in the result: a row is the caller's if a set customer of that name holds that serial */
(N'GetCustomerDashboardData', N'#Dash', N', @RowsOfPage = 100000', 0,
 N'SELECT @Bad = COUNT(*) FROM #Dash AS r WHERE NOT EXISTS (SELECT 1 FROM #MineItems AS m
     WHERE EXISTS (SELECT m.CustomerName, m.SerialNumber INTERSECT
                   SELECT r.CustomerName COLLATE DATABASE_DEFAULT, r.SerialNumber COLLATE DATABASE_DEFAULT));'),
/* a calibrator and a date: there must be such an assignment on an order of the set */
(N'GetCustomerUpcommingCalibrationInfo', N'#Up', N'', 0,
 N'SELECT @Bad = COUNT(*) FROM #Up AS r WHERE NOT EXISTS (SELECT 1 FROM dbo.CalibratorsToWorkPlan AS ctwp
     INNER JOIN dbo.OrderWorkPlans AS wp ON wp.OrderWorkPlanId = ctwp.OrderWorkPlanId
     INNER JOIN #Mine AS m ON m.CustomerId = wp.CustomerId
     INNER JOIN dbo.Users AS u ON u.ID = ctwp.CalibratorId
     WHERE ctwp.IsDeleted = 0 AND ctwp.AssigmentDate = r.AssigmentDate
       AND EXISTS (SELECT u.Email INTERSECT SELECT r.Email COLLATE DATABASE_DEFAULT));'),
/* one employee: the support contact of a customer in the set */
(N'GetCustomerSupportData', N'#Sup', N'', 0,
 N'SELECT @Bad = COUNT(*) FROM #Sup AS r WHERE NOT EXISTS (SELECT 1 FROM dbo.Customers AS c
     INNER JOIN #Mine AS m ON m.CustomerId = c.CustomerId
     INNER JOIN dbo.Users AS u ON u.ID = c.CustomerSupportContactId
     WHERE EXISTS (SELECT u.Email, u.FirstName, u.LastName INTERSECT
                   SELECT r.Email COLLATE DATABASE_DEFAULT, r.FirstName COLLATE DATABASE_DEFAULT,
                          r.LastName COLLATE DATABASE_DEFAULT));'),
(N'GetCustomerProfile', N'#Prof', N'', 0,
 N'SELECT @Bad = COUNT(*) FROM #Prof AS r WHERE NOT EXISTS (SELECT 1 FROM #Mine AS m WHERE m.CustomerId = r.CustomerId);'),
(N'GetCustomerShipments', N'#Ship', N'', 0,
 N'SELECT @Bad = COUNT(*) FROM #Ship AS r WHERE NOT EXISTS (SELECT 1 FROM #MineItems AS m WHERE m.ItemId = r.id);'),
(N'GetCustomerSites', N'#Site', N'', 0,
 N'SELECT @Bad = COUNT(*) FROM #Site AS r WHERE NOT EXISTS (SELECT 1 FROM #Mine AS m WHERE m.CustomerId = r.CustomerId);'),
/* through the contact id, not the CustomerId column the procedure chose to return */
(N'GetCustomerContacts', N'#Cont', N'', 0,
 N'SELECT @Bad = COUNT(*) FROM #Cont AS r WHERE NOT EXISTS (SELECT 1 FROM dbo.CustomerContacts AS cc
     INNER JOIN #Mine AS m ON m.CustomerId = cc.CustomerId WHERE cc.CustomerContactId = r.CustomerContactId);'),
/* quoteNumber is the order number; no order number is shared by two customers */
(N'GetCustomerRequests', N'#Req', N'', 0,
 N'SELECT @Bad = COUNT(*) FROM #Req AS r WHERE NOT EXISTS (SELECT 1 FROM #MineOrders AS o WHERE o.OrderNumber = r.quoteNumber COLLATE DATABASE_DEFAULT);'),
(N'GetCustomerInvoicesFromPriority', N'#Inv', N'', 1,
 N'SELECT @Bad = COUNT(*) FROM #Inv AS r WHERE NOT EXISTS (SELECT 1 FROM #MineInvoices AS d WHERE d.DocNo = r.invoiceNumber);'),
(N'GetCustomerQuotesFromPriority', N'#Quo', N'', 1,
 N'SELECT @Bad = COUNT(*) FROM #Quo AS r WHERE NOT EXISTS (SELECT 1 FROM #MineQuotes AS d WHERE d.DocNo = r.quoteNumber);'),
(N'GetCustomerDeviceList', N'#Dev', N'', 0,
 N'SELECT @Bad = COUNT(*) FROM #Dev AS r WHERE NOT EXISTS (SELECT 1 FROM #MineItems AS m WHERE m.ItemId = r.id);'),
(N'GetCustomerCalibrationReports', N'#Rep', N'', 0,
 N'SELECT @Bad = COUNT(*) FROM #Rep AS r WHERE NOT EXISTS (SELECT 1 FROM #MineItems AS m WHERE m.ItemId = r.id);'),
/* asked for @Me's own item; the other callers ask for the same item and must not get it */
(N'GetCustomerDeviceDetail', N'#Det', N', @OrderDetailsItemId = @OwnItem', 0,
 N'SELECT @Bad = COUNT(*) FROM #Det AS r WHERE NOT EXISTS (SELECT 1 FROM #MineItems AS m WHERE m.ItemId = r.id);');

/* the card shows the nearest visit, so a foreign visit booked earlier than the caller's own is the
   one that would surface if the scope leaked */
UPDATE @Procs SET Setup =
 N'IF @OwnOrder IS NOT NULL AND @ForeignOrder IS NOT NULL AND @Calibrator IS NOT NULL
       INSERT dbo.CalibratorsToWorkPlan (OrderWorkPlanId, CalibratorId, AssigmentDate)
       VALUES (@OwnOrder,     @Calibrator, DATEADD(DAY, 2, CAST(GETDATE() AS DATE))),
              (@ForeignOrder, @Calibrator, DATEADD(DAY, 1, CAST(GETDATE() AS DATE))); '
WHERE ProcName = N'GetCustomerUpcommingCalibrationInfo';

DECLARE @Callers TABLE (K INT IDENTITY, Kind NVARCHAR(20), Email NVARCHAR(100), Deactivate BIT);
INSERT @Callers (Kind, Email, Deactivate) VALUES
    (N'unknown address', @Unknown, 0),
    (N'staff-only user', @Staff, 0),
    (N'inactive contact', @Inactive, 1),
    (N'@Me', @Me, 0);

DECLARE @p INT = 1, @c INT, @Proc SYSNAME, @Tmp SYSNAME, @Extra NVARCHAR(200), @NeedsPriority BIT,
        @Check NVARCHAR(MAX), @Setup NVARCHAR(MAX), @Kind NVARCHAR(20), @Who NVARCHAR(100), @Deactivate BIT,
        @Test NVARCHAR(100);

WHILE @p <= (SELECT COUNT(*) FROM @Procs)
BEGIN
    SELECT @Proc = ProcName, @Tmp = Tmp, @Extra = Extra, @NeedsPriority = NeedsPriority,
           @Check = OwnershipCheck, @Setup = Setup
    FROM @Procs WHERE Seq = @p;

    SET @c = 1;
    WHILE @c <= (SELECT COUNT(*) FROM @Callers)
    BEGIN
        SELECT @Kind = Kind, @Who = Email, @Deactivate = Deactivate FROM @Callers WHERE K = @c;
        SET @Test = CONCAT(@Proc, N' - ', @Kind);

        IF @Who IS NULL
            INSERT @Out SELECT IIF(@Kind = N'@Me', N'R2 own set', N'R1 refuse'), @Test, N'-', N'-',
                   CONCAT(N'SKIP - no ', @Kind, N' in the data');
        ELSE IF @Kind = N'@Me' AND @NeedsPriority = 1 AND @PriorityUp = 0
            INSERT @Out SELECT N'R2 own set', @Test, N'0 foreign', N'-', N'SKIP - Priority not reachable';
        ELSE
        BEGIN
            SELECT @N = NULL, @Bad = NULL, @Err = NULL, @Msg = NULL;
            SET @Sql = CONCAT(@Setup,
                              N'TRUNCATE TABLE ', @Tmp, N'; ',
                              N'INSERT ', @Tmp, N' EXEC dbo.', @Proc, N' @LoggedInUserEmail = @Who', @Extra, N'; ',
                              N'SELECT @N = COUNT(*) FROM ', @Tmp, N'; ',
                              IIF(@Kind = N'@Me', @Check, N''));
            BEGIN TRY
                BEGIN TRAN;
                IF @Deactivate = 1
                    UPDATE dbo.CustomerContacts SET IsActive = 0
                    WHERE IsDeleted = 0 AND LOWER(LTRIM(RTRIM(CustomerContactEmail))) = @Who;
                EXEC sp_executesql @Sql,
                     N'@Who NVARCHAR(100), @OwnItem INT, @OwnOrder INT, @ForeignOrder INT, @Calibrator INT,
                       @N INT OUTPUT, @Bad INT OUTPUT',
                     @Who, @OwnItem, @OwnOrder, @ForeignOrder, @Calibrator, @N OUTPUT, @Bad OUTPUT;
                ROLLBACK;
            END TRY
            BEGIN CATCH
                SELECT @Err = ERROR_NUMBER(), @Msg = ERROR_MESSAGE();
                IF @@TRANCOUNT > 0 ROLLBACK;
            END CATCH;

            IF @Kind <> N'@Me'
                INSERT @Out SELECT N'R1 refuse', @Test, N'0 rows',
                       IIF(@Err IS NULL, CONCAT(@N, N' rows'), LEFT(CONCAT(@Err, N' ', @Msg), 80)),
                       IIF(@Err IS NULL AND @N = 0, N'PASS', N'FAIL');
            ELSE
                INSERT @Out SELECT N'R2 own set', @Test, N'0 foreign',
                       IIF(@Err IS NULL, CONCAT(@Bad, N' foreign of ', @N, N' rows'), LEFT(CONCAT(@Err, N' ', @Msg), 80)),
                       CASE WHEN @Err = 8164 THEN N'SKIP - proc nests INSERT EXEC (8164), rows not capturable'
                            WHEN @Err IS NOT NULL THEN N'FAIL'
                            WHEN @Bad > 0         THEN N'FAIL'
                            WHEN @N = 0           THEN N'SKIP - @Me gets no rows here'
                            ELSE N'PASS' END;
        END;
        SET @c += 1;
    END;
    SET @p += 1;
END;


/* =============================================================================================
   R3 - GetCustomerDeviceDetail answers for the caller's own item only
   ============================================================================================= */
BEGIN TRY
    BEGIN TRAN;
    TRUNCATE TABLE #Det;
    INSERT #Det EXEC dbo.GetCustomerDeviceDetail @LoggedInUserEmail = @Me, @OrderDetailsItemId = @ForeignItem;
    SELECT @N = COUNT(*) FROM #Det;
    TRUNCATE TABLE #Det;
    INSERT #Det EXEC dbo.GetCustomerDeviceDetail @LoggedInUserEmail = @Me, @OrderDetailsItemId = @OwnItem;
    SELECT @M = COUNT(*) FROM #Det WHERE id = @OwnItem;
    ROLLBACK;
    INSERT @Out SELECT N'R3 detail', N'another customer''s live item -> 0 rows', N'0 rows',
           CONCAT(@N, N' rows'), IIF(@N = 0, N'PASS', N'FAIL');
    INSERT @Out SELECT N'R3 detail', N'own live item -> exactly that item', N'1 row',
           CONCAT(@M, N' rows'), IIF(@M = 1, N'PASS', N'FAIL');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out SELECT N'R3 detail', N'own / foreign item', N'no error', LEFT(ERROR_MESSAGE(), 80), N'FAIL';
END CATCH;


/* =============================================================================================
   R4 - GetCustomerCalibrationReports: getCustomerReportUrl presigns the reportPath of the row
   whose id it was given, so every path must be the item's own, under its own order
   ============================================================================================= */
BEGIN TRY
    BEGIN TRAN;
    TRUNCATE TABLE #Rep;
    INSERT #Rep EXEC dbo.GetCustomerCalibrationReports @LoggedInUserEmail = @Me;
    SELECT @N = COUNT(*),
           @Bad = SUM(CASE WHEN m.ItemId IS NULL
                             OR r.reportPath COLLATE DATABASE_DEFAULT
                                <> CONCAT(N'orders/', m.OrderNumber, N'/reports/', m.ItemId, N'/report.pdf')
                             OR r.mbaReportNumber COLLATE DATABASE_DEFAULT <> m.MbaReportNumber
                           THEN 1 ELSE 0 END)
    FROM #Rep AS r
    LEFT JOIN #MineItems AS m ON m.ItemId = r.id;
    SELECT @M = COUNT(*) FROM #Rep WHERE id = @ForeignReportItem;
    ROLLBACK;
    INSERT @Out SELECT N'R4 reports', N'every report is a set item''s, path under its own order', N'0 wrong',
           CONCAT(ISNULL(@Bad, 0), N' wrong of ', @N, N' rows'),
           CASE WHEN @Bad > 0 THEN N'FAIL' WHEN @N = 0 THEN N'SKIP - @Me has no reports' ELSE N'PASS' END;
    INSERT @Out SELECT N'R4 reports', N'another customer''s report is not listed', N'0 rows',
           IIF(@ForeignReportItem IS NULL, N'-', CONCAT(@M, N' rows')),
           CASE WHEN @ForeignReportItem IS NULL THEN N'SKIP - no foreign report in the data'
                WHEN @M = 0 THEN N'PASS' ELSE N'FAIL' END;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out SELECT N'R4 reports', N'report list', N'no error', LEFT(ERROR_MESSAGE(), 80), N'FAIL';
END CATCH;


/* =============================================================================================
   R5 - GetCustomerSites: createPortalRequest accepts a site only if it is in this list, so each
   site id is mapped through dbo.CustomerSites itself, not through the CustomerId column returned
   ============================================================================================= */
BEGIN TRY
    BEGIN TRAN;
    TRUNCATE TABLE #Site;
    INSERT #Site EXEC dbo.GetCustomerSites @LoggedInUserEmail = @Me;
    SELECT @N = COUNT(*) FROM #Site;
    SELECT @Bad = COUNT(*) FROM #Site AS r
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CustomerSites AS cs
                      INNER JOIN #Mine AS m ON m.CustomerId = cs.CustomerId
                      WHERE cs.CustomerSiteId = r.CustomerSiteId);
    SELECT @M = COUNT(*) FROM #Site WHERE CustomerSiteId = @ForeignSite;
    ROLLBACK;
    INSERT @Out SELECT N'R5 sites', N'every site id belongs to a customer of the set', N'0 foreign',
           CONCAT(@Bad, N' foreign of ', @N, N' rows'),
           CASE WHEN @Bad > 0 THEN N'FAIL' WHEN @N = 0 THEN N'SKIP - @Me has no sites' ELSE N'PASS' END;
    INSERT @Out SELECT N'R5 sites', N'another customer''s site is not listed', N'0 rows',
           IIF(@ForeignSite IS NULL, N'-', CONCAT(@M, N' rows')),
           CASE WHEN @ForeignSite IS NULL THEN N'SKIP - no foreign site in the data'
                WHEN @M = 0 THEN N'PASS' ELSE N'FAIL' END;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out SELECT N'R5 sites', N'site list', N'no error', LEFT(ERROR_MESSAGE(), 80), N'FAIL';
END CATCH;


/* =============================================================================================
   R6 - GetCustomerDashboardData builds its query as text, and @GlobalSearch is the dashboard's
   search box. A search containing an apostrophe (O'Brien) must be searched for - no device
   matches, so 0 rows - and not end up as part of the statement.
   ============================================================================================= */
SELECT @N = NULL, @Err = NULL, @Msg = NULL;
BEGIN TRY
    BEGIN TRAN;
    TRUNCATE TABLE #Dash;
    INSERT #Dash EXEC dbo.GetCustomerDashboardData @LoggedInUserEmail = @Me, @RowsOfPage = 100000,
        @GlobalSearch = N'mba1014 O''Brien';
    SELECT @N = COUNT(*) FROM #Dash;
    ROLLBACK;
END TRY
BEGIN CATCH
    SELECT @Err = ERROR_NUMBER(), @Msg = ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH;
INSERT @Out SELECT N'R6 search', N'search text with an apostrophe is searched for, not executed', N'0 rows, no error',
       IIF(@Err IS NULL, CONCAT(@N, N' rows'), LEFT(CONCAT(N'error ', @Err, N': ', @Msg), 80)),
       IIF(@Err IS NULL AND @N = 0, N'PASS', N'FAIL');


SELECT Seq, Section, Test, Expected, Actual, Result FROM @Out ORDER BY Seq;
