-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 20/10/2025
-- Description:	GetUser info based on email
-- JiraLink: 
-- =============================================

CREATE   FUNCTION [dbo].[GetSourceFilterByEmail](@LoggedInUserEmail NVARCHAR(50))
RETURNS TABLE
AS
RETURN
(
SELECT 
	u.ID as UserId,
	CASE 
		WHEN ur.UserRoleName = N'SuperAdmin' THEN NULL
		WHEN u.Email like N'sinova%' THEN 1
		ELSE COALESCE(s.SourceId,s1.SourceId)
	END AS SourceId
FROM [dbo].[Users] as u
LEFT JOIN [dbo].[UserRoles] ur ON u.[UserRoleId] = ur.[UserRoleId]
LEFT JOIN [dbo].[Source] as s ON u.SourceId = s.SourceId
LEFT JOIN [dbo].[Source] as s1 ON STUFF(u.Email,1,CHARINDEX('@',u.Email),'') = s1.EmailDomain
WHERE u.Email = @LoggedInUserEmail
)