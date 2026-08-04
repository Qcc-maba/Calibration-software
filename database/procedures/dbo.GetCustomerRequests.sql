-- =============================================
-- Proc:        dbo.GetCustomerRequests
-- Jira:        MBA-858 (Customer Support — customer-inquiry / requests list + action modals)
-- Description: Read SP that backs the customer-portal "requests / inquiries" list shown in the
--              Customer Support area (FE: components/customers/QuotesDialog.tsx, mock MOCK_QUOTES,
--              row shape TQuoteRow in components/customers/constants/quotes-dialog.ts). Returns one
--              row per calibration order (OrderWorkPlan) belonging to the logged-in customer — an
--              order IS the "request/quote" the customer submitted and that the 4 action modals
--              (cancel calibration / devices deleted / order for shipping / reject request) act on.
--
--              Identity + scoping follow the other customer-portal SPs
--              (@LoggedInUserEmail -> CustomerId via dbo.CustomerContacts), consistent with
--              dbo.GetCustomerDashboardData / dbo.GetCustomerDeviceList. Filtering / sorting are
--              done client-side (TanStack table), so the full clean set is returned, no paging.
--
-- Output columns (camelCase, exactly matching FE TQuoteRow):
--   status, quoteNumber, deviceCount, expectedCalibrationDate, calibrationLocation, price, note
--     * status                 -> FE quoteStatuses code. Sourced from the OrderStatus category
--                                 (StatusesCategories.StatusCategoryId = 9) via
--                                 COALESCE(wp.OrderStatusId, wp.OrderOverallStatusId). The 4 codes
--                                 the FE combobox styles are mapped explicitly; any other status
--                                 falls back to a lower-camel of StatusDescriptionENG (same pattern
--                                 as GetCustomerDeviceList).
--                                   66 Sent                -> 'sent'
--                                   72 Rejected            -> 'rejected'
--                                   73 AwaitingConfirmation -> 'waitingForCustomer'
--                                   76 WaitingForCalibration-> 'waitingForCalibration'
--     * quoteNumber            -> wp.OrderNumber.
--     * deviceCount            -> COUNT of non-deleted OrderDetailsItems in the order.
--     * expectedCalibrationDate-> DD.MM.YYYY (CONVERT 104) — MIN(OrderDetailsItems.NextCalibrationDate).
--     * calibrationLocation    -> 'lab' if any order line IsInHouse=1, else 'customer' (NULL if no lines).
--     * price                  -> SUM(OrderDetails.PRICE) net, DECIMAL(18,2) (NULL if none).
--     * note                   -> wp.Notes (fallback wp.CustomerComment).
--
-- NOTE for review (Ariel / Dako) — best-guess mappings, please confirm:
--   * status: STAGE has wp.OrderStatusId 100% NULL and wp.OrderOverallStatusId = 76 for every
--     order, so every row currently returns 'waitingForCalibration'. The id->FE-code map above is
--     the assumed lifecycle; confirm which OrderStatus ids represent sent / rejected / waiting-for-
--     customer once real status data flows in.
--   * expectedCalibrationDate: no dedicated column exists — using earliest item NextCalibrationDate.
--     Alt candidates: wp.WorkPlanOpenDate, OrderDetails.ActualCalibrationDate.
--   * price: net (PRICE). Alt: VPRICE (VAT-inclusive), as used by dbo.GetCustomerInvoicesQuotes.
--   Write actions (cancel calibration / devices deleted / order for shipping / reject request) are
--   OUT OF SCOPE here and tracked as separate follow-ups — see the Jira ticket.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerRequests]
    @LoggedInUserEmail NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

    SELECT TOP (1) @CustomerId = cc.CustomerId
    FROM [dbo].[CustomerContacts] AS cc
    WHERE cc.CustomerContactEmail = @LoggedInUserEmail;

    ;WITH req AS
    (
        SELECT
             wp.OrderWorkPlanId
            ,wp.OrderNumber
            ,COALESCE(wp.OrderStatusId, wp.OrderOverallStatusId)      AS StatusId
            ,COALESCE(NULLIF(LTRIM(RTRIM(wp.Notes)), N''),
                      NULLIF(LTRIM(RTRIM(wp.CustomerComment)), N''))   AS Note
            ,(
                SELECT COUNT(*)
                FROM [dbo].[OrderDetails]      AS od2
                JOIN [dbo].[OrderDetailsItems] AS it2 ON it2.OrderDetailId = od2.OrderDetailId
                WHERE od2.OrderWorkPlanId       = wp.OrderWorkPlanId
                  AND ISNULL(od2.IsDeleted, 0)  = 0
                  AND ISNULL(od2.IsCancelled,0) = 0
                  AND ISNULL(it2.IsDeleted, 0)  = 0
                  AND ISNULL(it2.IsCancelled,0) = 0
             )                                                         AS DeviceCount
            ,(
                SELECT MIN(it3.NextCalibrationDate)
                FROM [dbo].[OrderDetails]      AS od3
                JOIN [dbo].[OrderDetailsItems] AS it3 ON it3.OrderDetailId = od3.OrderDetailId
                WHERE od3.OrderWorkPlanId       = wp.OrderWorkPlanId
                  AND ISNULL(od3.IsDeleted, 0)  = 0
                  AND ISNULL(it3.IsDeleted, 0)  = 0
             )                                                         AS ExpectedCalibrationDate
            ,(
                SELECT MAX(CAST(ISNULL(od4.IsInHouse, 0) AS INT))
                FROM [dbo].[OrderDetails] AS od4
                WHERE od4.OrderWorkPlanId       = wp.OrderWorkPlanId
                  AND ISNULL(od4.IsDeleted, 0)  = 0
                  AND ISNULL(od4.IsCancelled,0) = 0
             )                                                         AS AnyInHouse
            ,(
                SELECT SUM(od5.PRICE)
                FROM [dbo].[OrderDetails] AS od5
                WHERE od5.OrderWorkPlanId       = wp.OrderWorkPlanId
                  AND ISNULL(od5.IsDeleted, 0)  = 0
                  AND ISNULL(od5.IsCancelled,0) = 0
             )                                                         AS NetPrice
        FROM [dbo].[OrderWorkPlans] AS wp
        WHERE wp.CustomerId  = @CustomerId
          AND wp.IsCancelled = 0
    )
    SELECT
         CASE r.StatusId
            WHEN 66 THEN 'sent'
            WHEN 72 THEN 'rejected'
            WHEN 73 THEN 'waitingForCustomer'
            WHEN 76 THEN 'waitingForCalibration'
            ELSE CASE
                    WHEN st.StatusDescriptionENG IS NULL
                      OR LEN(st.StatusDescriptionENG) = 0 THEN NULL
                    ELSE LOWER(LEFT(REPLACE(st.StatusDescriptionENG, '''', ''), 1))
                       + SUBSTRING(REPLACE(st.StatusDescriptionENG, '''', ''), 2, 200)
                 END
         END                                                          AS status
        ,r.OrderNumber                                                AS quoteNumber
        ,r.DeviceCount                                                AS deviceCount
        ,CONVERT(VARCHAR(10), r.ExpectedCalibrationDate, 104)         AS expectedCalibrationDate
        ,CASE
            WHEN r.AnyInHouse IS NULL THEN NULL
            WHEN r.AnyInHouse = 1     THEN 'lab'
            ELSE 'customer'
         END                                                          AS calibrationLocation
        ,CAST(r.NetPrice AS DECIMAL(18,2))                            AS price
        ,r.Note                                                       AS note
    FROM req AS r
    LEFT JOIN [dbo].[Statuses] AS st
           ON st.StatusId = r.StatusId
          AND st.StatusCategoryId = 9      -- OrderStatus category
    ORDER BY r.OrderWorkPlanId DESC
    OPTION (RECOMPILE);
END
