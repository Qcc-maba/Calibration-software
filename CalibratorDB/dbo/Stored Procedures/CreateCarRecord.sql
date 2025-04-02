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
@NextTreatment DATE,
@NextTestDate DATE,
@AssociatedEquipmentIDs NVARCHAR(200)

/*
EXEC [dbo].[CreateCarRecord] 
   @LicenseNumber = '000-001-003'
  ,@Model = 'Tesla Truck'
  ,@NumberOfSeats = 5
  ,@Status = 26
  ,@TreatmentPeriod = 30000
  ,@NextTreatment = '2025-03-19'
  ,@NextTestDate = '2026-03-19'
  ,@AssociatedEquipmentIDs = '1'
*/

AS
BEGIN

SET NOCOUNT ON;

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
LEFT JOIN [dbo].[CalibEquipments] as e ON e.ID = t.EquipmentId
WHERE  e.ID IS NULL OR e.StatusId <> 30
)
THROW 51000, 'Incorrect or inactive equipment were found in list or equipment not in available state.', 1;

if EXISTS (
SELECT 1 FROM [dbo].[Cars] as c
WHERE c.Model = @Model AND c.LicenseNumber = @LicenseNumber
)
THROW 51000, 'Car already exists', 1;

--- Check if all users are valid
if NOT EXISTS (
SELECT 1 FROM [dbo].[Users] as u
WHERE (u.ID = @AssignedCalibrator)  AND u.IsActive = 1
) AND @AssignedCalibrator IS NOT NULL
THROW 51000, 'Incorrect or inactive user assigned as calibrator.', 1;

if NOT EXISTS (
SELECT 1 FROM [dbo].[Users] as u
WHERE (u.ID = @Owner)  AND u.IsActive = 1
) and @Owner IS NOT NULL
THROW 51000, 'Incorrect or inactive user assigned as owner.', 1;

IF @Status NOT IN (SELECT StatusId
				FROM [dbo].[Statuses] as s
				JOIN [dbo].[StatusesCategories] as c On s.[StatusCategoryId] = c.[StatusCategoryId]
				WHERE c.StatusDescriptionENG = 'CarStatus' )
THROW 51000, 'Incorrect status was assigned.', 1;

DECLARE @CarId INT

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
	   @Status
	   )

SELECT @CarId = SCOPE_IDENTITY()

INSERT [dbo].[CarsToEquipment]([CarId],[EquipmentId])
SELECT DISTINCT @CarId, [EquipmentId] FROM #AssociatedEquipmentIDs

COMMIT


END