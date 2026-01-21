-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 21/01/2026
-- Description:	This SP cancel assigment of car, calibrator and equipment on specific date.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-567
-- =============================================
CREATE   PROCEDURE [dbo].[RemoveCarAssignment]
@OrderWorkPlanId INT,
@AssigmentDate DATE,
@CarId INT,
@LoggedInUserEmail NVARCHAR(100)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @LoggedInUserId INT 
	DECLARE @SourceId TINYINT

	SELECT 
	 @LoggedInUserId  = d.UserId 
	,@SourceId = d.SourceId
	FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

	
	DECLARE @Notification TABLE
	(
	CalibratorId INT,
	NotificationText NVARCHAR(200)
	)
	INSERT @Notification(CalibratorId,NotificationText)
	SELECT ca.CalibratorId, CONCAT('You''ve been unassigned from order #',wp.OrderNumber,' for ',@AssigmentDate)
	FROM [dbo].[CalibratorsToWorkPlan] as ca
	JOIN [dbo].[OrderWorkPlans] as wp ON ca.OrderWorkPlanId = wp.OrderWorkPlanId
	WHERE ca.OrderWorkPlanId = @OrderWorkPlanId AND ca.CarId = @CarId AND ca.AssigmentDate = @AssigmentDate 

	BEGIN TRANSACTION

		UPDATE [dbo].[CalibratorsToWorkPlan]
		SET IsDeleted = 1,
		    UpdatedDate = GETDATE(),
			UpdateUserID = @LoggedInUserId
		WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId = @CarId AND AssigmentDate = @AssigmentDate

		UPDATE [dbo].[CarsToOrder]
		SET IsDeleted = 1,
			UpdatedDate = GETDATE(),
			UpdateUserID = @LoggedInUserId
		WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId = @CarId AND AssignDate = @AssigmentDate

		UPDATE [dbo].[MeasurementDevicesToOrderHeaders]
		SET IsDeleted = 1,
			UpdatedDate = GETDATE(),
			UpdateUserID = @LoggedInUserId
		WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId = @CarId AND AssigmentDate = @AssigmentDate

		INSERT INTO [dbo].[CalibratorNotifications]
				([CalibratorId]
				,[OrderWorkPlanId]
				,[NotificationText]
				,[CreatedDate]
				,[CreateUserId]
				,[IsDeleted]
				,[NotificationTypeId])
		SELECT
				c.CalibratorID
				,@OrderWorkPlanId
				,c.[NotificationText]
				,GETDATE()
				,@LoggedInUserId
				,0
				,(SELECT StatusId FROM [dbo].[Statuses] WHERE StatusDescriptionENG='CancelOrderNotification')
		FROM @Notification as c

	COMMIT

END