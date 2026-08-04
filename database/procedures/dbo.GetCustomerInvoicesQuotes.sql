-- =============================================
-- Proc:        dbo.GetCustomerInvoicesQuotes
-- Jira:        MBA-797 (Customer Invoice/Quotes page — customer/invoice)
-- Description: Customer-portal Invoices/Quotes grid (screen has two tabs: "quotes" and
--              "invoices"). Identity input matches the other customer-portal SPs
--              (@LoggedInUserEmail -> CustomerId via dbo.CustomerContacts) and is scoped
--              to the calling customer only, consistent with dbo.GetCustomerDashboardData
--              / dbo.GetCustomerDeviceList.
--
--              *** PARTIAL / SCAFFOLD — see the "BLOCKED" note below. ***
--              The Calibrator DB holds calibration ORDERS with per-line pricing
--              (OrderDetails.PRICE = net, OrderDetails.VPRICE = VAT-inclusive), but it does
--              NOT hold billing/financial DOCUMENTS. It has no invoice numbers, no quote
--              numbers, no discount amounts, and no "paid by" party. Those live in the
--              Priority ERP and are not synced into Calibrator on STAGE:
--                  - OrderWorkPlans.BK_DOC_N is 100% NULL (0 distinct values on STAGE).
--                  - There is no Quotes / Invoices / Discount / Payments table.
--              This SP therefore returns one row per calibration order with the fields that
--              ARE legitimately available, and returns NULL for every field that must come
--              from Priority. It does NOT fabricate invoice/quote numbers or discounts.
--
--              There is also no data in Calibrator to split rows into "quotes" vs
--              "invoices"; @DocType is accepted for forward-compatibility but currently only
--              affects nothing (all rows are order-derived). FE tabs can filter later once
--              the Priority-sourced document type exists.
--
-- Output columns (superset covering both FE tabs; camelCase to match FE Raw* row types):
--   id, orderNumber, date, invoiceNumber, invoiceDate, quoteNumber,
--   price, discount, finalPrice, paidBy
--     * date / invoiceDate -> DD.MM.YYYY (CONVERT style 104) from WorkPlanOpenDate.
--     * price              -> SUM(OrderDetails.PRICE)  net, per order, 2dp string.
--     * finalPrice         -> SUM(OrderDetails.VPRICE) VAT-inclusive, per order, 2dp string.
--                             (NOTE: this is VAT-inclusive total, NOT a post-discount final;
--                              a true finalPrice needs the Priority discount — see BLOCKED.)
--     * invoiceNumber / invoiceDate / quoteNumber / discount / paidBy -> NULL (Priority ERP).
--
-- REVIEW / OPEN QUESTION (Ariel / Dako): confirm whether the Invoices/Quotes screen should
--   be sourced from a Priority sync (invoice/quote documents, discounts, paid-by) rather
--   than from Calibrator orders. If yes, this screen is blocked on that sync; if the intent
--   is "order pricing" only, drop the invoice/quote/discount/paidBy columns from the design.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerInvoicesQuotes]
    @LoggedInUserEmail NVARCHAR(50),
    @DocType           VARCHAR(10) = NULL   -- reserved: 'quotes' | 'invoices' (no source yet)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

    SELECT TOP (1) @CustomerId = cc.CustomerId
    FROM [dbo].[CustomerContacts] AS cc
    WHERE cc.CustomerContactEmail = @LoggedInUserEmail;

    ;WITH orderTotals AS
    (
        SELECT
             wp.OrderWorkPlanId
            ,wp.OrderNumber
            ,wp.WorkPlanOpenDate
            ,SUM(ISNULL(od.PRICE, 0))  AS NetTotal
            ,SUM(ISNULL(od.VPRICE, 0)) AS VatTotal
        FROM [dbo].[OrderWorkPlans] AS wp
        JOIN [dbo].[OrderDetails]   AS od ON od.OrderWorkPlanId = wp.OrderWorkPlanId
        WHERE wp.CustomerId          = @CustomerId
          AND wp.IsCancelled         = 0
          AND ISNULL(od.IsDeleted, 0)  = 0
          AND ISNULL(od.IsCancelled,0) = 0
        GROUP BY wp.OrderWorkPlanId, wp.OrderNumber, wp.WorkPlanOpenDate
    )
    SELECT
         ot.OrderWorkPlanId                                        AS id
        ,ot.OrderNumber                                            AS orderNumber
        ,CONVERT(VARCHAR(10), ot.WorkPlanOpenDate, 104)           AS date
        ,CAST(NULL AS NVARCHAR(50))                                AS invoiceNumber   -- Priority ERP (not in Calibrator)
        ,CONVERT(VARCHAR(10), ot.WorkPlanOpenDate, 104)           AS invoiceDate     -- placeholder = order date; real invoice date is Priority
        ,CAST(NULL AS NVARCHAR(50))                                AS quoteNumber     -- Priority ERP (not in Calibrator)
        ,CONVERT(VARCHAR(20), CAST(ot.NetTotal AS DECIMAL(18,2)))  AS price           -- net
        ,CAST(NULL AS NVARCHAR(20))                                AS discount        -- Priority ERP (not in Calibrator)
        ,CONVERT(VARCHAR(20), CAST(ot.VatTotal AS DECIMAL(18,2)))  AS finalPrice      -- VAT-inclusive total (see header note)
        ,CAST(NULL AS NVARCHAR(100))                               AS paidBy          -- Priority ERP (not in Calibrator)
    FROM orderTotals AS ot
    ORDER BY ot.WorkPlanOpenDate DESC
    OPTION (RECOMPILE);
END
