SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Author:      Eduard Kudlaiev
-- Create date: 10/03/2026
-- Description: The MABA account manager shown on the customer portal dashboard
--              ("שרות לקוחות מב"א" card). One employee per customer.
--
-- 2026-08-30 - FIX: the customer was resolved from dbo.Users only.
--
--              Portal users are CUSTOMER CONTACTS, not staff accounts, so that lookup
--              could not work: of the 2,070 rows in dbo.CustomerContacts exactly one
--              appears in dbo.Users, and none of them carry a CustomerId there. The
--              variable therefore came back NULL and the final predicate
--              `WHERE c.CustomerId = @CustomerId` was always false - the card was empty
--              for every portal user since the day it was written.
--
--              Now resolved from the portal contact first, falling back to dbo.Users.
--
-- 2026-08-31 - MBA-943: which customer, when the address serves several.
--
--              This card names ONE account manager, so it cannot be a union. It now takes
--              the caller's PRIMARY customer - the one holding the most devices - instead
--              of the one with the lowest CustomerContactId. For davide@iscar.co.il the old
--              rule pointed at ישקר בע"מ, a row with no devices; his work is under
--              ישקר-מתק"ש-תפן, and so is the account manager who actually handles it.
--
--              @SelectedCustomerId is gone: MBA-936 added it for a branch picker we decided
--              not to build.
--
--              Output columns are unchanged, so the front end needs no change.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerSupportData]
    @LoggedInUserEmail NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

    /* MBA-943: primary = most devices, lowest contact id to break a tie. */
    SELECT @CustomerId = CustomerId
    FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail)
    WHERE IsPrimary = 1;

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
