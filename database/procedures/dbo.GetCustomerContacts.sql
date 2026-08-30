-- =============================================
-- Author:      Eduard Kudlaiev
-- Create date: 04/05/2026
-- Description: Contacts of the customer the caller belongs to.
--              Used by the internal customer-management screen AND by the customer
--              portal profile screen.
--
-- 2026-08-30 — FIX: portal users could not resolve.
--
--              The customer was resolved only through dbo.GetSourceFilterByEmail, which
--              is a table-valued function over dbo.Users — internal staff accounts. A
--              portal user is a row in dbo.CustomerContacts and has no Users row, so the
--              function returned NO ROWS, @CustomerId stayed NULL, and the final
--              predicate `WHERE c.CustomerId = @CustomerId` was always false. The screen
--              showed nothing, which is why the front end was left on mock data.
--
--              Now: resolve from dbo.CustomerContacts first, fall back to the function.
--              Order matters — the portal case is checked first, and the staff path is
--              untouched, so the internal screen behaves exactly as before.
--
--              Same defect and same fix as GetCustomerSupportData (2026-08-30).
--              The SELECT list is unchanged; no caller needs to change.
-- JiraLink:
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerContacts]
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
GO
