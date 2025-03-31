-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 27/03/2025
-- Description:	Get all users that belongs for specific role
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE dbo.GetUsersByRole
@UserRoleName NVARCHAR(255)

/*
EXEC dbo.GetUsersByRole @UserRoleName = N'CarOwner'
*/

AS
BEGIN

If NOT EXISTS (SELECT 1 FROM [dbo].[UserRoles] as ur
				WHERE ur.UserRoleName = @UserRoleName)
THROW 51000, 'Incorrect user role provided.', 1;

SELECT 
	u.ID	
	,CONCAT(u.FirstName, ' ', u.LastName) as UserFullName
	,CONCAT(u.FirstNameEng, ' ', u.LastNameEng) as UserFullNameEng
FROM [dbo].[Users] as u
JOIN [dbo].[UsersToUserRoles] as rel ON u.ID = rel.UserId
JOIN [dbo].[UserRoles] as ur ON rel.UserRoleId = ur.UserRoleId
WHERE ur.UserRoleName = @UserRoleName
END