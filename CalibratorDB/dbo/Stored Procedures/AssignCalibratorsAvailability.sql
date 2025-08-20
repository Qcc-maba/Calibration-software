-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 21/04/2025
-- Description:	Assign availability for calibrator
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[AssignCalibratorsAvailability]
@UserId [int],
@AvailabilityStatusId [int],
@AvailbilityDateFrom [datetime2](0),
@AvailbilityDateTo [datetime2](0),
@LoggedInUserEmail NVARCHAR(50)

/*

*/
AS
BEGIN

IF NOT EXISTS (
SELECT 1 FROM [dbo].[Users] as u
JOIN [dbo].[UserRoles] as ur ON u.UserRoleId = ur.UserRoleId
WHERE u.ID = @UserId AND ur.UserRoleName like '%Calibrator%' and u.IsActive = 1
)
THROW 51000, 'Provided user is not calibrator or user not active', 1;

SET NOCOUNT ON;
DECLARE @LoggedInUserId INT = (SELECT ID FROM [dbo].[Users] WHERE Email = @LoggedInUserEmail) 

INSERT INTO [dbo].[CalibratorsAvailability]
           ([UserId]
           ,[AvailabilityStatusId]
           ,[AvailbilityDateFrom]
           ,[AvailbilityDateTo]
           ,[UpdateUserID])
     VALUES
           (@UserId,
			@AvailabilityStatusId,
            @AvailbilityDateFrom,
			@AvailbilityDateTo,
			@LoggedInUserId
           )

END