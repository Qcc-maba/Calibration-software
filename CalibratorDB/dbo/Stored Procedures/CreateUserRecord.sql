-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 14/04/2025
-- Description:	This SP add user
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-148
-- =============================================
CREATE     PROCEDURE [dbo].[CreateUserRecord]
 @FirstName NVARCHAR(50) = NULL
,@LastName NVARCHAR(50) = NULL
,@Phone NVARCHAR(20) = NULL
,@UserAddress NVARCHAR(200) = NULL
,@Password NVARCHAR(50) = NULL
,@LocationArea NVARCHAR(200) = NULL
,@UserRoleId INT
,@UserStatusId INT
,@Email NVARCHAR(50)
,@DepartmentIdsList NVARCHAR(max) 
,@CertificationIdsList NVARCHAR(max) = NULL
,@LoggedInUserEmail NVARCHAR(50)
,@Stamp NVARCHAR(200) = NULL
,@PositionId INT = NULL

/*
EXEC [dbo].[CreateUserRecord]
 @FirstName = 'test11_1'
,@LastName = 'test1'
,@Phone ='911-911-911'
,@UserAddress ='test address1'
,@Password ='test123'
,@LocationArea ='test area'
,@UserRoleId ='1'
,@UserStatusId = 56
,@Email ='tes2t@test.com12333'
,@DepartmentIdsList = '1,2,3'
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


DECLARE @IsActive BIT 

SELECT @IsActive = IIF(StatusDescriptionENG='Active',1,0)
  FROM [Calibrator].[dbo].[Statuses] as s
WHERE s.StatusId = @UserStatusId

IF @DepartmentIdsList IS NOT NULL
BEGIN
DROP TABLE IF EXISTS #DepartmentIdsList
CREATE TABLE #DepartmentIdsList
(
DepartmentId INT
)

INSERT #DepartmentIdsList(DepartmentId)
SELECT Value FROM dbo.ParseCSVToTable(@DepartmentIdsList)
END

BEGIN TRY

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
			   ,[UpdateUserID]
			   ,[Stamp]
			   ,[UserRoleId]
			   ,[PositionId])
		 VALUES(
			 @FirstName
			,@LastName 
			,@Email 
			,@Password
			,@Phone		
			,@IsActive
			,@UserAddress
			,@LocationArea 
			,@LoggedInUserId
			,@Stamp
			,@UserRoleId
			,@PositionId
			)

	DECLARE @Userid INT

	SELECT @Userid = SCOPE_IDENTITY()

	IF @CertificationIdsList IS NOT NULL
	INSERT [dbo].[CalibratorsToCertification](CertificationId,CalibratorId,UpdateUserID)
	SELECT DISTINCT CertificationId,@Userid,@LoggedInUserId
	FROM #CertificationIds

	INSERT [dbo].[UsersToDepartments](UserId,DepartmentId,UpdateUserID)
	SELECT DISTINCT @Userid, DepartmentId,@LoggedInUserId
	FROM #DepartmentIdsList

	COMMIT
END TRY

BEGIN CATCH
ROLLBACK
END CATCH

END