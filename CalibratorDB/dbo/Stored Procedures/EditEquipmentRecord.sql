-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 24/03/2025
-- Description:	This SP should edit a record for the equipment management table. 
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-174
-- =============================================
CREATE   PROCEDURE [dbo].[EditEquipmentRecord]
 @ID INT
,@DepartmentId INT
,@StatusId INT
,@EquipmentName NVARCHAR(255)
,@SerialNumber NVARCHAR(100) = NULL
,@CalibratorId INT = NULL
,@MainCategory NVARCHAR(100) = NULL
,@NextCalibrationDate DATE = NULL
,@CarId INT = NULL

/*
EXEC dbo.EditEquipmentRecord
@ID = 1
,@DepartmentId = 1
,@StatusId = 43
,@EquipmentName = 'Test'
,@SerialNumber = '00-00-11'
,@CalibratorId = 107
,@MainCategory = 'Test category'
,@NextCalibrationDate = '2025-03-24'
,@CarId = ''
*/

AS
BEGIN

SET NOCOUNT ON;

if NOT EXISTS (
SELECT 1 FROM dbo.CalibEquipments
WHERE ID = @ID
)
THROW 51000, 'Incorrect @ID', 1;

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


UPDATE [dbo].[CalibEquipments]
   SET [DepartmentId] = @DepartmentId
      ,[StatusId] = @StatusId
      ,[EquipmentName] = @EquipmentName
      ,[SerialNumber] = @SerialNumber
      ,[CalibratorId] = @CalibratorId
      ,[MainCategory] = @MainCategory
      ,[NextCalibrationDate] = NULLIF(@NextCalibrationDate,'1900-01-01')
      ,[CarId] = @CarId
      ,[UpdatedDate] = GETDATE()
 WHERE ID = @ID

END