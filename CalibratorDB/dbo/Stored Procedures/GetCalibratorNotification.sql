-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 28/11/2025
-- Description:	This SP should show assigned notifications.
-- JiraLink: 
-- =============================================

CREATE   PROCEDURE [dbo].[GetCalibratorNotification]
@CalibratorNotificationId INT = NULL,
@OrderWorkPlanId INT = NULL,
@OrderDetailId INT = NULL,
@OrderDetailItemId INT = NULL
AS
BEGIN

SET NOCOUNT ON;

IF (@CalibratorNotificationId IS NULL AND @OrderWorkPlanId IS NULL AND @OrderDetailId IS NULL AND @OrderDetailItemId IS NULL)
THROW 51000, 'Please provide @CalibratorNotificationId or @OrderWorkPlanId or @OrderDetailId or @OrderDetailItemId as one of it required parameter.', 1;

DECLARE @sql NVARCHAR(MAX)

SET @sql = 
CONCAT(
'
SELECT 
       cn.[CalibratorId]
      ,CONCAT(c.FirstName,'' '',c.LastName) as Calibrator
      ,cn.[CalibratorNotificationId]
      ,cn.[OrderWorkPlanId]
      ,cn.[OrderDetailId]
      ,cn.[OrderDetailItemId]
      ,cn.[NotificationText]
      ,cn.[NotificationTypeId]
      ,cn.[ResolvedDate]
      ,cn.[CreatedDate]
      ,cn.[CreateUserId] AS ValidatorId
      ,CONCAT(c1.FirstName,'' '',c1.LastName) as Calibrator
  FROM [dbo].[CalibratorNotifications] as cn
  LEFT JOIN [dbo].[Users] as c ON cn.[CalibratorId] = c.[ID]
  LEFT JOIN [dbo].[Users] as c1 ON cn.[CreateUserId] = c1.[ID]
  WHERE cn.[IsDeleted] = 0'
 ,CASE WHEN @CalibratorNotificationId IS NOT NULL THEN ' AND cn.CalibratorNotificationId = '''+CAST(@CalibratorNotificationId as NVARCHAR(MAX)) +''' 'ELSE ' ' END
 ,CASE WHEN @OrderWorkPlanId IS NOT NULL THEN ' AND cn.OrderWorkPlanId = '''+CAST(@OrderWorkPlanId as NVARCHAR(MAX)) +''' 'ELSE ' ' END
 ,CASE WHEN @OrderDetailId IS NOT NULL THEN ' AND cn.OrderDetailId = '''+CAST(@OrderDetailId as NVARCHAR(MAX)) +''' 'ELSE ' ' END
 ,CASE WHEN @OrderDetailItemId IS NOT NULL THEN ' AND cn.OrderDetailItemId = '''+CAST(@OrderDetailItemId as NVARCHAR(MAX)) +''' 'ELSE ' ' END
)
PRINT(@sql)
EXEC sp_executesql @sql

END