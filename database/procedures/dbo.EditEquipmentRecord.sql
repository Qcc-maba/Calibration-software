/*
    MBA-1060: refuse to change a device's MABA number to one another active device has.

    "[MabaID] = COALESCE(@MabaID,[MabaID])" accepted any number. That is how PROD's 796/832
    (copies of 18-172) became extra rows of 21-675, and how STAGE's test rows collided with
    10-30, 21-500, 21-540 and 21-675. The update sits inside a TRY whose CATCH turns every error
    into a result row ("ROLLBACK SELECT ERROR_MESSAGE()"), so even a unique-index violation would
    reach the screen as a success.

    Now, before the TRY, a NEW number that an active device already has raises error 51070 with
    the number and that device's ID. The app shows it as "MABA number already in use". Re-saving
    a device with its own unchanged number is never refused, even while duplicates still exist.
*/
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 24/03/2025
-- Description:	This SP should edit a record for the equipment management table. 
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-174
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[EditEquipmentRecord] 
 @ID INT
,@StatusId INT = NULL
,@EquipmentName NVARCHAR(255) = NULL
,@SerialNumber NVARCHAR(100) = NULL
,@CalibratorId INT = NULL
,@MainCategoryId INT = NULL
,@SecondaryCategoryId INT = NULL
,@NextCalibrationDate DATE = NULL
,@CalibrationDate DATE = NULL
,@CarId INT = NULL
,@LoggedInUserEmail NVARCHAR(50) = NULL
,@DisplayToCoordinator BIT = NULL
,@Manufacturer NVARCHAR(100) = NULL
,@MabaID NVARCHAR(50) = NULL
,@Channels NVARCHAR(100)=NULL
,@StabilityTime DECIMAL(16,8)=NULL
,@StabilitySize DECIMAL(16,8)=NULL
,@MainClassId INT = NULL

/*
EXEC dbo.EditEquipmentRecord
@ID = 1
,@DepartmentId = 1
,@StatusId = 39
,@EquipmentName = 'Test-update'
,@SerialNumber = '00-00-11'
,@CalibratorId = 1
,@MainCategoryId = 1
,@NextCalibrationDate = '2026-03-24'
,@CarId = '1'
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
SELECT 1 FROM [dbo].[MeasurementDevices]
WHERE ID = @ID
)
THROW 51000, 'Incorrect @ID', 1;

if @MainCategoryId IS NOT NULL AND NOT EXISTS (
SELECT 1 FROM [dbo].[MainCategories]
WHERE ID = @MainCategoryId 
)
THROW 51000, 'Incorrect @MainCategoryId', 1;

IF @StatusId IS NOT NULL AND @StatusId NOT IN (SELECT StatusId
				FROM [dbo].[Statuses] as s
				JOIN [dbo].[StatusesCategories] as c On s.[StatusCategoryId] = c.[StatusCategoryId]
				WHERE c.StatusDescriptionENG = 'MeasurementDeviceStatus' )
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

if @MabaID IS NOT NULL
   AND @MabaID <> (SELECT [MabaID] FROM [dbo].[MeasurementDevices] WHERE ID = @ID)
   AND EXISTS (SELECT 1 FROM [dbo].[MeasurementDevices] WHERE [MabaID] = @MabaID AND [IsDeleted] = 0 AND ID <> @ID)
BEGIN
	DECLARE @TakenById INT = (SELECT TOP (1) ID FROM [dbo].[MeasurementDevices]
	                          WHERE [MabaID] = @MabaID AND [IsDeleted] = 0 AND ID <> @ID ORDER BY ID);
	DECLARE @TakenMsg NVARCHAR(400) = CONCAT(N'MABA number ', @MabaID,
		N' is already used by active device ID ', @TakenById, N'. Each MABA number can belong to one device only.');
	THROW 51070, @TakenMsg, 1;
END


BEGIN TRY

	BEGIN TRAN
		
		DECLARE @PrevCarId INT = (SELECT TOP 1 CarId FROM [dbo].[CarsToEquipment] WHERE IsDeleted = 0 AND [MeasurementDeviceId] = @ID ORDER BY CreatedDate DESC)

		UPDATE [dbo].[MeasurementDevices]
		   SET [MainCategoryId] = COALESCE(@MainCategoryId,[MainCategoryId])
		      ,[SecondaryCategoryId] = COALESCE(@SecondaryCategoryId,[SecondaryCategoryId])
			  ,[MeasurementDeviceStatusId] = COALESCE(@StatusId,[MeasurementDeviceStatusId])
			  ,[Description] = COALESCE(@EquipmentName,[Description])
			  ,[SerialNumber] =COALESCE( @SerialNumber,[SerialNumber])
			  ,[CalibratorId] = COALESCE(@CalibratorId,[CalibratorId])
			  ,[MainClassId] = COALESCE(@MainClassId,[MainClassId])
			  ,[SubClassId] = NULL
			  ,[NextCalibration] = COALESCE(@NextCalibrationDate,[NextCalibration])
			  ,[UpdateDate] = GETDATE()
			  ,[UpdateUserID] = COALESCE(@LoggedInUserId,[UpdateUserID])
			  ,[DisplayToCoordinator] = COALESCE(@DisplayToCoordinator,[DisplayToCoordinator])
			  ,[Manufacturer] = COALESCE(@Manufacturer,[Manufacturer])
			  ,[MabaID] = COALESCE(@MabaID,[MabaID])
			  ,[CalibrationDate] = COALESCE(@CalibrationDate,[CalibrationDate])
			  ,[Channels] = COALESCE(@Channels,[Channels])
			  ,[StabilityTime] = COALESCE(@StabilityTime,[StabilityTime])
			  ,[StabilitySize] = COALESCE(@StabilitySize,[StabilitySize])

		 WHERE ID = @ID

		IF @PrevCarId IS NOT NULL 
			UPDATE [dbo].[CarsToEquipment]
				SET [CarId] = COALESCE(@CarId,[CarId])
				   ,[UpdateUserID] = @LoggedInUserId
				   ,[UpdatedDate] = GETDATE()
				   ,[IsDeleted] = IIF(@CarId IS NULL,1,0)
			WHERE [CarId] = @PrevCarId AND [MeasurementDeviceId] = @ID AND IsDeleted = 0
		
		IF @CarId IS NOT NULL
		 AND NOT EXISTS (SELECT 1 FROM [dbo].[CarsToEquipment] WHERE [CarId] = @CarId AND [MeasurementDeviceId] = @ID AND IsDeleted = 0) 
		INSERT [dbo].[CarsToEquipment]([CarId],[MeasurementDeviceId],[UpdateUserID])
		VALUES (@CarId,@ID,@LoggedInUserId)

	COMMIT
END TRY

BEGIN CATCH
	ROLLBACK SELECT ERROR_MESSAGE()
END CATCH
END

