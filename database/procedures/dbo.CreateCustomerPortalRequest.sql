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

    DECLARE @CustomerId INT, @CustomerContactId INT;

    SELECT TOP (1) @CustomerId = cc.CustomerId, @CustomerContactId = cc.CustomerContactId
    FROM dbo.CustomerContacts AS cc
    WHERE cc.IsDeleted = 0
      AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)))
    ORDER BY cc.CustomerContactId ASC;

    IF @CustomerId IS NULL
        THROW 52003, 'The submitting address does not belong to any customer contact.', 1;

    /* MBA-902 lesson: drop blanks and non-numerics rather than letting them become 0. */
    CREATE TABLE #Ids (OrderDetailsItemId INT PRIMARY KEY);

    INSERT INTO #Ids (OrderDetailsItemId)
    SELECT DISTINCT CAST(LTRIM(RTRIM(value)) AS INT)
    FROM STRING_SPLIT(ISNULL(@ItemIds, N''), ',')
    WHERE LTRIM(RTRIM(value)) <> N''
      AND LTRIM(RTRIM(value)) NOT LIKE '%[^0-9]%';

    /* Only items that really belong to this customer survive. */
    SELECT i.OrderDetailsItemId, it.MbaReportNumber, it.SerialNumber
    INTO #Owned
    FROM #Ids AS i
    INNER JOIN dbo.OrderDetailsItems AS it ON it.OrderDetailsItemId = i.OrderDetailsItemId
    INNER JOIN dbo.OrderDetails      AS od ON od.OrderDetailId      = it.OrderDetailId
    INNER JOIN dbo.OrderWorkPlans    AS wp ON wp.OrderWorkPlanId    = od.OrderWorkPlanId
    WHERE wp.CustomerId = @CustomerId
      AND ISNULL(it.IsDeleted, 0) = 0
      AND ISNULL(od.IsDeleted, 0) = 0;

    DECLARE @Rejected INT = (SELECT COUNT(*) FROM #Ids) - (SELECT COUNT(*) FROM #Owned);

    BEGIN TRAN;

        INSERT INTO dbo.CustomerPortalRequest
            (RequestType, Status, CustomerId, CustomerContactId, SubmittedByEmail,
             OrderWorkPlanId, OrderDetailsItemId, CustomerDeviceId, MbaReportNumber, QuoteNumber,
             RequestedDate, Reason, Notes, ShippingMethod, ShippingDocument, CustomerSiteId,
             DeviceLocation, DeviceCount, CalibrationLocation, CalibrateToDeviceSpec, AttachmentPath)
        VALUES
            (@RequestType, N'New', @CustomerId, @CustomerContactId,
             LOWER(LTRIM(RTRIM(@LoggedInUserEmail))),
             @OrderWorkPlanId,
             (SELECT MIN(OrderDetailsItemId) FROM #Owned),   /* the single-device shortcut */
             @CustomerDeviceId, @MbaReportNumber, @QuoteNumber,
             @RequestedDate, @Reason, @Notes, @ShippingMethod, @ShippingDocument, @CustomerSiteId,
             @DeviceLocation, @DeviceCount, @CalibrationLocation, @CalibrateToDeviceSpec, @AttachmentPath);

        DECLARE @RequestId BIGINT = CAST(SCOPE_IDENTITY() AS BIGINT);

        INSERT INTO dbo.CustomerPortalRequestItem
            (CustomerPortalRequestId, OrderDetailsItemId, MbaReportNumber, SerialNumber)
        SELECT @RequestId, o.OrderDetailsItemId, o.MbaReportNumber, o.SerialNumber
        FROM #Owned AS o;

    COMMIT;

    SELECT @RequestId                              AS customerPortalRequestId,
           (SELECT COUNT(*) FROM #Owned)           AS itemCount,
           @Rejected                               AS rejectedItemCount;
END
