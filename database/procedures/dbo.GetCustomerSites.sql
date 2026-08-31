SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Author:      Eduard Kudlaiev
-- Create date: 04/05/2026
-- Description: Sites (sub-sites) of the customer(s) the caller belongs to.
--              Used by the internal customer-management screen AND by the customer
--              portal profile screen.
--
-- 2026-08-30 - FIX: portal users could not resolve.
--
--              Identical defect to GetCustomerContacts: the customer was resolved only
--              through dbo.GetSourceFilterByEmail, a table-valued function over
--              dbo.Users. A portal user lives in dbo.CustomerContacts and has no Users
--              row, so the function returned no rows, @CustomerId stayed NULL, and
--              `WHERE cs.CustomerId = @CustomerId` was always false.
--
-- 2026-08-31 - MBA-943: a portal caller is a SET of customers, not one.
--
--              Worth knowing while reading this: what the business calls a "site" is usually
--              NOT a row in this table. dbo.CustomerSites is empty for every ישקר division -
--              Priority models each division as its own Customers row. So a manager's several
--              locations arrive through the union below, not through this table.
--
--              The portal path is now a union over dbo.GetPortalCustomerIds. THE STAFF PATH IS
--              UNCHANGED: dbo.GetSourceFilterByEmail is consulted only when the caller is not a
--              portal contact, so the internal screen behaves exactly as before.
--
--              @SelectedCustomerId is gone; MBA-936 added it for a branch picker we decided not
--              to build.
--
-- NEW COLUMN:  CustomerName - which company each site belongs to. Front end: MBA-942.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerSites]
    @LoggedInUserEmail NVARCHAR(100)
AS

SET NOCOUNT ON;

DECLARE @StaffCustomerId INT = NULL;

IF NOT EXISTS (SELECT 1 FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail))
BEGIN
    SELECT TOP 1 @StaffCustomerId = d.CustomerId
    FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) AS d;
END

SELECT cs.[CustomerId]
      ,cust.[CustomerName]
      ,cs.[CustomerSiteId]
      ,cs.[CustomerSiteAddress]
      ,cs.[CustomerSiteState]
      ,cs.[CustomerSiteZIP]
      ,cs.[CustomerSitePhone]
      ,cs.[CustomerSiteDescription]
      ,cs.[CustomerSiteCode]
      ,cs.[CreateDate]
      ,cs.[UpdatedDate]
      ,cs.[UpdateUserID]
      ,cs.[SourceId]
      ,s.[SourceDisplayName] AS [SourceName]
      ,cs.[CustomerSiteAddressENG]
      ,cs.[CustomerSiteStateENG]
      ,cs.[CustomerSiteDescriptionENG]
      ,cs.[IsDeleted]
  FROM [dbo].[CustomerSites] as cs
  LEFT JOIN [dbo].[Source] as s ON cs.[SourceId] = s.[SourceId]
  LEFT JOIN [dbo].[Customers] as cust ON cust.[CustomerId] = cs.[CustomerId]
  WHERE /*cs.[IsDeleted] = 0 AND */
        (cs.CustomerId IN (SELECT CustomerId FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail))
         OR cs.CustomerId = @StaffCustomerId)
  ORDER BY cust.[CustomerName], cs.[CustomerSiteDescription];
GO
