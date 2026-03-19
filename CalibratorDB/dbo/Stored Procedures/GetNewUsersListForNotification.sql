-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 19/03/2026
-- Description:	List of users recently created for notification about access to the platform
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[GetNewUsersListForNotification]
@ResendNotificationDays TINYINT
AS
BEGIN
    
    DECLARE @dt DATETIME2(0) = GETDATE()

    SELECT 
           u.[ID]
          ,u.[FirstName]
          ,u.[LastName]
          ,u.[FirstNameEng]
          ,u.[LastNameEng]
          ,u.[Email]
          ,u.[IsActive]
          ,u.[UserRoleId]
          ,ur.[UserRoleDescriptionENG]
          ,u.[LastLoginDate]
          ,u.[WelcomeEmailSentDate]
      FROM [dbo].[Users] as u
      JOIN [dbo].[UserRoles] as ur on u.[UserRoleId] = ur.[UserRoleId]
      WHERE u.[WelcomeEmailSentDate] IS NULL OR DATEDIFF(DAY,u.[WelcomeEmailSentDate],@dt) >= @ResendNotificationDays
END