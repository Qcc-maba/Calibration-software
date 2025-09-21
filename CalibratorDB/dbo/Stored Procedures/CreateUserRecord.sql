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
,@DepartmentIdsList NVARCHAR(max) = NULL -- mapped to MainCategories
--,@CertificationIdsList NVARCHAR(max) = NULL
,@LoggedInUserEmail NVARCHAR(50)
,@Stamp NVARCHAR(200) = NULL
,@PositionId INT = NULL
,@CertificationAuthoritiesIdsList NVARCHAR(max) = NULL 

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
,@DepartmentIdsList = '1,4,3'
,@CertificationAuthoritiesIdsList ='1,2,3'
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

IF @CertificationAuthoritiesIdsList IS NOT NULL
BEGIN
DROP TABLE IF EXISTS #CertificationAuthoritiesIdsList
CREATE TABLE #CertificationAuthoritiesIdsList
(
CalibratorCertificationAuthorityId INT
)

INSERT #CertificationAuthoritiesIdsList(CalibratorCertificationAuthorityId)
SELECT Value FROM dbo.ParseCSVToTable(@CertificationAuthoritiesIdsList)
END


DECLARE @IsActive BIT 

SELECT @IsActive = IIF(StatusDescriptionENG='Active',1,0)
  FROM [Calibrator].[dbo].[Statuses] as s
WHERE s.StatusId = @UserStatusId

DROP TABLE IF EXISTS #DepartmentIdsList
CREATE TABLE #DepartmentIdsList
(
DepartmentId INT
)

IF @DepartmentIdsList IS NOT NULL
BEGIN
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

	IF @CertificationAuthoritiesIdsList IS NOT NULL
	INSERT [dbo].[CalibratorsToCertificationAuthoritiesAuthorities](CalibratorCertificationAuthorityId,CalibratorId,UpdateUserID)
	SELECT DISTINCT CalibratorCertificationAuthorityId,@Userid,@LoggedInUserId
	FROM #CertificationAuthoritiesIdsList

	INSERT [dbo].[UsersToDepartments](UserId,[MainCategoryId],UpdateUserID)
	SELECT DISTINCT @Userid, DepartmentId,@LoggedInUserId
	FROM #DepartmentIdsList

	COMMIT
END TRY

BEGIN CATCH
SELECT ERROR_MESSAGE() as error
ROLLBACK
END CATCH

END