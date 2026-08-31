SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Author:      Eduard Kudlaiev
-- Create date: 04/05/2026
-- Description: Contacts of the customer(s) the caller belongs to.
--              Used by the internal customer-management screen AND by the customer
--              portal profile screen.
--
-- 2026-08-30 - FIX: portal users could not resolve.
--
--              The customer was resolved only through dbo.GetSourceFilterByEmail, which
--              is a table-valued function over dbo.Users - internal staff accounts. A
--              portal user is a row in dbo.CustomerContacts and has no Users row, so the
--              function returned NO ROWS, @CustomerId stayed NULL, and the final
--              predicate `WHERE c.CustomerId = @CustomerId` was always false. The screen
--              showed nothing, which is why the front end was left on mock data.
--
-- 2026-08-31 - MBA-943: a portal caller is a SET of customers, not one.
--
--              3,684 addresses are a contact of more than one customer. A manager over
--              three ישקר divisions has contacts in all three; showing only the division
--              with the lowest CustomerContactId hid the rest for no reason.
--
--              The portal path is now a union over dbo.GetPortalCustomerIds. THE STAFF PATH
--              IS UNCHANGED: an internal user is still resolved to exactly one customer
--              through dbo.GetSourceFilterByEmail, and that lookup only runs when the caller
--              is not a portal contact at all. The internal screen therefore behaves exactly
--              as before.
--
--              @SelectedCustomerId is gone; MBA-936 added it for a branch picker we decided
--              not to build.
--
-- NEW COLUMN:  CustomerName - which company each contact belongs to. Without it, a union of
--              three divisions' contacts is an unlabelled list. Front end: MBA-942.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerContacts]
    @LoggedInUserEmail NVARCHAR(100)
AS

SET NOCOUNT ON;

/* Staff fallback: only consulted when the caller is not a portal contact, so a portal caller
   can never pick up a staff mapping and vice versa. */
DECLARE @StaffCustomerId INT = NULL;

IF NOT EXISTS (SELECT 1 FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail))
BEGIN
    SELECT TOP 1 @StaffCustomerId = d.CustomerId
    FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) AS d;
END

SELECT c.[CustomerContactId]
      ,c.[CustomerId]
      ,cust.[CustomerName]
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
  LEFT JOIN [dbo].[Customers] as cust ON cust.[CustomerId] = c.[CustomerId]
  WHERE /*c.[IsDeleted] = 0 AND*/
        (c.CustomerId IN (SELECT CustomerId FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail))
         OR c.CustomerId = @StaffCustomerId)
  ORDER BY cust.[CustomerName], c.[CustomerContactName];
GO
