-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 19/12/2025
-- Description:	Mark notification as read or delete it
-- =============================================

CREATE   PROCEDURE dbo.UpdateCalibratorNotification
@CalibratorId INT,
@CalibratorNotificationId INT,
@IsRead BIT = NULL,
@IsDelete BIT = NULL

AS

IF @IsRead IS NOT NULL

UPDATE [dbo].[CalibratorNotifications] 
SET [IsRead] = @IsRead,
    [UpdatedDate] = GETDATE()
WHERE [CalibratorId] = @CalibratorId AND  [CalibratorNotificationId] = @CalibratorNotificationId


IF @IsDelete IS NOT NULL

UPDATE [dbo].[CalibratorNotifications] 
SET [IsDeleted] = @IsDelete,
    [UpdatedDate] = GETDATE()
WHERE [CalibratorId] = @CalibratorId AND  [CalibratorNotificationId] = @CalibratorNotificationId