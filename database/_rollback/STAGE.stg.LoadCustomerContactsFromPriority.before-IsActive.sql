
CREATE   PROCEDURE stg.LoadCustomerContactsFromPriority
    @ReportOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* Everything Priority holds for a customer, not just the one row flagged for orders. */
    DROP TABLE IF EXISTS #PB;
    SELECT * INTO #PB FROM OPENQUERY([31.168.173.93], '
        SELECT PHONE, CUST,
               NAME        = LTRIM(RTRIM(NAME)),
               POSITIONDES = LTRIM(RTRIM(POSITIONDES)),
               PHONENUM    = LTRIM(RTRIM(PHONENUM)),
               OFFICEPHONE = LTRIM(RTRIM(OFFICEPHONE)),
               CELLPHONE   = LTRIM(RTRIM(CELLPHONE)),
               EMAIL       = LTRIM(RTRIM(EMAIL)),
               ORDFLAG     = LTRIM(RTRIM(ISNULL(ORDFLAG,'''')))  ,
               NOTMAIL     = LTRIM(RTRIM(ISNULL(MBA_NOTMAIL,'''')))
        FROM amaba.dbo.PHONEBOOK
        WHERE CUST > 0
    ');

    IF @ReportOnly = 1
    BEGIN
        SELECT PhonebookRows      = COUNT(*),
               CustomersInPriority= COUNT(DISTINCT p.CUST),
               MatchOurCustomers  = COUNT(DISTINCT CASE WHEN c.CustomerId IS NOT NULL THEN p.CUST END),
               RowsWeWouldTake    = SUM(CASE WHEN c.CustomerId IS NOT NULL THEN 1 ELSE 0 END),
               MarkedPrimary      = SUM(CASE WHEN c.CustomerId IS NOT NULL AND p.ORDFLAG = 'Y' THEN 1 ELSE 0 END),
               MarkedDoNotMail    = SUM(CASE WHEN c.CustomerId IS NOT NULL AND p.NOTMAIL = 'Y' THEN 1 ELSE 0 END)
        FROM #PB AS p
        LEFT JOIN dbo.Customers AS c ON c.CustomerIdFromSource = p.CUST;
        RETURN;
    END

    DELETE FROM stg.stg_CustomerContacts;

    INSERT INTO stg.stg_CustomerContacts
          (CustomerContactIdFromSource, CustomerContactName, CustomerContactPersonRole,
           CustomerContactPhone, CustomerContactAdditionalPhoneNumber, CustomerContactEmail,
           CustomerId, SourceSystem, IsPrimary, DoNotMail)
    SELECT p.PHONE,
           LEFT(p.NAME, 100),
           LEFT(NULLIF(p.POSITIONDES, ''), 100),
           /* the desk number if there is one, otherwise the office line */
           LEFT(COALESCE(NULLIF(p.PHONENUM, ''), NULLIF(p.OFFICEPHONE, '')), 100),
           LEFT(NULLIF(p.CELLPHONE, ''), 100),
           LEFT(NULLIF(p.EMAIL, ''), 100),
           p.CUST,
           s.SourceName,
           CAST(CASE WHEN p.ORDFLAG = 'Y' THEN 1 ELSE 0 END AS BIT),
           CAST(CASE WHEN p.NOTMAIL = 'Y' THEN 1 ELSE 0 END AS BIT)
    FROM #PB AS p
    JOIN dbo.Customers AS c ON c.CustomerIdFromSource = p.CUST
    JOIN dbo.Source    AS s ON s.SourceId = c.SourceId
    WHERE NULLIF(p.NAME, '') IS NOT NULL;

    SELECT Staged      = COUNT(*),
           Customers   = COUNT(DISTINCT CustomerId),
           Primary_    = SUM(CAST(IsPrimary AS INT)),
           DoNotMail_  = SUM(CAST(DoNotMail AS INT))
    FROM stg.stg_CustomerContacts;
END
