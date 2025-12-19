-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 19/12/2025
-- Description:	Create notification
-- =============================================

CREATE   PROCEDURE dbo.CreateCalibratorNotification
@CalibratorId INT,
@OrderWorkPlanId INT = NULL,
@OrderDetailId INT = NULL,
@OrderDetailItemId INT = NULL,
@NotificationText NVARCHAR(200),
@NotificationTypeId INT,
@LoggedInUserEmail NVARCHAR(100),
@RedirectPage NVARCHAR(200)
AS

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

INSERT INTO [dbo].[CalibratorNotifications]
           ([CalibratorId]
           ,[OrderWorkPlanId]
           ,[OrderDetailId]
           ,[OrderDetailItemId]
           ,[NotificationText]
           ,[NotificationTypeId]
           ,[CreatedDate]
           ,[CreateUserId]
           ,[RedirectPage])
     VALUES
           (
            @CalibratorId,
            @OrderWorkPlanId,
            @OrderDetailId,
            @OrderDetailItemId,
            @NotificationText,
            @NotificationTypeId,
            GETDATE(),
            @LoggedInUserId,
            @RedirectPage
           )