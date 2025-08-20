-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/03/2025
-- Description:	This SP should edit a calendar event. It must take the event title, start time, end time, and a string with participant ids divided by comma.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-183
-- =============================================
CREATE   PROCEDURE [dbo].[CreateCarRecord]
@LicenseNumber NVARCHAR(50),
@Model NVARCHAR(50),
@NumberOfSeats TINYINT,
@Status INT,
@Owner INT = NULL,
@AssignedCalibrator INT = NULL,
@TreatmentPeriod INT,
@NextTreatment DATE = NULL,
@NextTestDate DATE = NULL,
@AssociatedEquipmentIDs NVARCHAR(200) = NULL,
@LoggedInUserEmail NVARCHAR(50) = NULL
/*
EXEC [dbo].[CreateCarRecord] 
   @LicenseNumber = '090-001-003'
  ,@Model = 'Tesla Truck'
  ,@NumberOfSeats = 5
  ,@Status = 35
  ,@TreatmentPeriod = 30000
  ,@NextTreatment = '2025-03-19'
  ,@NextTestDate = '2026-03-19'
  ,@AssociatedEquipmentIDs = '1'
*/

AS
BEGIN

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT = (SELECT ID FROM [dbo].[Users] WHERE Email = @LoggedInUserEmail) 

DROP TABLE IF EXISTS #AssociatedEquipmentIDs
CREATE TABLE #AssociatedEquipmentIDs
(
EquipmentId INT
)

INSERT #AssociatedEquipmentIDs(EquipmentId)
SELECT Value FROM dbo.ParseCSVToTable(@AssociatedEquipmentIDs)

--- Check equipment id's is valid
if EXISTS (
SELECT 1 FROM #AssociatedEquipmentIDs as t
JOIN [dbo].[MeasurementDevices] as e ON e.ID = t.EquipmentId
JOIN [dbo].[Statuses] as s ON s.StatusId = e.MeasurementDeviceStatusId
WHERE  COALESCE(s.StatusDescriptionENG,'Available') <> 'Available'
)
THROW 51000, 'Incorrect or inactive equipment were found in list or equipment not in available state.', 1;

if EXISTS (
SELECT 1 FROM [dbo].[Cars] as c
WHERE c.Model = @Model AND c.LicenseNumber = @LicenseNumber AND c.IsDeleted = 0
)
THROW 51000, 'Car already exists', 1;

--- Check if all users are valid
if EXISTS (
SELECT 1 FROM [dbo].[Users] as u
WHERE (u.ID = @AssignedCalibrator)  AND u.IsActive = 0
) AND @AssignedCalibrator IS NOT NULL
THROW 51000, 'Incorrect or inactive user assigned as calibrator.', 1;

if EXISTS (
SELECT 1 FROM [dbo].[Users] as u
WHERE (u.ID = @Owner)  AND u.IsActive = 0
) and @Owner IS NOT NULL
THROW 51000, 'Incorrect or inactive user assigned as owner.', 1;

IF @Status NOT IN (SELECT StatusId
				FROM [dbo].[Statuses] as s
				JOIN [dbo].[StatusesCategories] as c On s.[StatusCategoryId] = c.[StatusCategoryId]
				WHERE c.StatusDescriptionENG = 'CarStatus' )
THROW 51000, 'Incorrect status was assigned.', 1;

DECLARE @CarId INT

BEGIN TRY
	BEGIN TRANSACTION

	INSERT INTO [dbo].[Cars]
			   ([Model]
			   ,[LicenseNumber]
			   ,[Seats]
			   ,[TreatmentPeriod]
			   ,[NextTreatmentDate]
			   ,[NextYearlyTestDate]
			   ,[AssignedCalibratorId]
			   ,[OwnerId]
			   ,[CarStatusId]
			   ,[UpdateUserID]
			   )
		 VALUES
		   (
		   @Model,
		   @LicenseNumber,
		   @NumberOfSeats,
		   @TreatmentPeriod,
		   @NextTreatment,
		   @NextTestDate,
		   @AssignedCalibrator,
		   @Owner,
		   @Status,
		   @LoggedInUserId
		   )

	SELECT @CarId = SCOPE_IDENTITY()

	INSERT [dbo].[CarsToEquipment]([CarId],[MeasurementDeviceId],[UpdateUserID])
	SELECT DISTINCT @CarId, [EquipmentId], @LoggedInUserId FROM #AssociatedEquipmentIDs

	COMMIT
END TRY

BEGIN CATCH
ROLLBACK
END CATCH

END