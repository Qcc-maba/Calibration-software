-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 04/05/2026
-- Description:	This SP get data about customers sites. 
--              It get appopriate customer for filtering based on @LoggedInUserEmail
-- JiraLink: 
-- =============================================

CREATE    PROCEDURE [dbo].[GetCustomerSites] 
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
      ,s.[SourceName]
      ,cs.[CustomerSiteAddressENG]
      ,cs.[CustomerSiteStateENG]
      ,cs.[CustomerSiteDescriptionENG]
	  ,cs.[IsDeleted]
  FROM [dbo].[CustomerSites] as cs
  LEFT JOIN [dbo].[Source] as s ON cs.[SourceId] = s.[SourceId]
  WHERE /*cs.[IsDeleted] = 0 AND */cs.CustomerId = @CustomerId