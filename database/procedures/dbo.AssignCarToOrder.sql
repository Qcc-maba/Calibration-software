-- =============================================
-- Proc:        dbo.AssignCarToOrder
-- Jira:        MBA-160 "Create SP to save the car placement"
--              (parent MBA-91 "Assign car to the order")
--              Originally authored under MABA-182 (Eduard Kudlaiev, 17/03/2025);
--              re-published here as the reviewable source of truth for MBA-160.
-- Description: Upsert (INSERT/UPDATE) that saves a car placement for one order on one
--              calendar day. The day is split into 4 quarters (0..3 = 9:00 / 11:00 /
--              14:00 / 16:00). The set of quarters passed in @QuartersOfDay is merged
--              onto the existing CarsToOrder row for (CarId, OrderWorkPlanId, AssignDate)
--              if one exists, otherwise a new row is inserted. As a side effect it also
--              back-fills the CarId/AssigmentDate onto the order's placeholder device- and
--              calibrator-to-workplan rows so the assignment date propagates through.
--
-- Inputs:
--   @CarID             INT            -- dbo.Cars.CarId to place
--   @OrderNumber       NCHAR(12)      -- resolves to OrderWorkPlans.OrderWorkPlanId (active only)
--   @Date              DATE           -- assignment (placement) date
--   @QuartersOfDay     NVARCHAR(10)   -- CSV of quarter ids, e.g. '0,1,2,3'
--   @LoggedInUserEmail NVARCHAR(100)  -- resolves to UserId via dbo.GetSourceFilterByEmail
--
-- Output:      None (no result set). Writes to dbo.CarsToOrder and back-fills
--              dbo.MeasurementDevicesToOrderHeaders and dbo.CalibratorsToWorkPlan.
--
-- Called from: app tRPC cars.assignCarToOrder
--              (src/server/api/routers/cars/cars.ts):
--              exec dbo.AssignCarToOrder @CarID, @OrderNumber, @Date, @QuartersOfDay, @LoggedInUserEmail
--
-- NOTES FOR REVIEW:
--   1. The whole write is wrapped in BEGIN TRY / BEGIN CATCH with a bare ROLLBACK and an
--      EMPTY catch body. Any failure is therefore SILENTLY SWALLOWED: the transaction
--      rolls back but the caller (tRPC mutation) still sees success. Preserved as-is to
--      match the deployed behavior — reviewer should decide whether to re-THROW so the
--      app can surface save failures to the coordinator.
--   2. The quarter guard `SUM(QuarterId) > 6` is only a coarse sanity check (0+1+2+3 = 6),
--      so it never rejects a legitimate full-day selection but also does not validate that
--      values are strictly within {0,1,2,3}. Preserved from the original.
--   3. On UPDATE the quarter columns are set from COALESCE(new, existing), i.e. quarters
--      are additive/merge-only — this SP cannot CLEAR a previously-set quarter (that path
--      is handled by dbo.RemoveCarAssignment / MBA-567). Confirm this is intended.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[AssignCarToOrder]
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
