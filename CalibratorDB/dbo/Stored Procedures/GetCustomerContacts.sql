-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 04/05/2026
-- Description:	This SP get data about customers contacts based 
--              It get appopriate customer for filtering based on @LoggedInUserEmail
-- JiraLink: 
-- =============================================

CREATE    PROCEDURE [dbo].[GetCustomerContacts] 
@LoggedInUserEmail NVARCHAR(100)
AS

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT
DECLARE @CustomerId INT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
,@CustomerId = d.CustomerId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

SELECT c.[CustomerContactId]
      ,c.[CustomerId]
      ,c.[CustomerContactName]
      ,c.[CustomerContactPersonRole]
      ,c.[CustomerContactPhone]
      ,c.[CustomerContactAdditionalPhoneNumber]
      ,c.[CustomerContactEmail]
      ,c.[SourceId]
      ,s.[SourceName]
      ,c.[CustomerSiteId]
	  ,c.[IsDeleted]
  FROM [dbo].[CustomerContacts] as c
  LEFT JOIN [dbo].[Source] as s ON c.[SourceId] = s.[SourceId]
  WHERE /*c.[IsDeleted] = 0 AND*/ c.CustomerId = @CustomerId