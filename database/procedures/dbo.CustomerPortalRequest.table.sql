/*
    dbo.CustomerPortalRequest / dbo.CustomerPortalRequestItem                           MBA-903
    ---------------------------------------------------------------------------------------------
    Everything a customer ASKS FOR from the portal.

    The portal design (Figma node 6768-597) has read screens and action popups. Every read screen
    already had a procedure behind it; almost none of the popups did, so a customer could look at
    their data but not ask for anything - the buttons had nowhere to write to.

    Seven of those popups are the same thing wearing different labels: a customer, about a device or
    an order, asks MBA for something, gives a reason, and waits for an answer. They are one table
    with a type, not seven tables:

        ReportUpdate             בקשה לעדכון דו״ח / דו״חות
        Shipment                 הזמנה לשינוע
        CalibrationExtension     הארכת תוקף כיול
        CalibrationCancellation  בקשה לביטול הכיול
        Quote                    בקשה להצעת מחיר (single, multi, or from a file)
        QuoteFeedback            התייחסות לקוח / בקשה לתיקון ההצעה
        DeviceRemoval            מחיקת מכשיר

    The columns a given type does not use stay NULL. That is deliberate: a JSON blob would make the
    fields invisible to reporting, and a table per type would multiply the same lifecycle six times.
    Which columns each type fills is documented on dbo.CreateCustomerPortalRequest.

    Requests that cover several devices at once - "בקשה לעדכון דו״חות", a multi-device quote - put
    one row per device in CustomerPortalRequestItem. A single-device request simply has one item.

    Append-mostly: the customer cannot edit a submitted request, only cancel it, and MBA resolves it.
    The history is the point - "the customer asked twice and nobody answered" has to stay visible.
*/
IF OBJECT_ID('dbo.CustomerPortalRequest', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CustomerPortalRequest
    (
        CustomerPortalRequestId BIGINT IDENTITY(1,1) NOT NULL,

        RequestType         NVARCHAR(40)  NOT NULL,
        Status              NVARCHAR(20)  NOT NULL
            CONSTRAINT DF_CustomerPortalRequest_Status DEFAULT (N'New'),

        /* who */
        CustomerId          INT           NOT NULL,
        CustomerContactId   INT           NULL,
        SubmittedByEmail    NVARCHAR(100) NOT NULL,

        /* what it is about - which of these is filled depends on RequestType */
        OrderWorkPlanId     INT           NULL,
        OrderDetailsItemId  INT           NULL,
        CustomerDeviceId    INT           NULL,
        MbaReportNumber     NVARCHAR(100) NULL,
        QuoteNumber         NVARCHAR(100) NULL,

        /* what the popup collects */
        RequestedDate       DATE          NULL,   /* pickup date, or the new validity date */
        Reason              NVARCHAR(1000) NULL,  /* סיבה לעדכון / לביטול / לשינוי תאריך */
        Notes               NVARCHAR(2000) NULL,  /* הערות לקוח */
        ShippingMethod      NVARCHAR(100) NULL,   /* שינוע ע״י */
        ShippingDocument    NVARCHAR(100) NULL,   /* תעודת משלוח */
        CustomerSiteId      INT           NULL,   /* כתובת אתר */
        DeviceLocation      NVARCHAR(200) NULL,   /* מיקום המכשיר */
        DeviceCount         INT           NULL,   /* מספר מכשירים */
        CalibrationLocation NVARCHAR(20)  NULL,   /* 'lab' | 'customer' */
        CalibrateToDeviceSpec BIT         NULL,   /* כיול לפי מפרט המכשיר */
        AttachmentPath      NVARCHAR(400) NULL,   /* the uploaded file, for the from-file variants */

        /* lifecycle */
        CreatedDate         DATETIME2(3)  NOT NULL
            CONSTRAINT DF_CustomerPortalRequest_CreatedDate DEFAULT (SYSUTCDATETIME()),
        ResolvedDate        DATETIME2(3)  NULL,
        ResolvedByUserId    INT           NULL,
        ResolutionNotes     NVARCHAR(1000) NULL,
        IsDeleted           BIT           NOT NULL
            CONSTRAINT DF_CustomerPortalRequest_IsDeleted DEFAULT (0),

        CONSTRAINT PK_CustomerPortalRequest PRIMARY KEY CLUSTERED (CustomerPortalRequestId),
        CONSTRAINT CK_CustomerPortalRequest_Type CHECK (RequestType IN
            (N'ReportUpdate', N'Shipment', N'CalibrationExtension', N'CalibrationCancellation',
             N'Quote', N'QuoteFeedback', N'DeviceRemoval')),
        CONSTRAINT CK_CustomerPortalRequest_Status CHECK (Status IN
            (N'New', N'InProgress', N'Approved', N'Rejected', N'Cancelled', N'Done'))
    );

    /* "what has this customer asked for lately" - the portal list, and the MBA queue */
    CREATE NONCLUSTERED INDEX IX_CustomerPortalRequest_Customer_Created
        ON dbo.CustomerPortalRequest (CustomerId, CreatedDate DESC)
        INCLUDE (RequestType, Status, OrderWorkPlanId, MbaReportNumber, QuoteNumber);

    /* the open queue, newest first, across all customers */
    CREATE NONCLUSTERED INDEX IX_CustomerPortalRequest_Status_Created
        ON dbo.CustomerPortalRequest (Status, CreatedDate DESC)
        WHERE IsDeleted = 0;
END
GO

IF OBJECT_ID('dbo.CustomerPortalRequestItem', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CustomerPortalRequestItem
    (
        CustomerPortalRequestItemId BIGINT IDENTITY(1,1) NOT NULL,
        CustomerPortalRequestId     BIGINT NOT NULL,

        OrderDetailsItemId  INT           NULL,
        CustomerDeviceId    INT           NULL,
        MbaReportNumber     NVARCHAR(100) NULL,
        SerialNumber        NVARCHAR(100) NULL,
        Notes               NVARCHAR(1000) NULL,

        CONSTRAINT PK_CustomerPortalRequestItem PRIMARY KEY CLUSTERED (CustomerPortalRequestItemId),
        CONSTRAINT FK_CustomerPortalRequestItem_Request FOREIGN KEY (CustomerPortalRequestId)
            REFERENCES dbo.CustomerPortalRequest (CustomerPortalRequestId)
    );

    CREATE NONCLUSTERED INDEX IX_CustomerPortalRequestItem_Request
        ON dbo.CustomerPortalRequestItem (CustomerPortalRequestId);
END
GO
