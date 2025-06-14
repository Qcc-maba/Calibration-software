-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 20/03/2025
-- Description:	This SP should edit a record for the car management table.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-172
-- =============================================
CREATE   PROCEDURE [dbo].[EditCarRecord]
@CarId INT,
@LicenseNumber NVARCHAR(50),
@Model NVARCHAR(50),
@NumberOfSeats INT,
@StatusId INT,
@OwnerId INT = NULL,
@AssignedCalibrator INT,
@TreatmentPeriod INT,
@NextTreatmentDate DATE,
@NextTestDate DATE,
@AssociatedEquipmentId NVARCHAR(200)

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

if NOT EXISTS (
SELECT 1 FROM [dbo].[Cars] WHERE CarId = @CarId
)
THROW 51000, 'Car do not exist', 1;

IF @StatusId NOT IN (SELECT StatusId
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
SELECT 1 FROM #AssociatedEquipmentIDs as t
JOIN [dbo].[CalibEquipments] as e ON e.ID = t.EquipmentId
JOIN [dbo].[Statuses] as s ON s.StatusId = e.StatusId
WHERE  s.StatusDescriptionENG <> 'Available'
)
THROW 51000, 'Incorrect or inactive equipment were found in list.', 1;

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
		   [Model] = @Model
		  ,[LicenseNumber] = @LicenseNumber
		  ,[Seats] = @NumberOfSeats
		  ,[TreatmentPeriod] = @TreatmentPeriod
		  ,[NextTreatmentDate] = @NextTreatmentDate
		  ,[NextYearlyTestDate] = @NextTestDate
		  ,[OwnerId] = COALESCE(@OwnerId,[OwnerId])
		  ,[CarStatusId] = @StatusId
		  ,[UpdatedDate] = GETDATE()
		  ,[AssignedCalibratorId] = @AssignedCalibrator
	 WHERE CarId = @CarId

	UPDATE [dbo].[CarsToEquipment]
	SET IsDeleted = 1
	WHERE CarId = @CarId

	INSERT [dbo].[CarsToEquipment](CarId, MeasurementDeviceId)
	SELECT DISTINCT @CarId, EquipmentId
	FROM #AssociatedEquipmentIDs
	COMMIT
END TRY

BEGIN CATCH
ROLLBACK
END CATCH
END