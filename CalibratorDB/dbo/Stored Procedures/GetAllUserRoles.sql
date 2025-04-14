-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 14/04/2025
-- Description:	This SP return all user roles
-- JiraLink:
-- =============================================
CREATE     PROCEDURE [dbo].[GetAllUserRoles]
AS
SELECT [UserRoleId]
      ,[UserRoleDescriptionENG]
      ,[UserRoleDescriptionHEB]
      ,[UserRoleName]
      ,[IsApplicationRole]
  FROM [dbo].[UserRoles]