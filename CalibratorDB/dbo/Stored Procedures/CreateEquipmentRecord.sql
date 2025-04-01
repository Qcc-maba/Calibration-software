-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 20/03/2025
-- Description:	This SP should edit a calendar event. It must take the event title, start time, end time, and a string with participant ids divided by comma.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-173
-- =============================================
CREATE   PROCEDURE [dbo].[CreateEquipmentRecord]
 @DepartmentId INT
,@StatusId INT
,@EquipmentName NVARCHAR(255)
,@SerialNumber NVARCHAR(100) = NULL
,@CalibratorId INT = NULL
,@MainCategory NVARCHAR(100) = NULL
,@NextCalibrationDate DATE
,@CarId INT = NULL

/*
EXEC dbo.CreateEquipmentRecord
 @DepartmentId = 1
,@StatusId = 43
,@EquipmentName = 'Test'
,@SerialNumber = '00-00-11'
,@CalibratorId = 107
,@MainCategory = 'Test category'
,@NextCalibrationDate = '2025-03-24'
,@CarId = 1
*/

AS
BEGIN

SET NOCOUNT ON;

if NOT EXISTS (
SELECT 1 FROM dbo.Departments
WHERE ID = @DepartmentId
)
THROW 51000, 'Incorrect @DepartmentId', 1;

if NOT EXISTS (
SELECT 1 FROM dbo.Departments
WHERE ID = @DepartmentId
)
THROW 51000, 'Incorrect @StatusId', 1;

IF @StatusId NOT IN (SELECT StatusId
				FROM [dbo].[Statuses] as s
				JOIN [dbo].[StatusesCategories] as c On s.[StatusCategoryId] = c.[StatusCategoryId]
				WHERE c.StatusDescriptionENG = 'CalibrationEquipmentStatus' )
THROW 51000, 'Incorrect status was assigned.', 1;

if @CalibratorId IS NOT NULL AND NOT EXISTS (
SELECT 1 FROM [dbo].[Users] as u
WHERE (u.ID = @CalibratorId)  AND u.IsActive = 1
)
THROW 51000, 'Incorrect or inactive user assigned as calibrator.', 1;

if @CarId IS NOT NULL AND NOT EXISTS (
SELECT 1 FROM Cars WHERE CarId = @CarId
)
THROW 51000, 'Incorrect car was assigned.', 1;

INSERT INTO [dbo].[CalibEquipments]
           ([DepartmentId]
           ,[StatusId]
           ,[EquipmentName]
           ,[SerialNumber]
           ,[CalibratorId]
           ,[MainCategory]
           ,[NextCalibrationDate]
           ,[CarId]
		   )
VALUES 
(
 @DepartmentId
,@StatusId
,@EquipmentName
,@SerialNumber
,@CalibratorId
,@MainCategory
,@NextCalibrationDate
,@CarId
)
END