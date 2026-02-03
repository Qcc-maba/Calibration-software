-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/03/2025
-- Description:	This SP should assign a car to a specific order. It should return the status of the operation.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-182
-- =============================================
CREATE   PROCEDURE [dbo].[AssignCarToOrder]
@CarID INT,
@OrderNumber NCHAR(12),
@Date DATE,
@QuartersOfDay NVARCHAR(10),
@LoggedInUserEmail NVARCHAR(100) = NULL
--EXEC dbo.AssignCarToOrder @CarID = 3,@OrderNumber = 'LA25101669',@Date = '2025-04-11',@QuartersOfDay ='0,1,2,3'

AS
BEGIN

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

DROP TABLE IF EXISTS #QuartersOfDay
CREATE TABLE #QuartersOfDay
(
QuarterId INT
)

INSERT #QuartersOfDay(QuarterId)
SELECT Value FROM dbo.ParseCSVToTable(@QuartersOfDay)

if (SELECT SUM(QuarterId) FROM #QuartersOfDay) > 6
THROW 51000, 'Incorrect values passed for quaters.', 1;

DECLARE @OrderWorkPlanId INT
SELECT @OrderWorkPlanId =  o.OrderWorkPlanId FROM [dbo].[OrderWorkPlans] as o 
WHERE o.OrderNumber = @OrderNumber AND o.IsCancelled = 0
IF @OrderWorkPlanId IS NULL
THROW 51000, 'Incorrect or not active order number passed.', 1;

if NOT EXISTS (
SELECT 1 FROM dbo.Cars as c
WHERE c.CarId = @CarID
)
THROW 51000, 'Incorrect car id passed.', 1;

DECLARE 
@part0db BIT,
@part1db BIT,
@part2db BIT,
@part3db BIT,
@exists BIT

SELECT  
    @part0db = MAX(CASE WHEN QuarterId = 0 THEN 1 ELSE NULL END),
    @part1db = MAX(CASE WHEN QuarterId = 1 THEN 1 ELSE NULL END),
    @part2db = MAX(CASE WHEN QuarterId = 2 THEN 1 ELSE NULL END),
    @part3db = MAX(CASE WHEN QuarterId = 3 THEN 1 ELSE NULL END)
FROM #QuartersOfDay;

SELECT  @part0db =  COALESCE(@part0db,AssignQuater0),
		@part1db =  COALESCE(@part1db,AssignQuater1),
		@part2db =  COALESCE(@part2db,AssignQuater2),
		@part3db =  COALESCE(@part3db,AssignQuater3),
		@exists = 1
FROM [dbo].[CarsToOrder] as cto
WHERE cto.CarId = @CarID AND cto.OrderWorkPlanId = @OrderWorkPlanId 
		AND cto.AssignDate = @Date AND cto.IsDeleted = 0

BEGIN TRY
	BEGIN TRAN
		IF @exists IS NULL

		INSERT [dbo].[CarsToOrder](CarId,OrderWorkPlanId,AssignDate,AssignQuater0,AssignQuater1,AssignQuater2,AssignQuater3,UpdateUserID)
		SELECT @CarID as CarID, 
			   @OrderWorkPlanId as OrderWorkPlanId,
			   @Date as AssignDate,
			   @part0db as AssignQuater0,
			   @part1db as AssignQuater1,
			   @part2db as AssignQuater2,
			   @part3db as AssignQuater3,
			   @LoggedInUserId


		ELSE

		UPDATE [dbo].[CarsToOrder]
		SET AssignQuater0 = @part0db,
			AssignQuater1 = @part1db,
			AssignQuater2 = @part2db,
			AssignQuater3 = @part3db,
			UpdatedDate = GETDATE(),
			UpdateUserID = @LoggedInUserId
		WHERE CarId = @CarID AND OrderWorkPlanId = @OrderWorkPlanId 
				AND AssignDate = @Date AND IsDeleted = 0
		
		IF EXISTS (SELECT 1 FROM [dbo].[MeasurementDevicesToOrderHeaders] WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId IS NULL AND AssigmentDate IS NULL AND IsDeleted = 0)
			UPDATE [dbo].[MeasurementDevicesToOrderHeaders]
			SET CarId = @CarID,
				AssigmentDate = @Date
			WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId IS NULL AND AssigmentDate IS NULL
		
		IF NOT EXISTS (SELECT 1 FROM [dbo].[MeasurementDevicesToOrderHeaders] WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId = @CarID AND AssigmentDate = @Date AND IsDeleted = 0)
			INSERT INTO [dbo].[MeasurementDevicesToOrderHeaders]
					   ([OrderWorkPlanId]
					   ,[MeasurementDeviceId]
					   ,[CreatedByUserId]
					   ,[AssigmentDate]
					   ,[CarId])

			SELECT TOP 1 WITH TIES
					@OrderWorkPlanId,
					[MeasurementDeviceId],
					@LoggedInUserId,
					@Date,
					@CarID
			FROM [dbo].[MeasurementDevicesToOrderHeaders] 
			WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId = @CarID AND IsDeleted = 0
			ORDER BY RANK() OVER(PARTITION BY OrderWorkPlanId ORDER BY AssigmentDate)

		IF EXISTS (SELECT 1 FROM [dbo].[CalibratorsToWorkPlan] WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId IS NULL AND AssigmentDate IS NULL AND IsDeleted = 0)
			UPDATE [dbo].[CalibratorsToWorkPlan]
			SET CarId = @CarID,
				AssigmentDate = @Date
			WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId IS NULL AND AssigmentDate IS NULL

		IF NOT EXISTS (SELECT 1 FROM [dbo].[CalibratorsToWorkPlan] WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId = @CarID AND AssigmentDate = @Date AND IsDeleted = 0)
			INSERT INTO [dbo].[CalibratorsToWorkPlan]
					   ([OrderWorkPlanId]
					   ,[CalibratorId]
					   ,[UpdateUserID]
					   ,[AssigmentDate]
					   ,[CarId])

			SELECT TOP 1 WITH TIES
					@OrderWorkPlanId,
					[CalibratorId],
					@LoggedInUserId,
					@Date,
					@CarID
			FROM [dbo].[CalibratorsToWorkPlan] 
			WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId = @CarID AND IsDeleted = 0
			ORDER BY RANK() OVER(PARTITION BY OrderWorkPlanId ORDER BY AssigmentDate)

	COMMIT
END TRY

BEGIN CATCH
	ROLLBACK
END CATCH

/*
UPDATE [dbo].[OrderWorkPlans]
SET AssigmentDate = @Date
WHERE OrderNumber = @OrderNumber
*/

END