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

    2026-09-08 - THE DOCUMENT ITSELF
    ---------------------------------------------------------------------------------------------
    The portal's invoice screen has a document icon that had nothing behind it. Priority keeps the
    printed invoice as an attachment in EXTFILES, keyed by INVOICES.IV: 56,582 of its 315,491
    invoices have one. EXTFILENAME is a path relative to the Priority root, and each attachment
    sits in its own hash directory.

    Only the DIRECTORY is returned, never the file name, and deliberately: Priority stores the name
    in visual order, so the Hebrew in it is reversed against what is actually on disk - the file
    "הדפסת קבלה - K2602732_ מסטרקרד פלטינום.pdf" is stored with every Hebrew run backwards. The
    directory is ASCII and survives; the caller opens it and takes the file whose size matches
    documentFileSize.

    THE WHOLE STATEMENT RUNS REMOTELY. Written as a four-part join, the attachment lookup became
    one remote call per invoice: 65 seconds for 1,361 invoices, against one second before it
    existed. Inside OPENQUERY the join happens on the Priority server and the cost disappears.
    @Cust is an INT, so embedding it in the remote text carries no injection risk.
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

    DECLARE @Quote CHAR(1) = CHAR(39);
    DECLARE @Slash CHAR(1) = CHAR(92);

    /* The statement as the Priority server will see it. */
    DECLARE @RemoteQuery NVARCHAR(MAX) =
        N'SELECT iv.IVNUM, iv.IVDATE, iv.TOTPRICE, iv.IVBALANCE,'
      + N' DocumentType = t.IVDES,'
      + N' IsReceipt = CASE WHEN t.RECEIPT = ' + @Quote + N'Y' + @Quote + N' THEN 1 ELSE 0 END,'
      + N' DocumentDirectory = LEFT(e.EXTFILENAME, LEN(e.EXTFILENAME) - CHARINDEX(' + @Quote + @Slash + @Quote + N', REVERSE(e.EXTFILENAME))),'
      + N' DocumentFileSize = e.FILESIZE'
      + N' FROM amaba.dbo.INVOICES AS iv'
      /* IVTYPES names the document: TYPE T is קבלה - every K-numbered row on this screen - while
         C is a חש. מרכזת or a חש. זיכוי. TYPE alone is not unique, so FNCPATTERN joins with it.
         OTYPE C keeps this to customer-side documents; the P types are supplier paperwork. */
      + N' LEFT JOIN amaba.dbo.IVTYPES AS t ON t.TYPE = iv.TYPE AND t.FNCPATTERN = iv.FNCPATTERN'
      + N' OUTER APPLY ('
      + N'   SELECT TOP (1) x.EXTFILENAME, x.FILESIZE'
      + N'   FROM amaba.dbo.EXTFILES AS x'
      + N'   WHERE x.IV = iv.IV'
      + N'     AND x.EXTFILENAME LIKE ' + @Quote + N'%.pdf' + @Quote
      + N'     AND CHARINDEX(' + @Quote + @Slash + @Quote + N', x.EXTFILENAME) > 0'
      + N'   ORDER BY x.CURDATE DESC, x.EXTFILENUM DESC'
      + N' ) AS e'
      + N' WHERE iv.CUST = ' + CAST(@Cust AS NVARCHAR(20))
      + N'   AND ISNULL(t.OTYPE, ' + @Quote + N'C' + @Quote + N') = ' + @Quote + N'C' + @Quote + N';';

    /* ... wrapped as a string literal inside OPENQUERY, so every quote in it doubles. */
    DECLARE @Sql NVARCHAR(MAX) =
        N'SELECT r.IVNUM AS invoiceNumber,'
      + N' CONVERT(varchar(10), DATEADD(MINUTE, r.IVDATE, ' + @Quote + N'1988-01-01' + @Quote + N'), 104) AS invoiceDate,'
      + N' r.TOTPRICE AS totalPrice,'
      + N' r.IVBALANCE AS balance,'
      + N' CAST(CASE WHEN r.IVBALANCE = 0 THEN 1 ELSE 0 END AS bit) AS isPaid,'
      + N' r.DocumentType AS documentType,'
      + N' CAST(r.IsReceipt AS bit) AS isReceipt,'
      + N' r.DocumentDirectory AS documentDirectory,'
      + N' r.DocumentFileSize AS documentFileSize,'
      + N' CAST(CASE WHEN r.DocumentDirectory IS NULL THEN 0 ELSE 1 END AS bit) AS hasDocument'
      + N' FROM OPENQUERY([31.168.173.93], ' + @Quote + REPLACE(@RemoteQuery, @Quote, @Quote + @Quote) + @Quote + N') AS r'
      + N' ORDER BY r.IVDATE DESC;';

    EXEC sp_executesql @Sql;
END
GO
