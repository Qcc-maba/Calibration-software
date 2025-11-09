-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 20/03/2025
-- Description:	This SP should edit a record for the car management table.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-172
-- =============================================
CREATE   PROCEDURE [dbo].[EditCarRecord]
@CarId INT,
@LicenseNumber NVARCHAR(50) = NULL,
@Model NVARCHAR(50) = NULL,
@NumberOfSeats INT = NULL,
@StatusId INT = NULL,
@OwnerId INT = NULL,
@AssignedCalibrator INT = NULL,
@TreatmentPeriod INT = NULL,
@NextTreatmentDate DATE = NULL,
@NextTestDate DATE = NULL,
@AssociatedEquipmentId NVARCHAR(200) = NULL,
@LoggedInUserEmail NVARCHAR(50) = NULL,
@DowntimePeriodStartDate DATE = NULL,
@DowntimePeriodEndDate DATE = NULL,
@CarIdForReassigment INT = NULL

/*
EXEC [dbo].[EditCarRecord] 
   @CarId = 5
  ,@LicenseNumber = 'Tesla'
  ,@Model = 'tesla test model'
  ,@NumberOfSeats = 5
  ,@StatusId = 35
  ,@OwnerId = 2
  ,@AssignedCalibrator = 6
  ,@TreatmentPeriod = 10000
  ,@NextTreatmentDate = '2025-03-20'
  ,@NextTestDate = '2026-03-20'
  ,@AssociatedEquipmentId = '1,2,3'
*/

AS
BEGIN

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

if NOT EXISTS (
SELECT 1 FROM [dbo].[Cars] WHERE CarId = @CarId
)
THROW 51000, 'Car do not exist', 1;

IF @StatusId IS NOT NULL AND @StatusId NOT IN (SELECT StatusId
				FROM [dbo].[Statuses] as s
				JOIN [dbo].[StatusesCategories] as c On s.[StatusCategoryId] = c.[StatusCategoryId]
				WHERE c.StatusDescriptionENG = 'CarStatus' )
THROW 51000, 'Incorrect status was assigned.', 1;

DECLARE @StatusDescription NVARCHAR(255) = (SELECT TOP 1 [StatusDescriptionENG] FROM [dbo].[Statuses] WHERE StatusId = @StatusId)

IF( @StatusDescription IN (N'Treatment',N'UnAvailable') AND @DowntimePeriodStartDate IS NULL AND @DowntimePeriodEndDate IS NULL )
THROW 51000, 'For statuses Treatment and UnAvailable date range should be provided.', 1;

DROP TABLE IF EXISTS #AssociatedEquipmentIDs
CREATE TABLE #AssociatedEquipmentIDs
(
EquipmentId INT
)

INSERT #AssociatedEquipmentIDs(EquipmentId)
SELECT Value FROM dbo.ParseCSVToTable(@AssociatedEquipmentId)

if EXISTS (
SELECT 1 FROM [dbo].[Users] as u
WHERE (u.ID = @OwnerId)  AND u.IsActive = 0
)
THROW 51000, 'Incorrect or inactive user assigned as owner.', 1;


if EXISTS (
SELECT 1 FROM [dbo].[Users] as u
WHERE (u.ID = @AssignedCalibrator)  AND u.IsActive = 0
)
THROW 51000, 'Incorrect or inactive user assigned as owner.', 1;

BEGIN TRY
	BEGIN TRANSACTION

	UPDATE [dbo].[Cars]
	   SET 
		   [Model] = COALESCE(@Model,'')
		  ,[LicenseNumber] = COALESCE(@LicenseNumber,'')
		  ,[Seats] = COALESCE(@NumberOfSeats,0)
		  ,[TreatmentPeriod] = @TreatmentPeriod
		  ,[NextTreatmentDate] = @NextTreatmentDate
		  ,[NextYearlyTestDate] = @NextTestDate
		  ,[OwnerId] = COALESCE(@OwnerId,[OwnerId])
		  ,[CarStatusId] = COALESCE(@StatusId,0)
		  ,[UpdatedDate] = GETDATE()
		  ,[UpdateUserID] = @LoggedInUserId
		  ,[AssignedCalibratorId] = @AssignedCalibrator
	 WHERE CarId = @CarId

	UPDATE [dbo].[CarsToEquipment]
	SET [IsDeleted] = 1,
		[UpdateUserID] = @LoggedInUserId
	WHERE CarId = @CarId

	INSERT [dbo].[CarsToEquipment](CarId, MeasurementDeviceId,UpdateUserID)
	SELECT DISTINCT @CarId, EquipmentId, @LoggedInUserId
	FROM #AssociatedEquipmentIDs

	IF (@DowntimePeriodStartDate IS NOT NULL AND @DowntimePeriodEndDate IS NOT NULL AND @StatusDescription IN (N'Treatment',N'UnAvailable')
	AND NOT EXISTS 
	(
		SELECT TOP 1 CarId
		FROM [dbo].[CarsToOrder]
		WHERE [IsDeleted] = 0
			AND [AssignDate] >= @DowntimePeriodStartDate 
			AND [AssignDate] <= @DowntimePeriodEndDate
			AND [CarId] = @CarId
			/*This check allow to skip reassing logic*/
			AND 1 = IIF(@StatusDescription = N'Treatment',1,0)
	)
	AND NOT EXISTS 
	(
	SELECT 1 
	FROM [dbo].[CarDowntimePeriodHistory]
	WHERE [CarId] = @CarId 
		AND [TreatmentStartDate] = @DowntimePeriodStartDate 
		AND [TreatmentEndDate] = @DowntimePeriodEndDate
		AND [StatusId] = @StatusId
	)
	)
	BEGIN

		-- In case if Treatment specified populate table for tracking and assing car status as treatment
		INSERT [dbo].[CarDowntimePeriodHistory]
		(
			[CarId],
			[DateOfChange],
			[TreatmentStartDate],
			[TreatmentEndDate],
			[UpdateUserID],
			[StatusId]
		)
		SELECT 
			@CarId,
			GETDATE(),
			@DowntimePeriodStartDate,
			@DowntimePeriodEndDate,
			@LoggedInUserId,
			@StatusId
	   
		UPDATE cto
		SET CarId = @CarIdForReassigment
		FROM [dbo].[CarsToOrder] as cto
		WHERE cto.[IsDeleted] = 0
			AND cto.[AssignDate] >= @DowntimePeriodStartDate 
			AND cto.[AssignDate] <= @DowntimePeriodEndDate
			AND cto.CarId = @CarId
			SELECT @@ERROR;
	END

	IF (@DowntimePeriodStartDate IS NOT NULL AND @DowntimePeriodEndDate IS NOT NULL AND @StatusDescription IN (N'Treatment')
	AND EXISTS 
	(
		SELECT TOP 1 CarId
		FROM [dbo].[CarsToOrder]
		WHERE [IsDeleted] = 0
			AND [AssignDate] >= @DowntimePeriodStartDate 
			AND [AssignDate] <= @DowntimePeriodEndDate
			AND [CarId] = @CarId
			/*This check allow to skip reassing logic*/
			AND 1 = IIF(@StatusDescription = N'Treatment',1,0)
	) )	THROW 51000, 'Status was not changed. Active orders assigments exists.', 1;
	COMMIT
END TRY

BEGIN CATCH
ROLLBACK

	SELECT wp.OrderNumber, cto.AssignDate
	FROM [dbo].[CarsToOrder] as cto
	JOIN [dbo].[OrderWorkPlans] as wp ON cto.OrderWorkPlanId = wp.OrderWorkPlanId
	WHERE [IsDeleted] = 0
		AND [AssignDate] >= @DowntimePeriodStartDate 
		AND [AssignDate] <= @DowntimePeriodEndDate
		AND [CarId] = @CarId

		

END CATCH
END