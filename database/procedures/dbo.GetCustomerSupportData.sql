-- =============================================
-- Author:      Eduard Kudlaiev
-- Create date: 10/03/2026
-- Description: The MABA account manager shown on the customer portal dashboard
--              ("שרות לקוחות מב\"א" card). One employee per customer.
--
-- 2026-08-30 — FIX: the customer was resolved from dbo.Users only.
--
--              Portal users are CUSTOMER CONTACTS, not staff accounts, so that lookup
--              could not work: of the 2,070 rows in dbo.CustomerContacts exactly one
--              appears in dbo.Users, and none of them carry a CustomerId there. The
--              variable therefore came back NULL and the final predicate
--              `WHERE c.CustomerId = @CustomerId` was always false — the card was empty
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
    @LoggedInUserEmail NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

    -- Primary resolution: portal contact login
    SELECT TOP 1 @CustomerId = cc.CustomerId
    FROM dbo.CustomerContacts AS cc
    WHERE cc.CustomerContactEmail = @LoggedInUserEmail;

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
GO
