/*
    dbo.GetCustomerContacts                                        MBA-936
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
-- Create date: 04/05/2026
-- Description: Contacts of the customer the caller belongs to.
--              Used by the internal customer-management screen AND by the customer
--              portal profile screen.
--
-- 2026-08-30 ג€” FIX: portal users could not resolve.
--
--              The customer was resolved only through dbo.GetSourceFilterByEmail, which
--              is a table-valued function over dbo.Users ג€” internal staff accounts. A
--              portal user is a row in dbo.CustomerContacts and has no Users row, so the
--              function returned NO ROWS, @CustomerId stayed NULL, and the final
--              predicate `WHERE c.CustomerId = @CustomerId` was always false. The screen
--              showed nothing, which is why the front end was left on mock data.
--
--              Now: resolve from dbo.CustomerContacts first, fall back to the function.
--              Order matters ג€” the portal case is checked first, and the staff path is
--              untouched, so the internal screen behaves exactly as before.
--
--              Same defect and same fix as GetCustomerSupportData (2026-08-30).
--              The SELECT list is unchanged; no caller needs to change.
-- JiraLink:
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerContacts]
@LoggedInUserEmail NVARCHAR(100),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS

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

-- Fallback: internal staff account mapped to a customer
IF @CustomerId IS NULL
BEGIN
    SELECT TOP 1 @CustomerId = d.CustomerId
    FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) AS d;
END

SELECT c.[CustomerContactId]
      ,c.[CustomerId]
      ,c.[CustomerContactName]
      ,c.[CustomerContactPersonRole]
      ,c.[CustomerContactPhone]
      ,c.[CustomerContactAdditionalPhoneNumber]
      ,c.[CustomerContactEmail]
      ,c.[SourceId]
      ,s.[SourceDisplayName] AS [SourceName]
      ,c.[CustomerSiteId]
      ,c.[IsDeleted]
  FROM [dbo].[CustomerContacts] as c
  LEFT JOIN [dbo].[Source] as s ON c.[SourceId] = s.[SourceId]
  WHERE /*c.[IsDeleted] = 0 AND*/ c.CustomerId = @CustomerId
