/*
    dbo.GetOrderApprovalDetails
    ---------------------------
    Everything the coordination e-mail ("אישור תיאום כיול") needs about one order, in a single
    row so a Prisma $queryRaw call can read it (only the first result set survives that API).

    Parameters:
      @OrderWorkPlanId INT  (required)

    Returns exactly 0 or 1 rows:
      OrderWorkPlanId, OrderNumber, CustomerId, CustomerName, CustomerNameENG,
      ClientConfirmationStatus  — current status, ENG ('New' when the column is NULL)
      IsCancelled
      PlacementDate             — תאריך שיבוץ: earliest CalibratorsToWorkPlan.AssigmentDate
      SiteAddress               — אתר הלקוח (first non-empty site on the order lines)
      CalibrationRange          — תחומי הכיול, comma separated MainCategories (Priority: תחום כיול)
      ContactName / ContactEmail / ContactPhone — the recipient of the e-mail
      ContactId
      RecipientCount            — how many contacts of this customer have an e-mail at all
      CalibratorsJson           — [{ "Name": "...", "Phone": "..." }]  שם וטלפון הכייל
      DevicesJson               — [{ "PartName", "ProductType", "Manufacturer", "Model",
                                     "SerialNumber", "AdditionalDeviceNumber", "Quantity" }]
                                  רשימת כלים — see the comment on the column below for the
                                  per-device / per-line fallback.
      SkusJson                  — ["999999", ...] distinct מק"טים, for the Priority intake call

    Contact resolution: contacts of the order's customer that have an e-mail, preferring one
    attached to a site that appears on the order, then the lowest CustomerContactId — the same
    "deterministic pick" rule dbo.GetCustomerPortalContactByEmail uses.

    Read-only.
*/
CREATE OR ALTER PROCEDURE dbo.GetOrderApprovalDetails
    @OrderWorkPlanId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @OrderWorkPlanId IS NULL
        RETURN;

    /* Sites that appear on this order's lines — used to prefer a site contact. */
    DROP TABLE IF EXISTS #OrderSites;
    CREATE TABLE #OrderSites (CustomerSiteId INT PRIMARY KEY);

    INSERT #OrderSites (CustomerSiteId)
    SELECT DISTINCT od.CustomerSiteId
    FROM dbo.OrderDetails AS od
    WHERE od.OrderWorkPlanId = @OrderWorkPlanId
      AND od.IsDeleted = 0
      AND od.CustomerSiteId IS NOT NULL;

    DECLARE @CustomerId INT =
    (
        SELECT wp.CustomerId
        FROM dbo.OrderWorkPlans AS wp
        WHERE wp.OrderWorkPlanId = @OrderWorkPlanId
    );

    DECLARE @ContactId    INT,
            @ContactName  NVARCHAR(100),
            @ContactEmail NVARCHAR(100),
            @ContactPhone NVARCHAR(100),
            @RecipientCount INT = 0;

    SELECT TOP (1)
        @ContactId    = cc.CustomerContactId,
        @ContactName  = cc.CustomerContactName,
        @ContactEmail = LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))),
        @ContactPhone = COALESCE(NULLIF(LTRIM(RTRIM(cc.CustomerContactPhone)), N''),
                                 cc.CustomerContactAdditionalPhoneNumber)
    FROM dbo.CustomerContacts AS cc
    WHERE cc.IsDeleted = 0
      AND cc.CustomerId = @CustomerId
      AND NULLIF(LTRIM(RTRIM(cc.CustomerContactEmail)), N'') IS NOT NULL
    ORDER BY
        CASE WHEN EXISTS (SELECT 1 FROM #OrderSites AS s WHERE s.CustomerSiteId = cc.CustomerSiteId)
             THEN 0 ELSE 1 END,
        cc.CustomerContactId ASC;

    SELECT @RecipientCount = COUNT(*)
    FROM dbo.CustomerContacts AS cc
    WHERE cc.IsDeleted = 0
      AND cc.CustomerId = @CustomerId
      AND NULLIF(LTRIM(RTRIM(cc.CustomerContactEmail)), N'') IS NOT NULL;

    SELECT
        wp.OrderWorkPlanId,
        wp.OrderNumber,
        wp.CustomerId,
        cust.CustomerName,
        cust.CustomerNameENG,
        COALESCE(st.StatusDescriptionENG, N'New')  AS ClientConfirmationStatus,
        wp.IsCancelled,

        (SELECT MIN(ctwp.AssigmentDate)
         FROM dbo.CalibratorsToWorkPlan AS ctwp
         WHERE ctwp.OrderWorkPlanId = wp.OrderWorkPlanId
           AND ctwp.IsDeleted = 0)                 AS PlacementDate,

        (SELECT TOP (1) NULLIF(LTRIM(RTRIM(cs.CustomerSiteAddress)), N'')
         FROM #OrderSites AS s
         JOIN dbo.CustomerSites AS cs ON cs.CustomerSiteId = s.CustomerSiteId
         WHERE NULLIF(LTRIM(RTRIM(cs.CustomerSiteAddress)), N'') IS NOT NULL
         ORDER BY cs.CustomerSiteId)                AS SiteAddress,

        (SELECT STRING_AGG(x.MainCategoryName, N', ')
         FROM (SELECT DISTINCT mc.MainCategoryName
               FROM dbo.OrderDetails AS od
               JOIN dbo.MainCategories AS mc ON mc.ID = od.MainCategoryId
               WHERE od.OrderWorkPlanId = wp.OrderWorkPlanId
                 AND od.IsDeleted = 0) AS x)        AS CalibrationRange,

        @ContactId                                  AS ContactId,
        @ContactName                                AS ContactName,
        @ContactEmail                               AS ContactEmail,
        @ContactPhone                               AS ContactPhone,
        @RecipientCount                             AS RecipientCount,

        ISNULL((SELECT LTRIM(RTRIM(CONCAT(u.FirstName, N' ', u.LastName))) AS [Name],
                       u.Phone                                            AS Phone
                FROM dbo.CalibratorsToWorkPlan AS ctwp
                JOIN dbo.Users AS u ON u.ID = ctwp.CalibratorId
                WHERE ctwp.OrderWorkPlanId = wp.OrderWorkPlanId
                  AND ctwp.IsDeleted = 0
                ORDER BY ctwp.CalibratorsToWorkPlanId
                FOR JSON PATH), N'[]')              AS CalibratorsJson,

        /*
            רשימת הכלים. Two sources, per order LINE, because OrderDetailsItems (the per-device
            rows carrying serial numbers) exist for only ~18% of scheduled orders on PROD, while
            every order has OrderDetails lines. Sourcing from the items alone left 82% of the
            coordination e-mails saying "אין כלים רשומים בהזמנה".

              * line HAS items  -> one entry per device, with its serial number (Quantity = 1)
              * line has NO items -> one entry for the line itself: the product-type description
                                     (OrdersProductTypeName, populated on 868/868 PROD lines) and
                                     the ordered quantity.

            The fallback is per line, not per order, so a partially-detailed order lists the
            devices it does have and summarises the rest instead of dropping them.
        */
        ISNULL((SELECT x.PartName,
                       x.ProductType,
                       x.Manufacturer,
                       x.Model,
                       x.SerialNumber,
                       x.AdditionalDeviceNumber,
                       x.Quantity
                FROM (
                        SELECT od.OrderDetailId,
                               itm.OrderDetailsItemId       AS SortKey,
                               od.PartName                  AS PartName,
                               opt.OrdersProductTypeName    AS ProductType,
                               itm.OrdersDeviceManufacturer AS Manufacturer,
                               itm.DeviceModel              AS Model,
                               itm.SerialNumber             AS SerialNumber,
                               itm.AdditionalDeviceNumber   AS AdditionalDeviceNumber,
                               1                            AS Quantity
                        FROM dbo.OrderDetails AS od
                        JOIN dbo.OrderDetailsItems AS itm ON itm.OrderDetailId = od.OrderDetailId
                        LEFT JOIN dbo.OrdersProductTypes AS opt
                               ON opt.OrdersProductTypeId = od.OrdersProductTypeId
                        WHERE od.OrderWorkPlanId = wp.OrderWorkPlanId
                          AND od.IsDeleted = 0
                          AND od.IsCancelled = 0
                          AND itm.IsDeleted = 0
                          AND itm.IsCancelled = 0

                        UNION ALL

                        SELECT od.OrderDetailId,
                               0                            AS SortKey,
                               od.PartName                  AS PartName,
                               opt.OrdersProductTypeName    AS ProductType,
                               CAST(NULL AS NVARCHAR(255))  AS Manufacturer,
                               CAST(NULL AS NVARCHAR(255))  AS Model,
                               CAST(NULL AS NVARCHAR(255))  AS SerialNumber,
                               CAST(NULL AS NVARCHAR(255))  AS AdditionalDeviceNumber,
                               ISNULL(od.OrderLineCnt, 1)   AS Quantity
                        FROM dbo.OrderDetails AS od
                        LEFT JOIN dbo.OrdersProductTypes AS opt
                               ON opt.OrdersProductTypeId = od.OrdersProductTypeId
                        WHERE od.OrderWorkPlanId = wp.OrderWorkPlanId
                          AND od.IsDeleted = 0
                          AND od.IsCancelled = 0
                          AND NOT EXISTS (SELECT 1
                                          FROM dbo.OrderDetailsItems AS itm
                                          WHERE itm.OrderDetailId = od.OrderDetailId
                                            AND itm.IsDeleted = 0
                                            AND itm.IsCancelled = 0)
                     ) AS x
                ORDER BY x.OrderDetailId, x.SortKey
                FOR JSON PATH), N'[]')              AS DevicesJson,

        ISNULL((SELECT CONCAT(N'["',
                              STRING_AGG(STRING_ESCAPE(x.PartName, 'json'), N'","'),
                              N'"]')
                FROM (SELECT DISTINCT od.PartName
                      FROM dbo.OrderDetails AS od
                      WHERE od.OrderWorkPlanId = wp.OrderWorkPlanId
                        AND od.IsDeleted = 0
                        AND od.IsCancelled = 0
                        AND NULLIF(LTRIM(RTRIM(od.PartName)), N'') IS NOT NULL) AS x),
               N'[]')                               AS SkusJson

    FROM dbo.OrderWorkPlans AS wp
    LEFT JOIN dbo.Customers AS cust ON cust.CustomerId = wp.CustomerId
    LEFT JOIN dbo.Statuses  AS st   ON st.StatusId     = wp.ClientConfirmationStatusId
    WHERE wp.OrderWorkPlanId = @OrderWorkPlanId;
END
GO
