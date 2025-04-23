-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 15/04/2025
-- Description:	This SP edit user data
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-148
-- =============================================
CREATE     PROCEDURE [dbo].[EditUserRecord]
 @FirstName nvarchar(50) = NULL
,@LastName nvarchar(50) = NULL
,@Phone nvarchar(20) = NULL
,@UserAddress nvarchar(200) = NULL
,@Password nvarchar(50) = NULL
,@LocationArea nvarchar(200) = NULL
,@UserRoleIdsList nvarchar(200) = NULL
,@UserStatusId INT
,@Email nvarchar(50) = NULL
,@DepartmentId int = NULL
,@CertificationIdsList nvarchar(max) = NULL
,@LoggedInUserEmail nvarchar(50)
,@UserId INT
,@Stamp NVARCHAR(30) = NULL

/*
EXEC [dbo].[EditUserRecord]
 @FirstName = 'test1'
,@LastName = 'test1'
,@Phone ='911-911-911'
,@UserAddress ='test address'
,@Password ='test123'
,@LocationArea ='test area'
,@UserRoleIdsList ='1,2,3'
,@Email ='tes2t@test.com1234'
,@UserStatusId = 55
,@DepartmentId = 1
,@CertificationIdsList ='1,2,3'
,@LoggedInUserEmail = 'sinova_super_admin@gmail.com'
,@UserId =178
*/

AS
BEGIN

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT = (SELECT ID FROM [dbo].[Users] WHERE Email = @LoggedInUserEmail) 

IF NOT EXISTS (
SELECT 1 FROM [dbo].[Users] as u
WHERE u.ID = @UserId
)
THROW 51000, 'User not exists.', 1;

DROP TABLE IF EXISTS #CertificationIds
CREATE TABLE #CertificationIds
(
CertificationId INT
)

IF @CertificationIdsList IS NOT NULL
INSERT #CertificationIds(CertificationId)
SELECT Value FROM dbo.ParseCSVToTable(@CertificationIdsList)

DROP TABLE IF EXISTS #UserRoles
CREATE TABLE #UserRoles
(
UserRoleId INT
)

IF @UserRoleIdsList IS NOT NULL
INSERT #UserRoles(UserRoleId)
SELECT Value FROM dbo.ParseCSVToTable(@UserRoleIdsList)

DECLARE @IsActive BIT 

SELECT @IsActive = IIF(StatusDescriptionENG='Active',1,0)
  FROM [Calibrator].[dbo].[Statuses] as s
WHERE s.StatusId = @UserStatusId

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
	FROM [dbo].[Users] as u
	WHERE u.ID = @UserId

	IF @UserRoleIdsList IS NOT NULL
	BEGIN
	UPDATE ur 
	SET IsDeleted = 1,UpdateUserID = @LoggedInUserId
	FROM [dbo].[UsersToUserRoles] as ur
	LEFT JOIN #UserRoles as tur ON  ur.UserRoleId = tur.UserRoleId and ur.IsDeleted = 0
	WHERE ur.UserId = @UserId AND tur.UserRoleId IS NULL

	INSERT [dbo].[UsersToUserRoles](UserId,UserRoleId,UpdateUserID)
	SELECT @UserId, tur.UserRoleId,@LoggedInUserId
	FROM #UserRoles as tur
	LEFT JOIN [dbo].[UsersToUserRoles] as ur ON ur.UserId = @UserId AND ur.UserRoleId = tur.UserRoleId AND ur.IsDeleted = 0
	WHERE ur.UserRoleId IS NULL
	END

	IF @CertificationIdsList IS NOT NULL
	BEGIN
	UPDATE ctc
	SET IsDeleted = 1,UpdateUserID = @LoggedInUserId
	FROM [dbo].[CalibratorsToCertification] as ctc
	LEFT JOIN #CertificationIds as ci ON ctc.CalibratorId = @UserId and ci.CertificationId = ctc.CertificationId 
	WHERE ctc.CalibratorId = @UserId  AND ci.CertificationId IS NULL

	INSERT [dbo].[CalibratorsToCertification](CertificationId,CalibratorId,UpdateUserID)
	SELECT ci.CertificationId,@UserId,@LoggedInUserId
	FROM #CertificationIds as ci
	LEFT JOIN [dbo].[CalibratorsToCertification] as ctc ON ctc.CalibratorId = @UserId and ci.CertificationId = ctc.CertificationId AND ctc.IsDeleted = 0
	WHERE ctc.CertificationId IS NULL
	END
	COMMIT
END TRY

BEGIN CATCH
ROLLBACK
END CATCH

END