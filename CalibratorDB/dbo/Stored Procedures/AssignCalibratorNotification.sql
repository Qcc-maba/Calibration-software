-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 28/11/2025
-- Description:	This SP should assign notification for calibrator.
-- JiraLink: 
-- =============================================

CREATE   PROCEDURE [dbo].[AssignCalibratorNotification]
@LoggedInUserEmail NVARCHAR(100),
@CalibratorNotificationId INT = NULL,
@CalibratorId INT = NULL,
@OrderWorkPlanId INT = NULL,
@OrderDetailId INT = NULL,
@OrderDetailItemId INT = NULL,
@NotificationText  NVARCHAR(200) = NULL,
@IsDeleted BIT = NULL

AS
BEGIN

SET NOCOUNT ON;


DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

--- Check if all users are valid
if NOT EXISTS (
SELECT 1 FROM [dbo].[Users] as ul
WHERE ul.ID = @CalibratorId AND ul.IsActive = 1
) AND @CalibratorId IS NOT NULL
THROW 51000, 'Incorrect or inactive calibrators were found.', 1;

/*Delete record*/
IF (@CalibratorNotificationId IS NOT NULL AND @IsDeleted = 1)
BEGIN
    UPDATE [dbo].[CalibratorNotifications]
        SET [IsDeleted] = @IsDeleted,
            [UpdatedDate] = GETDATE(),
            [UpdateUserID] = @LoggedInUserId
    WHERE [CalibratorNotificationId] = @CalibratorNotificationId
    RETURN
END

IF (@OrderWorkPlanId IS NULL AND @OrderDetailId IS NULL AND @OrderDetailItemId IS NULL)
THROW 51000, 'Please provide @OrderWorkPlanId or @OrderDetailId or @OrderDetailItemId as one of it required parameter.', 1;

IF @CalibratorNotificationId IS NULL
	INSERT INTO [dbo].[CalibratorNotifications]
           ([CalibratorId]
           ,[OrderWorkPlanId]
           ,[OrderDetailId]
           ,[OrderDetailItemId]
           ,[NotificationText]
           ,[CreatedDate]
           ,[CreateUserId]
           ,[IsDeleted])
    VALUES (
            @CalibratorId
           ,@OrderWorkPlanId
           ,@OrderDetailId
           ,@OrderDetailItemId
           ,@NotificationText
           ,GETDATE()
           ,@LoggedInUserId
           ,0
           )
ELSE 
    UPDATE [dbo].[CalibratorNotifications]
    SET [CalibratorId] = @CalibratorId,
        [OrderWorkPlanId] = @OrderWorkPlanId,
        [OrderDetailId] = @OrderDetailId,
        [OrderDetailItemId] = @OrderDetailItemId,
        [NotificationText] = @NotificationText,
        [UpdatedDate] = GETDATE(),
        [UpdateUserID] = @LoggedInUserId
    WHERE [CalibratorNotificationId] = @CalibratorNotificationId

END