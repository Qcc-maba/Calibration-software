SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*
    dbo.GetCustomerInvoicesFromPriority                                             MBA-894
    ---------------------------------------------------------------------------------------------
    Invoices straight from Priority over the linked server, keyed by CustomerIdFromSource = CUST.
    Priority stores dates as minutes since 1988-01-01.

    2026-08-31 - MBA-943: which customer, when the address serves several.

    DELIBERATELY NOT A UNION. The device and report screens now show every company the caller
    belongs to, because a plant manager owning devices in three ישקר divisions should see all of
    them. Invoices are different: they are financial, and joining three subsidiaries' balances into
    one list is a disclosure decision, not a display decision. Until that is decided by the
    business, this stays scoped to ONE customer.

    What did change is WHICH one. The old rule took the lowest CustomerContactId, which for
    davide@iscar.co.il is ישקר בע"מ - a row with no devices and, in all likelihood, no invoices
    he cares about. It now takes the primary customer: the one holding the most devices.

    @SelectedCustomerId is gone; MBA-936 added it for a branch picker we decided not to build.
*/
CREATE OR ALTER PROCEDURE dbo.GetCustomerInvoicesFromPriority
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

    SELECT iv.IVNUM AS invoiceNumber,
        CONVERT(varchar(10), DATEADD(MINUTE, iv.IVDATE, '1988-01-01'), 104) AS invoiceDate,
        iv.TOTPRICE AS totalPrice, iv.IVBALANCE AS balance,
        CAST(CASE WHEN iv.IVBALANCE = 0 THEN 1 ELSE 0 END AS bit) AS isPaid
    FROM [31.168.173.93].amaba.dbo.INVOICES AS iv
    WHERE iv.CUST = @Cust
    ORDER BY iv.IVDATE DESC;
END
GO
