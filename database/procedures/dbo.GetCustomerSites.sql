-- =============================================
-- Author:      Eduard Kudlaiev
-- Create date: 04/05/2026
-- Description: Sites (sub-sites) of the customer the caller belongs to.
--              Used by the internal customer-management screen AND by the customer
--              portal profile screen.
--
-- 2026-08-30 — FIX: portal users could not resolve.
--
--              Identical defect to GetCustomerContacts: the customer was resolved only
--              through dbo.GetSourceFilterByEmail, a table-valued function over
--              dbo.Users. A portal user lives in dbo.CustomerContacts and has no Users
--              row, so the function returned no rows, @CustomerId stayed NULL, and
--              `WHERE cs.CustomerId = @CustomerId` was always false.
--
--              Now: resolve from dbo.CustomerContacts first, fall back to the function,
--              so the internal screen is unaffected.
--
--              The SELECT list is unchanged; no caller needs to change.
-- JiraLink:
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerSites]
@LoggedInUserEmail NVARCHAR(100)
AS

SET NOCOUNT ON;

DECLARE @CustomerId INT = NULL;

-- Primary resolution: portal contact login
SELECT TOP 1 @CustomerId = cc.CustomerId
FROM dbo.CustomerContacts AS cc
WHERE cc.CustomerContactEmail = @LoggedInUserEmail;

-- Fallback: internal staff account mapped to a customer
IF @CustomerId IS NULL
BEGIN
    SELECT TOP 1 @CustomerId = d.CustomerId
    FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) AS d;
END

SELECT cs.[CustomerId]
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
  WHERE /*cs.[IsDeleted] = 0 AND */cs.CustomerId = @CustomerId
GO
