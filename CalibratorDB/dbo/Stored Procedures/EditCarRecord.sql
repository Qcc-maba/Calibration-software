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
@TreatmentStartDate DATE = NULL,
@TreatmentEndDate DATE = NULL

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


	IF (@TreatmentStartDate IS NOT NULL AND @TreatmentEndDate IS NOT NULL)
	BEGIN
		-- In case if Treatment specified populate table for tracking and assing car status as treatment
		INSERT [dbo].[CarsTreatmentTracking]
		(
			[CarId],
			[DateOfChange],
			[TreatmentStartDate],
			[TreatmentEndDate],
			[UpdateUserID]
		)
		SELECT 
			@CarId,
			GETDATE(),
			@TreatmentStartDate,
			@TreatmentEndDate,
			@LoggedInUserId
	   
		UPDATE [dbo].[Cars]
		SET [CarStatusId] = (
				SELECT TOP 1 s.StatusId
				FROM [dbo].[Statuses] AS s
				JOIN [dbo].[StatusesCategories] AS c ON s.[StatusCategoryId] = c.[StatusCategoryId]
				WHERE c.StatusDescriptionENG = 'CarStatus'
					AND s.StatusDescriptionENG = 'Treatment'
				)
			,[UpdatedDate] = GETDATE()
			,[UpdateUserID] = @LoggedInUserId
		WHERE CarId = @CarId

		DECLARE @UpdatedCarsAssigments TABLE (
			[CarId] [int] NOT NULL,
			[AssignDate] [datetime2](0) NOT NULL,
			[AssignQuater0] [bit] NULL,
			[AssignQuater1] [bit] NULL,
			[AssignQuater2] [bit] NULL,
			[AssignQuater3] [bit] NULL,
			[OrderWorkPlanId] [int] NOT NULL
		)

		UPDATE [dbo].[CarsToOrder]
		SET IsDeleted = 1
			,UpdateUserID = @LoggedInUserId
			,UpdatedDate = GETDATE()
		OUTPUT DELETED.[CarId]
			,DELETED.[AssignDate]
			,DELETED.[AssignQuater0]
			,DELETED.[AssignQuater1]
			,DELETED.[AssignQuater2]
			,DELETED.[AssignQuater3]
			,DELETED.[OrderWorkPlanId]
		INTO @UpdatedCarsAssigments
		WHERE [IsDeleted] = 0
			AND [AssignDate] >= @TreatmentStartDate 
			AND [AssignDate] <= @TreatmentEndDate
			AND [CarId] = @CarId

		SELECT 
			[CarId],
			[AssignDate],
			[AssignQuater0],
			[AssignQuater1],
			[AssignQuater2],
			[AssignQuater3],
			[OrderWorkPlanId]
		FROM @UpdatedCarsAssigments

	END

	COMMIT
END TRY

BEGIN CATCH
ROLLBACK
END CATCH
END