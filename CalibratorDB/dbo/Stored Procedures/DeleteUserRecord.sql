-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 16/04/2025
-- Description:	This SP should delete user record
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[DeleteUserRecord]
@UserIDs NVARCHAR(MAX),
@LoggedInUserEmail NVARCHAR(50)

/*
EXEC [dbo].[DeleteUserRecord] 
@UserIDs = '0,1,2',
@LoggedInUserEmail = 'sinova_super_admin@gmail.com'
*/

AS
BEGIN

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT = (SELECT ID FROM [dbo].[Users] WHERE Email = @LoggedInUserEmail) 

DROP TABLE IF EXISTS #UserIDs
CREATE TABLE #UserIDs
(
UserId INT PRIMARY KEY
)

INSERT #UserIDs(UserId)
SELECT Value FROM dbo.ParseCSVToTable(@UserIDs)


UPDATE u 
SET u.UpdatedDate = GETDATE(), u.IsActive = 0, UpdateUserID = @LoggedInUserId
FROM dbo.Users as u
JOIN #UserIDs as d ON u.ID = d.UserId


END