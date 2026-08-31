SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*
    dbo.GetPortalCustomerIds                                                        MBA-943
    =============================================================================================
    Every customer the portal caller is entitled to see, as a set.

    WHY THIS EXISTS
    ---------------
    A portal login is an e-mail address, and an e-mail address is not one customer. 3,684 addresses
    are a contact of more than one: davide@iscar.co.il is a contact of 22 ישקר entities,
    sharbaf_o@mac.org.il of 25 מכבי branches. Priority models an Iscar division as its own
    Customers row, not as a CustomerSites row - dbo.CustomerSites is empty for all of them - so
    from the database's point of view a plant manager simply has many customers.

    Until now every GetCustomer* proc resolved that to exactly one:

        SELECT TOP (1) @CustomerId = cc.CustomerId ... ORDER BY cc.CustomerContactId ASC

    Deterministic, but arbitrary, and measurably wrong. For davide@iscar.co.il the lowest contact
    id lands on ישקר בע"מ, which has ZERO devices, while ישקר-מתק"ש-תפן has 24, ישקר מיקרו-כלים 4
    and ישקר-מיבדקה 3. He logged in and saw an empty portal while 31 of his devices sat in the
    system. Measured across STAGE: 181 addresses see a blank portal despite owning devices, 240
    see only part of theirs, and 3,468 devices are hidden from their own contacts.

    THE DEVICE FILTER IS NOT COSMETIC
    ---------------------------------
    Not every association in Priority is a real one. davide@iscar.co.il is also listed against
    פאדאגיס ישראל פרמצבטיקה - an unrelated company - and against מקדמות מלקוחות, which is an
    accounting row rather than a customer. Both hold no devices today, but that is luck, not a
    rule. Since the portal now shows several customers at once, an untidy association would put
    another company's devices on an Iscar manager's screen with nothing to mark them as foreign.
    Restricting the set to customers that actually hold devices removes both, and does it on a
    property the portal genuinely depends on.

    The fallback matters: if NONE of the caller's customers hold a device, the whole set is
    returned rather than nothing. A newly registered customer with no calibrations yet must see an
    empty device list, not a portal that cannot resolve who they are - the profile, contacts and
    support screens still have to work.

    IsPrimary
    ---------
    The union is right for devices, reports and calibrations. It is meaningless for the screens
    that describe ONE customer - profile, contacts, sites, support, and the Priority invoices and
    quotes, which are keyed by a single CustomerIdFromSource. Those take the row flagged IsPrimary:
    most devices first, lowest contact id to break a tie. That is still one customer, but it is now
    the one the caller actually works with instead of whichever id happened to be lowest.

    SECURITY
    --------
    The set is derived from the caller's own CustomerContacts rows and nothing else. There is no
    parameter through which a caller can name a customer, so there is nothing to verify and nothing
    to forge. This replaces the @SelectedCustomerId parameter added in MBA-936, which was built for
    a branch picker that we are not building.
*/
CREATE OR ALTER FUNCTION dbo.GetPortalCustomerIds (@LoggedInUserEmail NVARCHAR(100))
RETURNS TABLE
AS
RETURN
    WITH mine AS
    (
        /* One row per customer this address is a contact of, plus the id that used to decide
           everything - still useful as a stable tie-break. */
        SELECT cc.CustomerId,
               MIN(cc.CustomerContactId) AS FirstContactId
        FROM dbo.CustomerContacts AS cc
        WHERE ISNULL(cc.IsDeleted, 0) = 0
          AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)))
        GROUP BY cc.CustomerId
    ),
    counted AS
    (
        SELECT m.CustomerId,
               m.FirstContactId,
               d.DeviceCount
        FROM mine AS m
        CROSS APPLY
        (
            SELECT COUNT_BIG(DISTINCT itm.SerialNumber) AS DeviceCount
            FROM dbo.OrderWorkPlans AS wp
            JOIN dbo.OrderDetails AS od ON od.OrderWorkPlanId = wp.OrderWorkPlanId
            JOIN dbo.OrderDetailsItems AS itm ON itm.OrderDetailId = od.OrderDetailId
            WHERE wp.CustomerId = m.CustomerId
        ) AS d
    ),
    kept AS
    (
        SELECT * FROM counted WHERE DeviceCount > 0

        UNION ALL

        /* Fallback - see header. Only fires when the caller has no devices anywhere. */
        SELECT * FROM counted
        WHERE NOT EXISTS (SELECT 1 FROM counted AS any_devices WHERE any_devices.DeviceCount > 0)
    )
    SELECT k.CustomerId,
           c.CustomerName,
           k.DeviceCount,
           CONVERT(BIT, IIF(ROW_NUMBER() OVER (ORDER BY k.DeviceCount DESC, k.FirstContactId ASC) = 1, 1, 0)) AS IsPrimary
    FROM kept AS k
    LEFT JOIN dbo.Customers AS c ON c.CustomerId = k.CustomerId;
GO
