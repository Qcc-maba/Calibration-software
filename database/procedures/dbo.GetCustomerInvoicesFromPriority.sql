-- =============================================
-- Proc:        dbo.GetCustomerInvoicesFromPriority
-- Jira:        MBA-871 (Customer portal — Invoices page)
-- Screen:      חשבוניות (Figma Portal 7725-1504 / 7725-2089)
-- Description: The customer portal's invoice fields do NOT live in the Calibrator DB — billing is
--              managed in the Priority ERP. This SP fetches them live over the existing linked
--              server [31.168.173.93].amaba (dbo.INVOICES), scoped to the logged-in customer.
-- Identity:    @LoggedInUserEmail → dbo.CustomerContacts.CustomerId → dbo.Customers.CustomerIdFromSource
--              = Priority CUST (verified: AWS CustomerIdFromSource == Priority CUST).
-- Dates:       Priority stores dates as minutes since 1988-01-01 → DATEADD(MINUTE, x, '1988-01-01').
-- Returns:     invoiceNumber, invoiceDate (DD.MM.YYYY), totalPrice, balance, isPaid
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerInvoicesFromPriority]
    @LoggedInUserEmail NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT, @Cust INT;

    SELECT TOP 1 @CustomerId = CustomerId
    FROM dbo.CustomerContacts
    WHERE CustomerContactEmail = @LoggedInUserEmail AND ISNULL(IsDeleted, 0) = 0;

    SELECT @Cust = TRY_CONVERT(INT, CustomerIdFromSource)
    FROM dbo.Customers WHERE CustomerId = @CustomerId;

    IF @Cust IS NULL RETURN;

    SELECT
         iv.IVNUM                                                              AS invoiceNumber
        ,CONVERT(varchar(10), DATEADD(MINUTE, iv.IVDATE, '1988-01-01'), 104)   AS invoiceDate
        ,iv.TOTPRICE                                                           AS totalPrice
        ,iv.IVBALANCE                                                          AS balance
        ,CAST(CASE WHEN iv.IVBALANCE = 0 THEN 1 ELSE 0 END AS bit)             AS isPaid
    FROM [31.168.173.93].[amaba].[dbo].[INVOICES] AS iv
    WHERE iv.CUST = @Cust
    ORDER BY iv.IVDATE DESC;
END
GO
