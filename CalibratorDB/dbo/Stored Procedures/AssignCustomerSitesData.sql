-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 04/05/2026
-- Description:	This SP add/update/remove customer contact for approprite customer site
--              It get appopriate customer site for filtering based on @LoggedInUserEmail
--              if @CustomerSitesIdsToRemove parameter specified - appropriate CustomerSitesId's will be removed
--              if @CustomerSiteId specified appropriate record will be updated with data specified in rest parameters. 
--              to add new record @CustomerSiteId shouldn't be specified
--              business key for a table is a combination of CustomerId and SiteCode
-- JiraLink: 
-- =============================================

CREATE    PROCEDURE [dbo].[AssignCustomerSitesData]
@LoggedInUserEmail NVARCHAR(100),
@CustomerSitesIdsToRemove NVARCHAR(400) = NULL,
@CustomerSiteAddress NVARCHAR(80) = NULL,
@CustomerSiteState NVARCHAR(40) = NULL,
@CustomerSiteZIP NVARCHAR(10) = NULL,
@CustomerSitePhone NVARCHAR(30) = NULL,
@CustomerSiteDescription NVARCHAR(50) = NULL,
@CustomerSiteCode INT=NULL,
@CustomerSiteAddressENG NVARCHAR(80) = NULL,
@CustomerSiteStateENG NVARCHAR(40) = NULL,
@CustomerSiteDescriptionENG NVARCHAR(50) = NULL,
@CustomerSiteId INT = NULL,
@RevertDeletion BIT = NULL

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


IF (@CustomerSiteId IS NULL AND @CustomerSitesIdsToRemove IS NULL 
    AND NOT EXISTS (SELECT 1 FROM [dbo].[CustomerSites] as c WHERE c.CustomerId = @CustomerId AND c.[CustomerSiteCode] = @CustomerSiteCode))

INSERT INTO [dbo].[CustomerSites]
           ([CustomerId]
           ,[CustomerSiteAddress]
           ,[CustomerSiteState]
           ,[CustomerSiteZIP]
           ,[CustomerSitePhone]
           ,[CustomerSiteDescription]
           ,[CustomerSiteCode]
           ,[CreateDate]
           ,[UpdateUserID]
           ,[SourceId]
           ,[CustomerSiteAddressENG]
           ,[CustomerSiteStateENG]
           ,[CustomerSiteDescriptionENG])
VALUES
        (
            @CustomerId
            ,@CustomerSiteAddress
            ,@CustomerSiteState
            ,@CustomerSiteZIP
            ,@CustomerSitePhone
            ,@CustomerSiteDescription
            ,@CustomerSiteCode
            ,GETDATE()
            ,@LoggedInUserId
            ,@SourceId
            ,@CustomerSiteAddressENG
            ,@CustomerSiteStateENG
            ,@CustomerSiteDescriptionENG
        )

-- update data
IF (@CustomerSitesIdsToRemove IS NULL AND @CustomerSiteId IS NOT NULL
    AND EXISTS (SELECT 1 FROM [dbo].[CustomerSites] as c WHERE c.CustomerId = @CustomerId AND c.[CustomerSiteId] = @CustomerSiteId))
UPDATE [dbo].[CustomerSites]
     SET    [CustomerSiteAddress] = COALESCE(@CustomerSiteAddress,[CustomerSiteAddress])
           ,[CustomerSiteState] = COALESCE(@CustomerSiteState,[CustomerSiteState])
           ,[CustomerSiteZIP] = COALESCE(@CustomerSiteZIP,[CustomerSiteZIP])
           ,[CustomerSitePhone] = COALESCE(@CustomerSitePhone,[CustomerSitePhone])
           ,[CustomerSiteDescription] = COALESCE(@CustomerSiteDescription,[CustomerSiteDescription])
           ,[UpdatedDate] = GETDATE()
           ,[UpdateUserID] = @LoggedInUserId
           ,[SourceId] = @SourceId
           ,[CustomerSiteAddressENG] = COALESCE(@CustomerSiteAddressENG,[CustomerSiteAddressENG])
           ,[CustomerSiteStateENG] = COALESCE(@CustomerSiteStateENG,[CustomerSiteStateENG])
           ,[CustomerSiteDescriptionENG] = COALESCE(@CustomerSiteDescriptionENG,[CustomerSiteDescriptionENG])
           ,[IsDeleted] = IIF(@RevertDeletion = 1,0,[IsDeleted])
WHERE [CustomerId] = @CustomerId AND [CustomerSiteId] = @CustomerSiteId

-- delete data
IF (@CustomerSitesIdsToRemove IS NOT NULL)
UPDATE c
SET
     [UpdatedDate] = GETDATE()
    ,[UpdateUserID] = COALESCE(@LoggedInUserId,[UpdateUserID])
    ,[IsDeleted] = 1
FROM [dbo].[CustomerSites] as c
JOIN STRING_SPLIT(@CustomerSitesIdsToRemove,',') as d ON c.CustomerSiteId = d.value