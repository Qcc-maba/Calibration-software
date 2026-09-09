/*
    dbo.GetUserNames
    ---------------------------------------------------------------------------------------------
    The e-mail list behind the username dropdown on the sign-in screen.

    Why this changed
    ----------------
    It used to return every active address in the table. On PROD that is 2,136 rows, of which
    2,099 are CUSTOMERS - so the sign-in page of cal.qcc.co.il was publishing MABA's entire
    customer contact list to anyone who opened it, without logging in.

    Now it returns staff only: 37 rows.

    Why the filter is on the ROLE and not on the e-mail domain
    ----------------------------------------------------------
    "Only @mba.co.il" was the obvious rule and it is wrong - three active members of staff do not
    have an MABA address, and a domain filter would lock them out of the system:

        0523862631                  אלון אזולאי       Calibrator   (a phone number in the e-mail column)
        erel@larit.co.il            קבלן משנה-לרית    Calibrator   (subcontractor)
        lilach_ch@sepharma.co.il    לילך שאוט         OperationManager

    Excluding the Customer role keeps all three and still removes all 2,099 customers, which is
    what the request was actually about. It also stays correct when a new member of staff arrives
    on some other domain.

    Safe to deploy: not one of the 2,099 customers has ever signed in - LastLoginDate is NULL for
    every one of them. Customers authenticate through the separate e-mail one-time-code flow
    (MBA-892 / MBA-893), which does not use this list.

    Worth saying plainly
    --------------------
    A dropdown that lists valid usernames is an account-enumeration aid whatever it is filtered
    to. This change removes the customer leak; it does not make the pattern a good one. Replacing
    the dropdown with a plain text field is the real fix and belongs to the front end.
*/
CREATE OR ALTER PROCEDURE [dbo].[GetUserNames]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT u.Email
    FROM dbo.Users AS u
    LEFT JOIN dbo.UserRoles AS r ON r.UserRoleId = u.UserRoleId
    WHERE LEN(TRIM(u.Email)) > 0
      AND u.IsActive = 1
      AND u.ID > 0                                   -- excludes the ETL service account
      AND ISNULL(r.UserRoleName, N'') <> N'Customer' -- staff only; see header
    ORDER BY u.Email;
END
