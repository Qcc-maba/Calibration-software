-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 14/04/2025
-- Description:	This SP add user
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-148
-- =============================================
CREATE     PROCEDURE [dbo].[CreateUserRecord]
 @FirstName nvarchar(50) = NULL
,@LastName nvarchar(50) = NULL
,@Phone nvarchar(20) = NULL
,@UserAddress nvarchar(200) = NULL
,@Password nvarchar(50) = NULL
,@LocationArea nvarchar(200) = NULL
,@UserRoleIdsList nvarchar(200) 
--,@UserStatus INT will be defined
,@Email nvarchar(50)
,@DepartmentId int 
,@CertificationIdsList nvarchar(max)
,@LoggedInUserEmail nvarchar(50)

/*
EXEC [dbo].[CreateUserRecord]
 @FirstName = 'test1'
,@LastName = 'test1'
,@Phone ='911-911-911'
,@UserAddress ='test address'
,@Password ='test123'
,@LocationArea ='test area'
,@UserRoleIdsList ='1,2,3'
,@Email ='tes2t@test.com'
,@DepartmentId = 1
,@CertificationIdsList ='1,2,3'
,@LoggedInUserEmail = 'sinova_super_admin@gmail.com'
*/

AS
BEGIN

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT = (SELECT ID FROM [dbo].[Users] WHERE Email = @LoggedInUserEmail) 

if EXISTS (
SELECT 1 FROM [dbo].[Users] as u
WHERE u.Email = @Email
)
THROW 51000, 'User already exists.', 1;

IF @CertificationIdsList IS NOT NULL
BEGIN
DROP TABLE IF EXISTS #CertificationIds
CREATE TABLE #CertificationIds
(
CertificationId INT
)

INSERT #CertificationIds(CertificationId)
SELECT Value FROM dbo.ParseCSVToTable(@CertificationIdsList)
END

IF @UserRoleIdsList IS NOT NULL
BEGIN
DROP TABLE IF EXISTS #UserRoles
CREATE TABLE #UserRoles
(
UserRoleId INT
)

INSERT #UserRoles(UserRoleId)
SELECT Value FROM dbo.ParseCSVToTable(@UserRoleIdsList)
END

BEGIN TRAN

INSERT INTO [dbo].[Users]
           ([FirstName]
           ,[LastName]
           ,[Email]
           ,[Password]
           ,[Phone]
           ,[IsActive]
           ,[UserAddress]
           ,[LocationArea]
           ,[DepartmentId]
		   ,[UpdateUserID])
     VALUES(
         @FirstName
		,@LastName 
		,@Email 
		,@Password
		,@Phone		
		,1
		,@UserAddress
		,@LocationArea 
		,@DepartmentId 
		,@LoggedInUserId
		)

DECLARE @Userid INT

SELECT @Userid = SCOPE_IDENTITY()

INSERT [dbo].[UsersToUserRoles](UserId,UserRoleId,UpdateUserID)
SELECT @Userid, UserRoleId,@LoggedInUserId
FROM #UserRoles

INSERT [dbo].[CalibratorsToCertification](CertificationId,CalibratorId,UpdateUserID)
SELECT CertificationId,@Userid,@LoggedInUserId
FROM #CertificationIds

COMMIT


END