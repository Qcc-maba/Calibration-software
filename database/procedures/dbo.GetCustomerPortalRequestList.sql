SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*
    dbo.GetCustomerPortalRequestList                                                    MBA-903
    ---------------------------------------------------------------------------------------------
    The requests a customer has submitted from the portal, newest first, with their status.

    Without this the customer submits into silence: the popups write a request and nothing ever
    shows it again. This is the "did anyone see what I asked for" screen, and it is also what lets
    the UI stop a customer filing the same extension request four times.

    Output columns are camelCase to match the front-end row types, the same convention as
    GetCustomerRequests and GetCustomerDeviceList.

    statusLabel and typeLabel are the Hebrew the screen shows. They are resolved here rather than
    in the client so that the portal and any MBA-side view cannot drift into calling the same
    status two different things.

    @Status and @RequestType are optional filters; the list is otherwise returned whole, since
    filtering and sorting are done client-side.

    2026-08-31 - MBA-943: scoped to the caller's customer SET rather than a single customer.

    A request is filed against one company, but a manager who files against two of his divisions
    has to see both - otherwise half his own requests disappear from the screen that exists to
    prove they were received. Still impossible to see another customer's requests: the set comes
    from dbo.GetPortalCustomerIds, which is derived from the caller's own contact rows and takes
    nothing from the request.
*/
CREATE OR ALTER PROCEDURE dbo.GetCustomerPortalRequestList
    @LoggedInUserEmail NVARCHAR(100),
    @Status            NVARCHAR(20) = NULL,
    @RequestType       NVARCHAR(40) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
         r.CustomerPortalRequestId                         AS id
        ,r.RequestType                                     AS requestType
        ,CASE r.RequestType
            WHEN N'ReportUpdate'            THEN N'בקשה לעדכון דוח'
            WHEN N'Shipment'                THEN N'הזמנה לשינוע'
            WHEN N'CalibrationExtension'    THEN N'הארכת תוקף כיול'
            WHEN N'CalibrationCancellation' THEN N'בקשה לביטול הכיול'
            WHEN N'Quote'                   THEN N'בקשה להצעת מחיר'
            WHEN N'QuoteFeedback'           THEN N'התייחסות לקוח'
            WHEN N'DeviceRemoval'           THEN N'מחיקת מכשיר'
         END                                               AS typeLabel
        ,r.Status                                          AS status
        ,CASE r.Status
            WHEN N'New'        THEN N'חדש'
            WHEN N'InProgress' THEN N'בטיפול'
            WHEN N'Approved'   THEN N'אושר'
            WHEN N'Rejected'   THEN N'נדחה'
            WHEN N'Cancelled'  THEN N'בוטל'
            WHEN N'Done'       THEN N'הסתיים'
         END                                               AS statusLabel
        ,r.OrderWorkPlanId                                 AS orderId
        ,wp.OrderNumber                                    AS orderNumber
        ,r.MbaReportNumber                                 AS mbaReportNumber
        ,r.QuoteNumber                                     AS quoteNumber
        ,CONVERT(VARCHAR(10), r.RequestedDate, 104)        AS requestedDate
        ,r.Reason                                          AS reason
        ,r.Notes                                           AS notes
        ,r.ShippingMethod                                  AS shippingMethod
        ,r.ShippingDocument                                AS shippingDocument
        ,r.DeviceLocation                                  AS deviceLocation
        ,r.CalibrationLocation                             AS calibrationLocation
        ,r.AttachmentPath                                  AS attachmentPath
        ,COALESCE(r.DeviceCount, itm.ItemCount)            AS deviceCount
        ,itm.SerialNumbers                                 AS serialNumbers
        ,r.SubmittedByEmail                                AS submittedByEmail
        ,CONVERT(VARCHAR(10), r.CreatedDate, 104)          AS createdDate
        ,CONVERT(VARCHAR(10), r.ResolvedDate, 104)         AS resolvedDate
        ,r.ResolutionNotes                                 AS resolutionNotes
        ,mine.CustomerName                                 AS customerName
    FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail) AS mine
    JOIN dbo.CustomerPortalRequest AS r ON r.CustomerId = mine.CustomerId
    LEFT JOIN dbo.OrderWorkPlans AS wp ON wp.OrderWorkPlanId = r.OrderWorkPlanId
    OUTER APPLY
    (
        SELECT COUNT(*) AS ItemCount,
               STRING_AGG(i.SerialNumber, N', ') WITHIN GROUP (ORDER BY i.SerialNumber) AS SerialNumbers
        FROM dbo.CustomerPortalRequestItem AS i
        WHERE i.CustomerPortalRequestId = r.CustomerPortalRequestId
    ) AS itm
    WHERE r.IsDeleted = 0
      AND (@Status      IS NULL OR r.Status      = @Status)
      AND (@RequestType IS NULL OR r.RequestType = @RequestType)
    ORDER BY r.CreatedDate DESC;
END
GO
