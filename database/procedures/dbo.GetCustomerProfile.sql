/*
    dbo.GetCustomerProfile                                        MBA-936
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
-- Author:      Claude (subagent)
-- Create date: 04/08/2026
-- Description: Returns the customer profile / main-site header for the
--              logged-in customer user (screen: customer/profile, MBA-612).
--              Customer-scoped: @CustomerId is resolved from dbo.CustomerContacts
--              by @LoggedInUserEmail (same convention as GetCustomerDashboardData),
--              with a fallback to dbo.Users so support/portal logins also resolve.
--              Returns a single header row. The sub-sites list and the MABA
--              contact cards on the same screen are served by the existing
--              GetCustomerSites / GetCustomerContacts / GetCustomerSupportData SPs
--              and are intentionally NOT duplicated here.
-- JiraLink:    MBA-612
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerProfile]
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

    SELECT
         c.CustomerId
        ,c.CustomerCode                                              AS SiteNumber
        ,c.CustomerName                                             AS MainSiteName
        ,c.CustomerNameENG                                          AS MainSiteNameENG
        ,c.CustomerName                                             AS AccountName
        ,c.CustomerNameENG                                          AS AccountNameENG
        -- No dedicated report-language column exists; report output preference
        -- is currently a UI toggle. Returned NULL so FE can default to 'he'.
        ,CAST(NULL AS NVARCHAR(2))                                  AS ReportLanguage
        ,LTRIM(RTRIM(
            CONCAT(
                c.CustomerAddress,
                CASE WHEN NULLIF(LTRIM(RTRIM(c.CustomerCity)), '') IS NOT NULL
                     THEN N', ' + c.CustomerCity ELSE N'' END
            )))                                                    AS SiteAddress
        ,LTRIM(RTRIM(
            CONCAT(
                c.CustomerAddressENG,
                CASE WHEN NULLIF(LTRIM(RTRIM(c.CustomerCityENG)), '') IS NOT NULL
                     THEN N', ' + c.CustomerCityENG ELSE N'' END
            )))                                                    AS SiteAddressENG
        ,c.CustomerPhone                                           AS SitePhone
        ,c.ReportRequired                                          AS ReportRequired
        ,c.ShipTypeDescr                                           AS ShippingMethod
        ,c.SignatureAmount                                         AS SignatureAmount
        -- Count of sub-sites so FE can show/toggle "all sites"; the list itself
        -- comes from GetCustomerSites.
        ,(SELECT COUNT(*) FROM dbo.CustomerSites AS s
          WHERE s.CustomerId = c.CustomerId AND s.IsDeleted = 0)   AS SubSitesCount
    FROM dbo.Customers AS c
    WHERE c.CustomerId = @CustomerId
      AND c.IsDeleted = 0;
END
