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
,@MainCategoryId INT
,@SecondaryCategoryId INT = NULL
,@NextCalibrationDate DATE = NULL
,@CarId INT = NULL
,@LoggedInUserEmail NVARCHAR(50) = NULL

/*
EXEC dbo.EditEquipmentRecord
@ID = 2526
,@DepartmentId = 1
,@StatusId = 39
,@EquipmentName = 'Test-update'
,@SerialNumber = '00-00-11'
,@CalibratorId = 107
,@MainCategoryId = 2
,@NextCalibrationDate = '2026-03-24'
,@CarId = '1'
*/

AS
BEGIN

SET NOCOUNT ON;

DECLARE @Userid INT = 0
IF @LoggedInUserEmail IS NOT NULL
SELECT @Userid = ID FROM dbo.Users WHERE Email = @LoggedInUserEmail

if NOT EXISTS (
SELECT 1 FROM [dbo].[MeasurementDevices]
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

if @CalibratorId IS NOT NULL AND EXISTS (
SELECT 1 FROM [dbo].[Users] as u
WHERE (u.ID = @CalibratorId)  AND u.IsActive = 0
)
THROW 51000, 'Incorrect or inactive user assigned as calibrator.', 1;

if @CarId IS NOT NULL AND NOT EXISTS (
SELECT 1 FROM Cars WHERE CarId = @CarId and IsDeleted = 0
)
THROW 51000, 'Incorrect car was assigned.', 1;

BEGIN TRY

	BEGIN TRAN
		
		DECLARE @PrevCarId INT = (SELECT TOP 1 CarId FROM [dbo].[CarsToEquipment] WHERE IsDeleted = 0 AND [MeasurementDeviceId] = @ID ORDER BY CreatedDate DESC)

		UPDATE [dbo].[MeasurementDevices]
		   SET [DepartmentId] = @DepartmentId
			  ,[MeasurementDeviceStatusId] = @StatusId
			  ,[Description] = @EquipmentName
			  ,[SerialNumber] = @SerialNumber
			  ,[CalibratorId] = @CalibratorId
			  ,[MainClassId] = @MainCategoryId
			  ,[SubClassId] = @SecondaryCategoryId
			  ,[NextCalibration] = @NextCalibrationDate
			  ,[UpdateDate] = GETDATE()
			  ,[UpdateUserID] = @Userid
		 WHERE ID = @ID

		IF @PrevCarId IS NOT NULL 
			UPDATE [dbo].[CarsToEquipment]
				SET [CarId] = COALESCE(@CarId,[CarId])
				   ,[UpdateUserID] = @Userid
				   ,[UpdatedDate] = GETDATE()
				   ,[IsDeleted] = IIF(@CarId IS NULL,1,0)
			WHERE [CarId] = @PrevCarId AND [MeasurementDeviceId] = @ID AND IsDeleted = 0
		
		IF @CarId IS NOT NULL
		 AND NOT EXISTS (SELECT 1 FROM [dbo].[CarsToEquipment] WHERE [CarId] = @CarId AND [MeasurementDeviceId] = @ID AND IsDeleted = 0) 
		INSERT [dbo].[CarsToEquipment]([CarId],[MeasurementDeviceId],[UpdateUserID])
		VALUES (@CarId,@ID,@Userid)

	COMMIT
END TRY

BEGIN CATCH
	ROLLBACK SELECT ERROR_MESSAGE()
END CATCH
END