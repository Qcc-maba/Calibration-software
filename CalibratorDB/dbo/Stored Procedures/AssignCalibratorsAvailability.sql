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

SET NOCOUNT ON;

IF NOT EXISTS (
SELECT 1 FROM [dbo].[Users] as u
JOIN [dbo].[UserRoles] as ur ON u.UserRoleId = ur.UserRoleId
WHERE u.ID = @UserId AND ur.UserRoleName IN (N'SuperAdmin',N'Calibrator',N'ExternalCalibrator')
and u.IsActive = 1
)
THROW 51000, 'Provided user is not calibrator or user not active', 1;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

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