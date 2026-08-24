-- =============================================
-- Proc:        dbo.GetCustomerQuotesFromPriority
-- Jira:        MBA-871 (Customer portal — Quotes / הצעות מחיר page)
-- Screen:      הצעות מחיר (Figma Portal 7725-1504 / 7725-2089)
-- Description: Quote (price-proposal) fields live in the Priority ERP, not the Calibrator DB.
--              Fetches them live over the linked server [31.168.173.93].amaba (dbo.CPROF),
--              scoped to the logged-in customer.
-- Identity:    @LoggedInUserEmail → dbo.CustomerContacts.CustomerId → dbo.Customers.CustomerIdFromSource
--              = Priority CUST.
-- Dates:       Priority dates = minutes since 1988-01-01. NULLIF(x,0) guards empty EXPIRYDATE.
-- Returns:     quoteNumber, quoteDate, validUntil, totalPrice, finalPrice (after discount),
--              discount (= TOTPRICE - DISPRICE), statusCode (CPROFSTAT)
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerQuotesFromPriority]
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
         cp.CPROFNUM                                                                    AS quoteNumber
        ,CONVERT(varchar(10), DATEADD(MINUTE, cp.PDATE, '1988-01-01'), 104)             AS quoteDate
        ,CONVERT(varchar(10), DATEADD(MINUTE, NULLIF(cp.EXPIRYDATE, 0), '1988-01-01'), 104) AS validUntil
        ,cp.TOTPRICE                                                                    AS totalPrice
        ,cp.DISPRICE                                                                    AS finalPrice
        ,(cp.TOTPRICE - cp.DISPRICE)                                                    AS discount
        ,cp.CPROFSTAT                                                                   AS statusCode
    FROM [31.168.173.93].[amaba].[dbo].[CPROF] AS cp
    WHERE cp.CUST = @Cust
    ORDER BY cp.PDATE DESC;
END
GO
