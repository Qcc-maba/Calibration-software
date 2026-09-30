/*
    dbo.CreateCustomerPortalRequest                                                     MBA-903
    ---------------------------------------------------------------------------------------------
    Records one request a customer submits from the portal. Backs seven popups in Figma node
    6768-597 that previously had no procedure to write to.

    Which parameters each type uses - everything else stays NULL:

      ReportUpdate             @MbaReportNumber or @ItemIds, @Reason
                               (single popup and the multi-report popup are the same call; the
                                multi one just passes several ids in @ItemIds)
      Shipment                 @ShippingMethod, @ShippingDocument, @RequestedDate (תאריך איסוף),
                               @CustomerSiteId, @DeviceLocation, @Notes
      CalibrationExtension     @RequestedDate (the new validity date), @Reason
      CalibrationCancellation  @RequestedDate (the calibration date being cancelled), @Reason
      Quote                    @CalibrationLocation, @CustomerSiteId, @DeviceCount, @ItemIds,
                               @CalibrateToDeviceSpec, @Notes, @AttachmentPath (from-file variant)
      QuoteFeedback            @QuoteNumber, @Notes
      DeviceRemoval            @ItemIds or @CustomerDeviceId, @Reason

    Identity follows the other customer-portal procedures: @LoggedInUserEmail resolves to a
    CustomerId through dbo.CustomerContacts, and the request is recorded against that customer. An
    address that matches no contact is rejected rather than written with a NULL customer - an
    unattributable request is worse than a failed one, because nobody would ever answer it.

    Ownership is enforced, not assumed. Every id in @ItemIds must belong to the calling customer's
    own orders; anything else is dropped and reported in RejectedItemCount. A caller cannot file a
    request against another customer's device by guessing an id.

    @ItemIds is a comma-separated list of OrderDetailsItemId. Blank and non-numeric entries are
    ignored - note that STRING_SPLIT('', ',') returns one row holding an empty string and
    CAST('' AS INT) is 0, which is exactly how MBA-902 silently wiped channel assignments. An empty
    list here is legitimate: several request types are about an order or a report, not about a
    device.

    Returns the new CustomerPortalRequestId, the number of items attached, and how many were
    rejected as not belonging to the caller.

    2026-09-30 - MBA-903: the caller is a SET of customers, and a submission can be several requests.
    ---------------------------------------------------------------------------------------------
    The identity used to be SELECT TOP (1) ... ORDER BY CustomerContactId - the rule MBA-943 removed
    from every read screen on 2026-08-31 and missed here. The screens show a caller the devices of
    every customer in dbo.GetPortalCustomerIds; this procedure then judged ownership against one
    arbitrary customer of the set. Measured on STAGE: 236 addresses land on a customer holding no
    devices while their devices sit under another one, so every request they filed was rejected
    (davide@iscar.co.il: customer 1082, none of his 31 devices). Ownership is now "belongs to a
    customer in the set" - exactly what the screens show.

    A request row still has ONE CustomerId, because MBA answers per customer: orders, quotes and
    invoices in Priority are per customer, dbo.GetCustomerPortalRequestList shows customerName per
    request, and dbo.ResolveCustomerPortalRequest checks ownership per request. So when the selected
    items belong to several customers (68 addresses on STAGE hold devices under more than one), the
    submission is SPLIT: one request per owning customer, each carrying only its own items. Stamping
    all of them on the primary customer would file one Iscar division's devices under another, and
    the quote or shipment would reach the wrong customer in Priority. A submission with no items
    (report- or order-level) is filed under the primary customer.

    One result row per request created, ordered by id. rejectedItemCount belongs to the SUBMISSION,
    not to a request, so every row repeats the same total - read it once, do not sum it. A caller
    that reads only the first row still gets a valid request id.

    When the split produces several requests, each one's DeviceCount is its own item count; a single
    request keeps @DeviceCount as passed.

    Two further refusals, both before anything is written:
      52004  ids were sent and NONE of them belongs to the caller. This used to commit a request with
             zero items - a "please extend calibration for nothing" that sat in MBA's queue as New
             while the portal showed the customer an error, and every retry added another. An EMPTY
             @ItemIds is still legitimate, as above; only "sent some, owned none" is refused.
      52005  @CustomerSiteId is not a live site of a customer in the caller's set. The portal checks
             this too; the procedure is the boundary every caller goes through.
*/
CREATE OR ALTER PROCEDURE dbo.CreateCustomerPortalRequest
    @LoggedInUserEmail     NVARCHAR(100),
    @RequestType           NVARCHAR(40),
    @ItemIds               NVARCHAR(MAX)  = NULL,   /* OrderDetailsItemId list */
    @OrderWorkPlanId       INT            = NULL,
    @CustomerDeviceId      INT            = NULL,
    @MbaReportNumber       NVARCHAR(100)  = NULL,
    @QuoteNumber           NVARCHAR(100)  = NULL,
    @RequestedDate         DATE           = NULL,
    @Reason                NVARCHAR(1000) = NULL,
    @Notes                 NVARCHAR(2000) = NULL,
    @ShippingMethod        NVARCHAR(100)  = NULL,
    @ShippingDocument      NVARCHAR(100)  = NULL,
    @CustomerSiteId        INT            = NULL,
    @DeviceLocation        NVARCHAR(200)  = NULL,
    @DeviceCount           INT            = NULL,
    @CalibrationLocation   NVARCHAR(20)   = NULL,
    @CalibrateToDeviceSpec BIT            = NULL,
    @AttachmentPath        NVARCHAR(400)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RequestType NOT IN (N'ReportUpdate', N'Shipment', N'CalibrationExtension',
                            N'CalibrationCancellation', N'Quote', N'QuoteFeedback', N'DeviceRemoval')
        THROW 52001, 'Unknown RequestType.', 1;

    IF @CalibrationLocation IS NOT NULL AND @CalibrationLocation NOT IN (N'lab', N'customer')
        THROW 52002, 'CalibrationLocation must be lab or customer.', 1;

    DECLARE @Email NVARCHAR(100) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)));

    /* MBA-943: every customer this address may act for - the set every read screen uses. */
    SELECT m.CustomerId, m.IsPrimary
    INTO #Mine
    FROM dbo.GetPortalCustomerIds(@Email) AS m;

    IF NOT EXISTS (SELECT 1 FROM #Mine)
        THROW 52003, 'The submitting address does not belong to any customer contact.', 1;

    IF @CustomerSiteId IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM dbo.CustomerSites AS cs
                       INNER JOIN #Mine AS m ON m.CustomerId = cs.CustomerId
                       WHERE cs.CustomerSiteId = @CustomerSiteId
                         AND ISNULL(cs.IsDeleted, 0) = 0)
        THROW 52005, 'The site does not belong to the caller.', 1;

    /* MBA-902 lesson: drop blanks and non-numerics rather than letting them become 0. Longer than
       nine digits cannot be an INT id and would fail the CAST, so it is dropped the same way. */
    CREATE TABLE #Ids (OrderDetailsItemId INT PRIMARY KEY);

    INSERT INTO #Ids (OrderDetailsItemId)
    SELECT DISTINCT CAST(LTRIM(RTRIM(value)) AS INT)
    FROM STRING_SPLIT(ISNULL(@ItemIds, N''), ',')
    WHERE LTRIM(RTRIM(value)) <> N''
      AND LTRIM(RTRIM(value)) NOT LIKE '%[^0-9]%'
      AND LEN(LTRIM(RTRIM(value))) <= 9;

    /* Only items that really belong to a customer of this caller survive, each with its owner. */
    SELECT i.OrderDetailsItemId, it.MbaReportNumber, it.SerialNumber, wp.CustomerId
    INTO #Owned
    FROM #Ids AS i
    INNER JOIN dbo.OrderDetailsItems AS it ON it.OrderDetailsItemId = i.OrderDetailsItemId
    INNER JOIN dbo.OrderDetails      AS od ON od.OrderDetailId      = it.OrderDetailId
    INNER JOIN dbo.OrderWorkPlans    AS wp ON wp.OrderWorkPlanId    = od.OrderWorkPlanId
    INNER JOIN #Mine                 AS m  ON m.CustomerId          = wp.CustomerId
    WHERE ISNULL(it.IsDeleted, 0) = 0
      AND ISNULL(od.IsDeleted, 0) = 0;

    DECLARE @Rejected INT = (SELECT COUNT(*) FROM #Ids) - (SELECT COUNT(*) FROM #Owned);

    /* Sent some, owned none: refuse rather than file a request about nothing - see the header. */
    IF EXISTS (SELECT 1 FROM #Ids) AND NOT EXISTS (SELECT 1 FROM #Owned)
        THROW 52004, 'None of the selected items belong to the caller.', 1;

    /* One request per owning customer; no items at all -> the primary customer. */
    DECLARE @Targets TABLE (Seq INT IDENTITY(1,1) PRIMARY KEY, CustomerId INT NOT NULL,
                            CustomerContactId INT NULL, RequestId BIGINT NULL);

    INSERT INTO @Targets (CustomerId)
    SELECT o.CustomerId FROM #Owned AS o GROUP BY o.CustomerId ORDER BY o.CustomerId;

    IF NOT EXISTS (SELECT 1 FROM @Targets)
        INSERT INTO @Targets (CustomerId)
        SELECT TOP (1) m.CustomerId FROM #Mine AS m ORDER BY m.IsPrimary DESC, m.CustomerId;

    /* This address's own contact row within each customer - active first, lowest id to break a tie. */
    UPDATE t
    SET CustomerContactId = (SELECT TOP (1) cc.CustomerContactId
                             FROM dbo.CustomerContacts AS cc
                             WHERE cc.CustomerId = t.CustomerId
                               AND cc.IsDeleted = 0
                               AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @Email
                             ORDER BY ISNULL(cc.IsActive, 1) DESC, cc.CustomerContactId ASC)
    FROM @Targets AS t;

    DECLARE @IsSplit BIT = IIF((SELECT COUNT(*) FROM @Targets) > 1, 1, 0);
    DECLARE @Seq INT = 1, @LastSeq INT = (SELECT MAX(Seq) FROM @Targets);
    DECLARE @TargetCustomerId INT, @TargetContactId INT, @RequestId BIGINT;

    BEGIN TRAN;

        WHILE @Seq <= @LastSeq
        BEGIN
            SELECT @TargetCustomerId = t.CustomerId, @TargetContactId = t.CustomerContactId
            FROM @Targets AS t WHERE t.Seq = @Seq;

            INSERT INTO dbo.CustomerPortalRequest
                (RequestType, Status, CustomerId, CustomerContactId, SubmittedByEmail,
                 OrderWorkPlanId, OrderDetailsItemId, CustomerDeviceId, MbaReportNumber, QuoteNumber,
                 RequestedDate, Reason, Notes, ShippingMethod, ShippingDocument, CustomerSiteId,
                 DeviceLocation, DeviceCount, CalibrationLocation, CalibrateToDeviceSpec, AttachmentPath)
            VALUES
                (@RequestType, N'New', @TargetCustomerId, @TargetContactId, @Email,
                 @OrderWorkPlanId,
                 (SELECT MIN(o.OrderDetailsItemId) FROM #Owned AS o
                  WHERE o.CustomerId = @TargetCustomerId),          /* the single-device shortcut */
                 @CustomerDeviceId, @MbaReportNumber, @QuoteNumber,
                 @RequestedDate, @Reason, @Notes, @ShippingMethod, @ShippingDocument, @CustomerSiteId,
                 @DeviceLocation,
                 IIF(@IsSplit = 1,
                     (SELECT COUNT(*) FROM #Owned AS o WHERE o.CustomerId = @TargetCustomerId),
                     @DeviceCount),
                 @CalibrationLocation, @CalibrateToDeviceSpec, @AttachmentPath);

            SET @RequestId = CAST(SCOPE_IDENTITY() AS BIGINT);

            UPDATE @Targets SET RequestId = @RequestId WHERE Seq = @Seq;

            INSERT INTO dbo.CustomerPortalRequestItem
                (CustomerPortalRequestId, OrderDetailsItemId, MbaReportNumber, SerialNumber)
            SELECT @RequestId, o.OrderDetailsItemId, o.MbaReportNumber, o.SerialNumber
            FROM #Owned AS o
            WHERE o.CustomerId = @TargetCustomerId;

            SET @Seq += 1;
        END

    COMMIT;

    SELECT t.RequestId                                                   AS customerPortalRequestId,
           t.CustomerId                                                  AS customerId,
           c.CustomerName                                                AS customerName,
           (SELECT COUNT(*) FROM #Owned AS o WHERE o.CustomerId = t.CustomerId) AS itemCount,
           @Rejected                                                     AS rejectedItemCount
    FROM @Targets AS t
    LEFT JOIN dbo.Customers AS c ON c.CustomerId = t.CustomerId
    ORDER BY t.RequestId;
END
