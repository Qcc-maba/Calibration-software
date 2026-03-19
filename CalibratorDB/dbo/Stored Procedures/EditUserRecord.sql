-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 15/04/2025
-- Description:	This SP edit user data
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-148
-- =============================================
CREATE     PROCEDURE [dbo].[EditUserRecord]
 @FirstName NVARCHAR(50) = NULL
,@LastName NVARCHAR(50) = NULL
,@Phone NVARCHAR(20) = NULL
,@UserAddress NVARCHAR(200) = NULL
,@Password NVARCHAR(50) = NULL
,@LocationArea NVARCHAR(200) = NULL
,@UserRoleId int = NULL
,@UserStatusId INT = NULL
,@Email NVARCHAR(50) = NULL
,@DepartmentIdsList NVARCHAR(max) = NULL -- mapped to main category
--,@CertificationIdsList NVARCHAR(max) = NULL
,@LoggedInUserEmail NVARCHAR(50)
,@UserId INT
,@Stamp NVARCHAR(200) = NULL
,@PositionId INT = NULL
,@CertificationAuthoritiesIdsList NVARCHAR(max) = NULL 
,@WelcomeEmailSentDate DATETIME2(0)
/*
EXEC [dbo].[EditUserRecord]
 @FirstName = 'test1'
,@LastName = 'test1'
,@Phone ='911-911-911'
,@UserAddress ='test address'
,@Password ='test123'
,@LocationArea ='test area'
,@UserRoleId =1
,@Email ='tes2t@test.com1234'
,@UserStatusId = 55
,@DepartmentIdsList = '1'
,@CertificationAuthoritiesIdsList ='1,2,3'
,@LoggedInUserEmail = 'sinova_super_admin@gmail.com'
,@UserId =18
*/

AS
BEGIN

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

IF NOT EXISTS (
SELECT 1 FROM [dbo].[Users] as u
WHERE u.ID = @UserId
)
THROW 51000, 'User not exists.', 1;

DROP TABLE IF EXISTS #CertificationAuthoritiesIdsList
CREATE TABLE #CertificationAuthoritiesIdsList
(
CertificationAuthorityId INT
)

IF @CertificationAuthoritiesIdsList IS NOT NULL
INSERT #CertificationAuthoritiesIdsList(CertificationAuthorityId)
SELECT Value FROM dbo.ParseCSVToTable(@CertificationAuthoritiesIdsList)

DROP TABLE IF EXISTS #UserRoles
CREATE TABLE #UserRoles
(
UserRoleId INT
)


DECLARE @IsActive BIT = 1

SELECT @IsActive = IIF(StatusDescriptionENG='Active',1,0)
  FROM [dbo].[Statuses] as s
WHERE s.StatusId = @UserStatusId

DROP TABLE IF EXISTS #DepartmentIdsList
CREATE TABLE #DepartmentIdsList
(
DepartmentId INT
)

IF @DepartmentIdsList IS NOT NULL
INSERT #DepartmentIdsList(DepartmentId)
SELECT Value FROM dbo.ParseCSVToTable(@DepartmentIdsList)

BEGIN TRY

	BEGIN TRAN

	UPDATE u
	   SET u.[FirstName] = COALESCE(@FirstName,u.[FirstName])
		  ,u.[LastName] = COALESCE(@LastName,u.[LastName])
		  ,u.[Email] = COALESCE(@Email,u.[Email])
		  ,u.[Password] = COALESCE(@Password,u.[Password])
		  ,u.[Phone] = COALESCE(@Phone,u.[Phone])
		  ,u.[IsActive] = COALESCE(@IsActive,u.[IsActive])
		  ,u.[UpdatedDate] = GETDATE()
		  ,u.[UpdateUserID] = @LoggedInUserId
		  ,u.[UserAddress] = COALESCE(@UserAddress,u.[UserAddress])
		  ,u.[LocationArea] = COALESCE(@LocationArea,u.[LocationArea])
		  ,u.[Stamp] = COALESCE(@Stamp,u.[Stamp])
		  ,u.[UserRoleId] = COALESCE(@UserRoleId,u.[UserRoleId])
		  ,u.[PositionId] = COALESCE(@PositionId,u.[PositionId])
		  ,u.[WelcomeEmailSentDate] = COALESCE(@WelcomeEmailSentDate, u.[WelcomeEmailSentDate])
	FROM [dbo].[Users] as u
	WHERE u.ID = @UserId

	IF @DepartmentIdsList IS NOT NULL
	BEGIN
		UPDATE ud
		SET IsDeleted = 1,UpdateUserID = @LoggedInUserId
		FROM [dbo].[UsersToDepartments] as ud
		LEFT JOIN #DepartmentIdsList as di ON ud.UserId = @UserId and di.DepartmentId = ud.MainCategoryId
		WHERE ud.UserId = @UserId  AND di.DepartmentId IS NULL

		INSERT [dbo].[UsersToDepartments](UserId,MainCategoryId,UpdateUserID)
		SELECT @UserId,di.DepartmentId, @LoggedInUserId
		FROM #DepartmentIdsList as di
		LEFT JOIN [dbo].[UsersToDepartments] as ud ON ud.UserId = @UserId and di.DepartmentId = ud.MainCategoryId AND ud.IsDeleted = 0
		WHERE ud.MainCategoryId IS NULL
	END
	ELSE 
		UPDATE ud
		SET IsDeleted = 1,UpdateUserID = @LoggedInUserId
		FROM [dbo].[UsersToDepartments] as ud
		WHERE ud.UserId = @UserId 

	IF @CertificationAuthoritiesIdsList IS NOT NULL
	BEGIN
	UPDATE ctc
	SET IsDeleted = 1,UpdateUserID = @LoggedInUserId, UpdatedDate = GETDATE()
	FROM [dbo].[CalibratorsToCertificationAuthoritiesAuthorities] as ctc
	LEFT JOIN #CertificationAuthoritiesIdsList as ci ON ctc.CalibratorId = @UserId and ci.CertificationAuthorityId = ctc.CalibratorCertificationAuthorityId 
	WHERE ctc.CalibratorId = @UserId  AND ci.CertificationAuthorityId IS NULL

	INSERT [dbo].[CalibratorsToCertificationAuthoritiesAuthorities](CalibratorCertificationAuthorityId,CalibratorId,UpdateUserID)
	SELECT ci.CertificationAuthorityId,@UserId,@LoggedInUserId
	FROM #CertificationAuthoritiesIdsList as ci
	LEFT JOIN [dbo].[CalibratorsToCertificationAuthoritiesAuthorities] as ctc ON ctc.CalibratorId = @UserId and ci.CertificationAuthorityId = ctc.CalibratorCertificationAuthorityId AND ctc.IsDeleted = 0
	WHERE ctc.CalibratorCertificationAuthorityId IS NULL
	END


	COMMIT
END TRY

BEGIN CATCH
ROLLBACK
END CATCH

END