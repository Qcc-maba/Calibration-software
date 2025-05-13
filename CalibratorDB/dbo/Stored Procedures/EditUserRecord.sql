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
,@UserRoleId int = NULL
,@UserStatusId INT
,@Email nvarchar(50) = NULL
,@DepartmentIdsList nvarchar(max) = NULL
,@CertificationIdsList nvarchar(max) = NULL
,@LoggedInUserEmail nvarchar(50)
,@UserId INT
,@Stamp NVARCHAR(200) = NULL

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
	FROM [dbo].[Users] as u
	WHERE u.ID = @UserId

	IF @DepartmentIdsList IS NOT NULL
	BEGIN
	UPDATE ud
	SET IsDeleted = 1,UpdateUserID = @LoggedInUserId
	FROM [dbo].[UsersToDepartments] as ud
	LEFT JOIN #DepartmentIdsList as di ON ud.UserId = @UserId and di.DepartmentId = ud.DepartmentId
	WHERE ud.UserId = @UserId  AND di.DepartmentId IS NULL

	INSERT [dbo].[UsersToDepartments](UserId,DepartmentId,UpdateUserID)
	SELECT @UserId,di.DepartmentId, @LoggedInUserId
	FROM #DepartmentIdsList as di
	LEFT JOIN [dbo].[UsersToDepartments] as ud ON ud.UserId = @UserId and di.DepartmentId = ud.DepartmentId AND ud.IsDeleted = 0
	WHERE ud.DepartmentId IS NULL
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