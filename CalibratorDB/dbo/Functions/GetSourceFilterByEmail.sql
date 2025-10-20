-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 20/10/2025
-- Description:	GetUser info based on email
-- JiraLink: 
-- =============================================

CREATE   FUNCTION dbo.GetSourceFilterByEmail(@LoggedInUserEmail NVARCHAR(50))
RETURNS TABLE
AS
RETURN
(
SELECT 
	u.ID as UserId,
	CASE ur.UserRoleName 
		WHEN N'SuperAdmin' THEN NULL
		ELSE s.SourceId
	END AS SourceId
FROM [dbo].[Users] as u
LEFT JOIN [dbo].[UserRoles] ur ON u.[UserRoleId] = ur.[UserRoleId]
LEFT JOIN [dbo].[Source] as s ON u.SourceId = s.SourceId
WHERE u.Email = @LoggedInUserEmail
)