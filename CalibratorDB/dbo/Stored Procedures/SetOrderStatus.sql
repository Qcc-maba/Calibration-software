-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/09/2025
-- Description:	This SP should set order status. It should take an array of order IDs and return the status of the operation.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-176
-- =============================================
CREATE   PROCEDURE [dbo].[SetOrderStatus]
@OrderIDs NVARCHAR(2000),
@Canceled BIT = NULL,
@OrderStatus INT = NULL,
@ClientConfirmationStatus INT = NULL
--EXEC dbo.SetOrderStatus @OrderIDs = N'LA24101259,LA24101282,LA24101290,LA24101296,LA24101306,LA24101328'

AS
BEGIN

SET NOCOUNT ON;

DECLARE @SpecifiedCount INT
SET @SpecifiedCount =
          (CASE WHEN @Canceled IS NOT NULL THEN 1 ELSE 0 END)
        + (CASE WHEN @OrderStatus IS NOT NULL THEN 1 ELSE 0 END)
        + (CASE WHEN @ClientConfirmationStatus IS NOT NULL THEN 1 ELSE 0 END);

IF @SpecifiedCount > 1 OR @SpecifiedCount = 0
THROW 51000, 'Only one parameter should be specified: @Canceled or @OrderStatus or @ClientConfirmationStatus.', 1;


DROP TABLE IF EXISTS #OrderIDs 
CREATE TABLE #OrderIDs
(
OrderNumber NVARCHAR(20) COLLATE Latin1_General_100_CI_AI_SC
)

INSERT #OrderIDs(OrderNumber)
SELECT Value FROM dbo.ParseCSVToTable(@OrderIDs)

IF @Canceled IS NOT NULL
BEGIN

    UPDATE o
    SET o.IsCancelled = 1
    FROM [dbo].[OrderWorkPlans] as o
    JOIN #OrderIDs as upd ON o.OrderNumber = upd.OrderNumber
    
    INSERT INTO [dbo].[CalibratorNotifications]
           ([CalibratorId]
           ,[OrderWorkPlanId]
           ,[NotificationText]
           ,[CreatedDate]
           ,[CreateUserId]
           ,[IsDeleted]
           ,[NotificationTypeId])
    SELECT
            cwp.CalibratorID
           ,o.OrderWorkPlanId
           ,CONCAT('Order ',LTRIM(RTRIM(o.OrderNumber)),' was cancelled.') AS [NotificationText]
           ,GETDATE()
           ,0
           ,0
           ,(SELECT StatusId FROM [dbo].[Statuses] WHERE StatusDescriptionENG='CancelOrderNotification')
    FROM [dbo].[OrderWorkPlans] as o
    JOIN #OrderIDs as upd ON o.OrderNumber = upd.OrderNumber
    JOIN [dbo].[CalibratorsToWorkPlan] as cwp ON o.OrderWorkPlanId = cwp.OrderWorkPlanId

END

IF @OrderStatus IS NOT NULL
UPDATE o
SET o.OrderOverallStatusId = @OrderStatus
FROM [dbo].[OrderWorkPlans] as o
JOIN #OrderIDs as upd ON o.OrderNumber = upd.OrderNumber

IF @ClientConfirmationStatus IS NOT NULL
UPDATE o
SET o.ClientConfirmationStatusId = @ClientConfirmationStatus
FROM [dbo].[OrderWorkPlans] as o
JOIN #OrderIDs as upd ON o.OrderNumber = upd.OrderNumber

IF EXISTS (SELECT 1 FROM [dbo].[Statuses] WHERE StatusId = @ClientConfirmationStatus AND StatusDescriptionENG='Pending')

INSERT INTO [dbo].[CalibratorNotifications]
        ([CalibratorId]
        ,[OrderWorkPlanId]
        ,[NotificationText]
        ,[CreatedDate]
        ,[CreateUserId]
        ,[IsDeleted]
        ,[NotificationTypeId])
SELECT
        cwp.CalibratorID
        ,o.OrderWorkPlanId
        ,CONCAT('Order ',LTRIM(RTRIM(o.OrderNumber)),' was delayed.') AS [NotificationText]
        ,GETDATE()
        ,0
        ,0
        ,(SELECT StatusId FROM [dbo].[Statuses] WHERE StatusDescriptionENG='DelayOrderNotification')
FROM [dbo].[OrderWorkPlans] as o
JOIN #OrderIDs as upd ON o.OrderNumber = upd.OrderNumber
JOIN [dbo].[CalibratorsToWorkPlan] as cwp ON o.OrderWorkPlanId = cwp.OrderWorkPlanId

END