SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Author:      Claude (subagent)
-- Create date: 04/08/2026
-- Description: Returns the customer profile / main-site header for the
--              logged-in customer user (screen: customer/profile, MBA-612).
--              Returns a SINGLE header row. The sub-sites list and the MABA
--              contact cards on the same screen are served by the existing
--              GetCustomerSites / GetCustomerContacts / GetCustomerSupportData SPs
--              and are intentionally NOT duplicated here.
--
-- 2026-08-31 - MBA-943: which customer, when the address serves several.
--
--              This screen describes ONE company - name, address, phone, shipping - so it
--              cannot be a union without breaking its contract with the front end, which maps
--              a single row. It now returns the caller's PRIMARY customer (the one holding the
--              most devices) instead of the one with the lowest CustomerContactId. For
--              davide@iscar.co.il that moves the profile from ישקר בע"מ, which holds none of
--              his work, to ישקר-מתק"ש-תפן, which holds most of it.
--
--              Note the asymmetry, and that it is deliberate: the profile header names one
--              company while GetCustomerSites and GetCustomerContacts beneath it now list all
--              of them. If that reads as confusing on screen, the fix belongs in the front end
--              (label the header, or let the user switch) rather than here - see MBA-942.
--
--              @SelectedCustomerId is gone; MBA-936 added it for a branch picker we decided
--              not to build.
-- JiraLink:    MBA-612
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerProfile]
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
        -- MBA-943: how many company records this caller covers in total. 1 for almost everyone;
        -- above 1 tells the front end the header names only one of several.
        ,(SELECT COUNT(*) FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail))
                                                                   AS RelatedCompaniesCount
    FROM dbo.Customers AS c
    WHERE c.CustomerId = @CustomerId
      AND c.IsDeleted = 0;
END
GO
