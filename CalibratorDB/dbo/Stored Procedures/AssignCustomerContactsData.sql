-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 04/05/2026
-- Description:	This SP add/update/remove customer contact for approprite customer
--              It get appopriate customer for filtering based on @LoggedInUserEmail
--              if @CustomerContactsIdsToRemove parameter specified - appropriate CustomerContactId's will be removed
--              if @CustomerContactsId specified appropriate record will be updated with data specified in rest parameters. 
--              to add new record @CustomerContactsId shouldn't be specified
-- JiraLink: 
-- =============================================

CREATE    PROCEDURE [dbo].[AssignCustomerContactsData]
@LoggedInUserEmail NVARCHAR(100),
@CustomerContactsIdsToRemove NVARCHAR(400) = NULL,
@CustomerContactsId INT = NULL,
@CustomerContactName NVARCHAR(50)= NULL,
@CustomerContactPersonRole NVARCHAR(50)= NULL,
@CustomerContactPhone NVARCHAR(50)= NULL,
@CustomerContactAdditionalPhoneNumber NVARCHAR(50)= NULL,
@CustomerContactEmail NVARCHAR(50)= NULL,
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


--Check that user don't exist and insert new one
IF (@CustomerContactsId IS NULL AND @CustomerContactsIdsToRemove IS NULL 
    AND NOT EXISTS (SELECT 1 FROM [dbo].[CustomerContacts] as c WHERE c.CustomerId = @CustomerId AND c.[CustomerContactEmail] = @CustomerContactEmail))
INSERT INTO [dbo].[CustomerContacts]
           ([CustomerId]
           ,[CustomerContactName]
           ,[CustomerContactPersonRole]
           ,[CustomerContactPhone]
           ,[CustomerContactAdditionalPhoneNumber]
           ,[CustomerContactEmail]
           ,[SourceId]
           ,[CreateDate]
           ,[UpdateUserID]
           ,[IsDeleted]
           ,[CustomerSiteId])
     VALUES
           (
            @CustomerId
           ,@CustomerContactName
           ,@CustomerContactPersonRole
           ,@CustomerContactPhone
           ,@CustomerContactAdditionalPhoneNumber
           ,@CustomerContactEmail
           ,@SourceId
           ,GETDATE()
           ,@LoggedInUserId
           ,0
           ,@CustomerSiteId
           )
-- If @CustomerContactsId exists update data
IF (@CustomerContactsIdsToRemove IS NULL 
    AND EXISTS (SELECT 1 FROM [dbo].[CustomerContacts] as c WHERE c.CustomerId = @CustomerId AND c.CustomerContactId = @CustomerContactsId))
UPDATE [dbo].[CustomerContacts]
     SET [CustomerContactName] = COALESCE(@CustomerContactName,[CustomerContactName])
    ,[CustomerContactPersonRole] = COALESCE(@CustomerContactPersonRole,[CustomerContactPersonRole])
    ,[CustomerContactPhone] = COALESCE(@CustomerContactPhone,[CustomerContactPhone])
    ,[CustomerContactAdditionalPhoneNumber] = COALESCE(@CustomerContactAdditionalPhoneNumber,[CustomerContactAdditionalPhoneNumber])
    ,[CustomerContactEmail] = COALESCE(@CustomerContactEmail,[CustomerContactEmail])
    ,[SourceId] = COALESCE(@SourceId,[SourceId])
    ,[UpdatedDate] = GETDATE()
    ,[UpdateUserID] = COALESCE(@LoggedInUserId,[UpdateUserID])
    ,[CustomerSiteId] = COALESCE(@CustomerSiteId,[CustomerSiteId])
    ,[IsDeleted] = IIF(@RevertDeletion = 1,0,[IsDeleted])
WHERE CustomerId = @CustomerId AND CustomerContactId = @CustomerContactsId

-- If @@CustomerContactsIdsToRemove exists delete data
IF (@CustomerContactsIdsToRemove IS NOT NULL)
UPDATE c
SET
     [UpdatedDate] = GETDATE()
    ,[UpdateUserID] = COALESCE(@LoggedInUserId,[UpdateUserID])
    ,[IsDeleted] = 1
FROM [dbo].[CustomerContacts] as c
JOIN STRING_SPLIT(@CustomerContactsIdsToRemove,',') as d ON c.CustomerContactId = d.value