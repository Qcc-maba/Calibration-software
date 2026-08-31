/*
    dbo.GetCustomerSupportData                                        MBA-936
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
-- =============================================
-- Author:      Eduard Kudlaiev
-- Create date: 10/03/2026
-- Description: The MABA account manager shown on the customer portal dashboard
--              ("׳©׳¨׳•׳× ׳׳§׳•׳—׳•׳× ׳׳‘\"׳" card). One employee per customer.
--
-- 2026-08-30 ג€” FIX: the customer was resolved from dbo.Users only.
--
--              Portal users are CUSTOMER CONTACTS, not staff accounts, so that lookup
--              could not work: of the 2,070 rows in dbo.CustomerContacts exactly one
--              appears in dbo.Users, and none of them carry a CustomerId there. The
--              variable therefore came back NULL and the final predicate
--              `WHERE c.CustomerId = @CustomerId` was always false ג€” the card was empty
--              for every portal user since the day it was written.
--
--              Now resolved from dbo.CustomerContacts first, falling back to dbo.Users,
--              which is the same convention GetCustomerProfile, GetCustomerDashboardData
--              and GetCustomerDeviceList already use. This SP was the only one in the
--              portal set that did not.
--
--              Output columns are unchanged, so the front end needs no change.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerSupportData]
    @LoggedInUserEmail NVARCHAR(50),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

    -- Primary resolution: portal contact login
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
    SELECT TOP 1 @CustomerId = cc.CustomerId
        FROM dbo.CustomerContacts AS cc
        WHERE cc.CustomerContactEmail = @LoggedInUserEmail
        ORDER BY cc.CustomerContactId ASC;   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */

    -- Fallback: user account login (support / staff mapped to a customer)
    IF @CustomerId IS NULL
    BEGIN
        SELECT TOP 1 @CustomerId = u.CustomerId
        FROM dbo.Users AS u
        WHERE u.Email = @LoggedInUserEmail;
    END

    IF @CustomerId IS NULL
        RETURN;

    SELECT
         u.FirstName
        ,u.LastName
        ,u.Email
        ,u.Phone
    FROM dbo.Customers AS c
    JOIN dbo.Users     AS u ON u.ID = c.CustomerSupportContactId
    WHERE c.CustomerId = @CustomerId;
END
