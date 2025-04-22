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
,@UserStatusId INT
,@Email nvarchar(50)
,@DepartmentId int 
,@CertificationIdsList nvarchar(max)
,@LoggedInUserEmail nvarchar(50)
,@Stamp NVARCHAR(30)

/*
EXEC [dbo].[CreateUserRecord]
 @FirstName = 'test111'
,@LastName = 'test1'
,@Phone ='911-911-911'
,@UserAddress ='test address'
,@Password ='test123'
,@LocationArea ='test area'
,@UserRoleIdsList ='1,2,3'
,@UserStatusId = 56
,@Email ='tes2t@test.com12'
,@DepartmentId = 1
,@CertificationIdsList ='1,2,3'
,@LoggedInUserEmail = 'sinova_super_admin@gmail.com'
,@Stamp =''
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

DECLARE @IsActive BIT 

SELECT @IsActive = IIF(StatusDescriptionENG='Active',1,0)
  FROM [Calibrator].[dbo].[Statuses] as s
WHERE s.StatusId = @UserStatusId

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
		   ,[UpdateUserID]
		   ,[Stamp])
     VALUES(
         @FirstName
		,@LastName 
		,@Email 
		,@Password
		,@Phone		
		,@IsActive
		,@UserAddress
		,@LocationArea 
		,@DepartmentId 
		,@LoggedInUserId
		,@Stamp
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