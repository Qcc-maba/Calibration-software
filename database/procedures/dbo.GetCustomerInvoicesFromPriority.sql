/*
    dbo.GetCustomerInvoicesFromPriority                                        MBA-936
    ---------------------------------------------------------------------------------------------
    Takes an optional @SelectedCustomerId: the branch the caller chose, for a contact whose e-mail
    address serves more than one customer. 3,684 addresses do - davide@iscar.co.il covers 22 ישקר
    sites, sharbaf_o@mac.org.il covers 25 מכבי branches.

    Without it, the customer is resolved as before: the lowest CustomerContactId for that address.
    That is stable but arbitrary, and it can land on a branch holding nothing while another of the
    caller's own branches holds their devices.

    THE ID IS VERIFIED, NOT TRUSTED. It is used only when the caller really is a contact of that
    customer; anything else falls through to the original pick. Passing a customer the caller does
    not serve returns their own data, never the other customer's - checked against a customer with
    71 order lines, which returned nothing.
*/
CREATE OR ALTER PROCEDURE dbo.GetCustomerInvoicesFromPriority
    @LoggedInUserEmail NVARCHAR(100),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CustomerId INT, @Cust INT;
        /* MBA-936: honour the chosen branch, but only if this caller really is a contact of it.
       3,684 addresses serve more than one customer; sharbaf_o@mac.org.il covers 25 מכבי branches.
       Without a choice, or with one that does not belong to the caller, this falls through to the
       original deterministic pick - never to the id it was handed. */
    IF @SelectedCustomerId IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.CustomerContacts AS v
                   WHERE v.CustomerId = @SelectedCustomerId
                     AND ISNULL(v.IsDeleted, 0) = 0
                     AND LOWER(LTRIM(RTRIM(v.CustomerContactEmail)))
                       = LOWER(LTRIM(RTRIM(@LoggedInUserEmail))))
        SET @CustomerId = @SelectedCustomerId;
    ELSE
    SELECT TOP 1 @CustomerId = CustomerId FROM dbo.CustomerContacts
          WHERE CustomerContactEmail = @LoggedInUserEmail AND ISNULL(IsDeleted,0)=0
          ORDER BY CustomerContactId ASC   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */;
    SELECT @Cust = TRY_CONVERT(INT, CustomerIdFromSource) FROM dbo.Customers WHERE CustomerId=@CustomerId;
    IF @Cust IS NULL RETURN;
    SELECT iv.IVNUM AS invoiceNumber,
        CONVERT(varchar(10), DATEADD(MINUTE, iv.IVDATE, '1988-01-01'), 104) AS invoiceDate,
        iv.TOTPRICE AS totalPrice, iv.IVBALANCE AS balance,
        CAST(CASE WHEN iv.IVBALANCE = 0 THEN 1 ELSE 0 END AS bit) AS isPaid
    FROM [31.168.173.93].amaba.dbo.INVOICES AS iv
    WHERE iv.CUST = @Cust
    ORDER BY iv.IVDATE DESC;
END