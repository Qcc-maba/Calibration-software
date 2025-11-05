-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 20/03/2025
-- Description:	This SP should edit a calendar event. It must take the event title, start time, end time, and a string with participant ids divided by comma.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-173
-- =============================================
CREATE   PROCEDURE [dbo].[CreateEquipmentRecord]
 @StatusId INT = NULL
,@EquipmentName NVARCHAR(255) = NULL
,@SerialNumber NVARCHAR(100) = NULL
,@CalibratorId INT = NULL
,@MainCategoryId INT = NULL
,@SecondaryCategoryId INT = NULL
,@NextCalibrationDate DATE = NULL
,@CarId INT = NULL
,@LoggedInUserEmail NVARCHAR(50) = NULL
,@DisplayToCoordinator BIT NULL = 1

/*
EXEC dbo.CreateEquipmentRecord
 @StatusId = 39
,@EquipmentName = 'Test2'
,@SerialNumber = '00-00-11'
,@CalibratorId = 38
,@MainCategoryId = 1
,@NextCalibrationDate = '2025-03-24'
,@CarId = 1
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
SELECT 1 FROM Cars WHERE CarId = @CarId
)
THROW 51000, 'Incorrect car was assigned.', 1;

BEGIN TRY

	BEGIN TRAN

		INSERT INTO [dbo].[MeasurementDevices]
				   ([MabaID]
				   ,[MainCategoryId]
				   ,[SecondaryCategoryId]
				   ,[MeasurementDeviceStatusId]
				   ,[Description]
				   ,[SerialNumber]
				   ,[CalibratorId]
				   ,[MainClassId]	
				   ,[SubClassId]
				   ,[NextCalibration]
				   ,[UpdateUserID]
				   ,[SourceId]
				   ,[DisplayToCoordinator]
				   )
		VALUES 
		(
		''
		,@MainCategoryId
		,@SecondaryCategoryId
		,@StatusId
		,@EquipmentName
		,@SerialNumber
		,@CalibratorId
		,NULL
		,NULL
		,NULLIF(@NextCalibrationDate,'1900-01-01')
		,@LoggedInUserId
		,@SourceId
		,@DisplayToCoordinator
		)
		DECLARE @EquipmentId INT
		SELECT @EquipmentId = SCOPE_IDENTITY()
		
		IF @CarId IS NOT NULL
			INSERT INTO [dbo].[CarsToEquipment]
					   ([CarId]
					   ,[MeasurementDeviceId]
					   ,[UpdateUserID])

			SELECT 
				@CarId ,
				@EquipmentId,
				@LoggedInUserId
	COMMIT
END TRY

BEGIN CATCH
	SELECT ERROR_MESSAGE()
	ROLLBACK 
END CATCH

END