SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*
    dbo.GetCustomerQuotesFromPriority                                               MBA-894
    ---------------------------------------------------------------------------------------------
    Quotes straight from Priority over the linked server, keyed by CustomerIdFromSource = CUST.
    Priority stores dates as minutes since 1988-01-01; EXPIRYDATE 0 means "no expiry", hence the
    NULLIF before the conversion.

    2026-08-31 - MBA-943: which customer, when the address serves several.

    Scoped to ONE customer for the same reason as GetCustomerInvoicesFromPriority: pricing is
    commercial information, and merging three subsidiaries' quotes into one list is a business
    decision rather than a display one. The customer picked is now the PRIMARY one - the one
    holding the most devices - instead of whichever had the lowest CustomerContactId.

    @SelectedCustomerId is gone; MBA-936 added it for a branch picker we decided not to build.
*/
CREATE OR ALTER PROCEDURE dbo.GetCustomerQuotesFromPriority
    @LoggedInUserEmail NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CustomerId INT, @Cust INT;

    /* MBA-943: primary = most devices, lowest contact id to break a tie. */
    SELECT @CustomerId = CustomerId
    FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail)
    WHERE IsPrimary = 1;

    SELECT @Cust = TRY_CONVERT(INT, CustomerIdFromSource) FROM dbo.Customers WHERE CustomerId = @CustomerId;
    IF @Cust IS NULL RETURN;

    /* The whole statement runs on the Priority side.

       It used to be a four-part-name read - FROM [31.168.173.93].amaba.dbo.CPROF WHERE cp.CUST =
       @Cust - which lets SQL Server decide how to satisfy the filter across the link, and it does
       not push it down. Measured on PROD for a customer with 684 quote rows: 1,194 ms that way,
       481 ms with the filter sent to the remote server. Unlike the catalogue text there is no
       local cache here, so this cost is paid on every call.

       The date arithmetic stays local: Priority stores PDATE as minutes since 1988, and doing the
       conversion here keeps it in one place rather than inside a string. */
    DECLARE @Sql NVARCHAR(MAX) = N'
        SELECT CPROFNUM, PDATE, EXPIRYDATE, TOTPRICE, DISPRICE, CPROFSTAT
        FROM OPENQUERY([31.168.173.93], ''
            SELECT cp.CPROFNUM, cp.PDATE, cp.EXPIRYDATE, cp.TOTPRICE, cp.DISPRICE, cp.CPROFSTAT
            FROM amaba.dbo.CPROF cp
            WHERE cp.CUST = ' + CAST(@Cust AS NVARCHAR(20)) + N'
        '')';

    DROP TABLE IF EXISTS #Quotes;
    CREATE TABLE #Quotes (CPROFNUM NVARCHAR(50), PDATE INT, EXPIRYDATE INT, TOTPRICE FLOAT, DISPRICE FLOAT, CPROFSTAT NVARCHAR(50));
    INSERT #Quotes EXEC sp_executesql @Sql;

    SELECT cp.CPROFNUM AS quoteNumber,
        CONVERT(varchar(10), DATEADD(MINUTE, cp.PDATE, '1988-01-01'), 104) AS quoteDate,
        CONVERT(varchar(10), DATEADD(MINUTE, NULLIF(cp.EXPIRYDATE,0), '1988-01-01'), 104) AS validUntil,
        cp.TOTPRICE AS totalPrice, cp.DISPRICE AS finalPrice,
        (cp.TOTPRICE - cp.DISPRICE) AS discount, cp.CPROFSTAT AS statusCode
    FROM #Quotes AS cp
    ORDER BY cp.PDATE DESC;
END
GO
