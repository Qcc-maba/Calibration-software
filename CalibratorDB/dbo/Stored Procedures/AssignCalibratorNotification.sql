
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 28/11/2025
-- Description:	This SP should assign notification for calibrator.
-- JiraLink: 
-- =============================================

CREATE   PROCEDURE [dbo].[AssignCalibratorNotification]
@LoggedInUserEmail NVARCHAR(100),
@CalibratorNotificationId INT = NULL,
@CalibratorIds NVARCHAR(MAX) = NULL,
@OrderWorkPlanId INT = NULL,
@OrderDetailId INT = NULL,
@OrderDetailItemId INT = NULL,
@NotificationText  NVARCHAR(200) = NULL,
@IsDeleted BIT = NULL

AS
BEGIN

SET NOCOUNT ON;

DROP TABLE IF EXISTS #CalibratorIDs
CREATE TABLE #CalibratorIDs
(
CalibratorID INT
)

INSERT #CalibratorIDs(CalibratorID)
SELECT Value FROM dbo.ParseCSVToTable(@CalibratorIds)
WHERE LEN(Value) > 0

DECLARE @LoggedInUserId INT = 0
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

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
    SELECT
            CalibratorID
           ,@OrderWorkPlanId
           ,@OrderDetailId
           ,@OrderDetailItemId
           ,@NotificationText
           ,GETDATE()
           ,@LoggedInUserId
           ,0
    FROM #CalibratorIDs
--ELSE 
--    UPDATE [dbo].[CalibratorNotifications] as 
--    SET [CalibratorId] = @CalibratorId,
--        [OrderWorkPlanId] = @OrderWorkPlanId,
--        [OrderDetailId] = @OrderDetailId,
--        [OrderDetailItemId] = @OrderDetailItemId,
--        [NotificationText] = @NotificationText,
--        [UpdatedDate] = GETDATE(),
--        [UpdateUserID] = @LoggedInUserId
--    WHERE [CalibratorNotificationId] = @CalibratorNotificationId

END