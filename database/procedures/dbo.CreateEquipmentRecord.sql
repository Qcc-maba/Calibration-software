/*
    MBA-1060: refuse a MABA number that an active device already has, and say so.

    Before, "IF NOT EXISTS (... WHERE MabaID = @MabaID)" guarded the INSERT. A taken number
    therefore created nothing and returned nothing: the screen reported success and no device
    appeared. That check also counted soft-deleted rows, so a number whose device was deleted could
    never be used again, just as silently.

    Now a number held by an ACTIVE device raises error 51070 with the number and that device's ID,
    before the TRY (whose CATCH would turn it into a result row). The app shows it as "MABA number
    already in use". A number held only by deleted rows can be reused. This matches the unique
    index UX_MeasurementDevices_MabaID_Active (database/constraints), which is the backstop for
    any other writer.
*/
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 20/03/2025
-- Description:	This SP should edit a calendar event. It must take the event title, start time, end time, and a string with participant ids divided by comma.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-173
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[CreateEquipmentRecord]
 @StatusId INT = NULL
,@EquipmentName NVARCHAR(255) = NULL
,@SerialNumber NVARCHAR(100) = NULL
,@CalibratorId INT = NULL
,@MainCategoryId INT = NULL
,@SecondaryCategoryId INT = NULL
,@NextCalibrationDate DATE = NULL
,@CalibrationDate DATE = NULL
,@CarId INT = NULL
,@LoggedInUserEmail NVARCHAR(50) = NULL
,@DisplayToCoordinator BIT NULL = 1
,@Manufacturer NVARCHAR(100) =NULL
,@MabaID NVARCHAR(50) = NULL
,@Channels NVARCHAR(100) = NULL
,@StabilityTime DECIMAL(16,8) = NULL
,@StabilitySize DECIMAL(16,8) = NULL
,@MainClassId INT = NULL
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

if @MabaID IS NOT NULL AND EXISTS (
SELECT 1 FROM [dbo].[MeasurementDevices] WHERE [MabaID] = @MabaID AND [IsDeleted] = 0
)
BEGIN
	DECLARE @TakenById INT = (SELECT TOP (1) ID FROM [dbo].[MeasurementDevices]
	                          WHERE [MabaID] = @MabaID AND [IsDeleted] = 0 ORDER BY ID);
	DECLARE @TakenMsg NVARCHAR(400) = CONCAT(N'MABA number ', @MabaID,
		N' is already used by active device ID ', @TakenById, N'. Each MABA number can belong to one device only.');
	THROW 51070, @TakenMsg, 1;
END


IF NOT EXISTS (SELECT 1 FROM [dbo].[MeasurementDevices] WHERE [MabaID] = @MabaID AND [IsDeleted] = 0)
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
				   ,[Manufacturer]
				   ,[CalibrationDate]
				   ,[Channels]
				   ,[StabilityTime]
				   ,[StabilitySize]
				   )
		VALUES 
		(
		 @MabaID
		,@MainCategoryId
		,@SecondaryCategoryId
		,@StatusId
		,@EquipmentName
		,@SerialNumber
		,@CalibratorId
		,@MainClassId
		,NULL
		,NULLIF(@NextCalibrationDate,'1900-01-01')
		,@LoggedInUserId
		,@SourceId
		,@DisplayToCoordinator
		,@Manufacturer
		,@CalibrationDate
		,@Channels
		,@StabilityTime
		,@StabilitySize
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

