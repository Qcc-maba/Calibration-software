/*
    11-MBA-1060-procedures - PROD (CalibratorProd) only. Step 1 of 3 for MBA-1060.

    Deploys four procedures, copied verbatim from database/procedures/ (regenerate this file
    if they change):
      dbo.GetMeasurementDevicesCorrections    station certificate load: one ACTIVE device per MabaID
      stg.MergeMeasurementDevicesCorrection   corrections sync: attach to the active device only
      dbo.CreateEquipmentRecord               a taken MABA number raises 51070 instead of silently nothing
      dbo.EditEquipmentRecord                 changing to a taken MABA number raises 51070

    Safe BEFORE the cleanup: none of them changes any result while duplicates still exist,
    except refusing a NEW collision. Run in SSMS on CalibratorProd as sa. Expect the last
    result to be one row: 4.

    Then step 2: database/data/Retire-DuplicateMeasurementDevices.sql (see RUNBOOK.md, MBA-1060).
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF DB_NAME() <> N'CalibratorProd'
BEGIN
    /* RAISERROR, not THROW: SSMS goes on to the next batch after an error, so the rest of the file is
       switched off with NOEXEC. Run SET NOEXEC OFF; afterwards, or open a new tab, before anything else. */
    DECLARE @WrongDb NVARCHAR(200) = CONCAT(N'Stopped, nothing changed: this script is for CalibratorProd, but the current database is ', DB_NAME(), N'. Run SET NOEXEC OFF; before anything else in this tab.');
    RAISERROR(@WrongDb, 16, 1);
    SET NOEXEC ON;
END;
GO

/* ==== dbo.GetMeasurementDevicesCorrections ==================================================== */
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 30/03/2025
-- Description:	Return corrections for measurment devices(history abd latest one)
-- JiraLink:
-- =============================================
/*
    MBA-1060: resolve the MabaID to ONE active device, deterministically.

    The station loads a master's certificate through this procedure (CalibrationRepository,
    @GetLatestVersionOnly = 1). It used to resolve the MabaID with
        SELECT @MeasurementDevicesId = md.ID ... WHERE md.MabaID = @MabaID GROUP BY md.ID
    which, when several rows share the MabaID, assigns whichever group SQL Server returns last,
    including a soft-deleted row. On PROD 21-242, 21-260 and 21-401 carry identical corrections on
    3-4 copies each, so the pick was arbitrary but harmless. Once the extra copies are retired
    (database/data/Retire-DuplicateMeasurementDevices.sql), a certificate saved later goes only
    onto the kept copy, because the save procedures filter IsDeleted = 0, and the old resolution
    could keep serving the stale one.

    Now: only IsDeleted = 0 devices that have active corrections, the lowest ID if more than one,
    and the latest version taken over active corrections only. Measured on PROD 2026-11-26: the
    latest version is the same whether deleted rows count or not for every MabaID (0 differ), and
    no device has only deleted corrections. So today the output changes for no MabaID.
*/
CREATE OR ALTER PROCEDURE [dbo].[GetMeasurementDevicesCorrections]
@MabaID NVARCHAR(50),
@GetLatestVersionOnly BIT = 0
/*
EXEC dbo.GetMeasurementDevicesCorrections
*/

AS

BEGIN

DECLARE @CorVersion INT, @MeasurementDevicesId INT

SELECT TOP (1) @MeasurementDevicesId = md.[ID]
FROM [dbo].[MeasurementDevices] as md
WHERE md.[MabaID] = @MabaID
  AND md.[IsDeleted] = 0
  AND EXISTS (SELECT 1 FROM [dbo].[MeasurementDevicesCorrections] as c
              WHERE c.[MeasurementDevicesId] = md.[ID] AND c.[IsDeleted] = 0)
ORDER BY md.[ID]

SELECT @CorVersion = MAX(mdc.CorVersion)
FROM [dbo].[MeasurementDevicesCorrections] as mdc
WHERE mdc.[MeasurementDevicesId] = @MeasurementDevicesId AND mdc.IsDeleted = 0


SELECT mdc.[ID]
      ,mdc.[Value1]
      ,mdc.[Value2]
      ,mdc.[Deviation]
      ,mdc.[Note]
      ,mdc.[MeasurementDevicesId]
      ,mdc.[MeasurementId]
      ,mdc.[UnitID]
      ,mdc.[CreatedDate]
      ,mdc.[CorVersion]
      ,mdc.[MainCategoryId] as  [DepartmentId]
      ,mdc.[Equation]
  FROM [dbo].[MeasurementDevicesCorrections] as mdc
  WHERE mdc.IsDeleted = 0 AND mdc.[MeasurementDevicesId] = @MeasurementDevicesId AND (@GetLatestVersionOnly = 0 OR mdc.[CorVersion] = @CorVersion)


END
GO

/* ==== stg.MergeMeasurementDevicesCorrection =================================================== */
/*
    MBA-1060: attach new corrections to the ACTIVE device only.

    The corrections sync (SSIS package MeasurmentDevicesSyncToAWS, which runs this procedure)
    joined the staging rows to dbo.MeasurementDevices on MabaID alone. Every row sharing a MabaID
    therefore got its own copy of each new correction: that is how 21-242 (19 rows), 21-260 (182)
    and 21-401 (9) came to carry identical certificates on 3-4 copies on PROD. Once the extra
    copies are retired (database/data/Retire-DuplicateMeasurementDevices.sql), the same join would
    keep feeding new corrections onto retired rows.

    Change: the corrections INSERT attaches each staging row to ONE device: the active one, or,
    when the MabaID has only retired rows, the lowest retired one. That way the row stays findable
    (the retire script's stranded-certificate step can move it), instead of landing with
    MeasurementDevicesId NULL, where the SourceId dedupe would never insert it again. A MabaID no
    row has gets NULL, as before. With duplicates still active it also stops inserting one copy
    per row. The MeasurementId update above it is left as it was: it writes the same value to
    every copy.
    Otherwise this is the definition deployed on PROD and STAGE (identical on both, 2026-11-26).
*/
CREATE OR ALTER PROCEDURE [stg].[MergeMeasurementDevicesCorrection]
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 25/12/2025
-- Description:	
-- JiraLink: 
-- =============================================
AS
BEGIN

SET NOCOUNT ON;

INSERT INTO [dbo].[Measurements]
           ([NameEn]
           ,[NameHe]
           ,[NoteEn]
           ,[NoteHe]
           ,[MainCategoryId]
           ,[IsDeleted]
           ,[UpdateUserID]
)
SELECT DISTINCT
 stg.ShortNameEn	
,stg.ShortNameHe	
,stg.MeasurementNameEn	
,stg.MeasurementNameHe	
,mc.ID
,0
,0
FROM [stg].[stg_MeasurementDevicesCorrections] as stg
JOIN [dbo].[MainCategories] as mc ON
        CASE stg.DepartmentHeb
            WHEN N'אלקטרוניקה' THEN N'אלקטרוניקה'
            WHEN N'טמפרטורה' THEN N'טמפרטורה ולחות'
            WHEN N'אורך וזווית' THEN N'אורך וזווית' 
            WHEN N'מסה' THEN N'מסה' 
        END = mc.MainCategoryName
LEFT JOIN [dbo].[Measurements] as dest ON dest.[NameEn] = stg.ShortNameEn
WHERE dest.[NameEn] IS NULL

;WITH cte
as
(
SELECT DISTINCT
stg.MabaID,
m.ID as MeasurementId
FROM [stg].[stg_MeasurementDevicesCorrections] as stg
JOIN [dbo].[Measurements] as m ON m.[NameEn] = stg.ShortNameEn
)
UPDATE md
SET MeasurementId = c.MeasurementId
FROM dbo.MeasurementDevices as md
JOIN cte as c ON md.MabaID = c.MabaID 
WHERE COALESCE(md.MeasurementId,0) <> COALESCE(c.MeasurementId,0)


INSERT INTO [dbo].[MeasurementDevicesCorrections]
           ([Value1]
           ,[Value2]
           ,[MeasurementDevicesId]
           ,[MeasurementId]
           ,[CorVersion]
           ,[MainCategoryId]
           ,[Equation]
           ,[CreatedDate]
           ,[IsDeleted]
           ,[UpdateUserID]
           ,[MeasurementDevicesCorrectionsSourceId]
           ,[Deviation])
SELECT 
 stg.RangeStart as [Value1]
,stg.RangeStop as [Value2]
,md.ID as [MeasurementDevicesId]
,m.ID as [MeasurementId]
,stg.CorVersion as [CorVersion]
,mc.ID as [MainCategoryId]
,stg.Value as [Equation]
,stg.DateAdded as [CreatedDate]
,0 as [IsDeleted]
,0 as [UpdateUserID]
,stg.[MeasurementDevicesCorrectionsSourceId]
,stg.[Deviation]
FROM [stg].[stg_MeasurementDevicesCorrections] as stg
JOIN [dbo].[MainCategories] as mc ON
        CASE stg.DepartmentHeb
            WHEN N'אלקטרוניקה' THEN N'אלקטרוניקה'
            WHEN N'טמפרטורה' THEN N'טמפרטורה ולחות'
            WHEN N'אורך וזווית' THEN N'אורך וזווית' 
            WHEN N'מסה' THEN N'מסה' 
        END = mc.MainCategoryName
JOIN [dbo].[Measurements] as m ON m.[NameEn] = stg.ShortNameEn
OUTER APPLY (SELECT TOP (1) d.[ID] FROM [dbo].[MeasurementDevices] as d
             WHERE d.MabaID = stg.MabaID ORDER BY d.IsDeleted, d.ID) as md
LEFT JOIN [dbo].[MeasurementDevicesCorrections] as dest ON stg.[MeasurementDevicesCorrectionsSourceId] = dest.[MeasurementDevicesCorrectionsSourceId]
WHERE dest.[MeasurementDevicesCorrectionsSourceId] IS NULL


UPDATE mdc
SET MeasurementDevicesId = md.ID
FROM [dbo].[MeasurementDevicesCorrections] as mdc 
JOIN [dbo].[MeasurementDevices] as md  ON md.ID = mdc.MeasurementDevicesId
WHERE COALESCE(mdc.MeasurementDevicesId,0) <> COALESCE(md.ID,0)


END
GO

/* ==== dbo.CreateEquipmentRecord =============================================================== */
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

    The CATCH now re-raises instead of "SELECT ERROR_MESSAGE(); ROLLBACK", so whatever fails inside
    the TRY (the index's 2601 when two users save the same number at once, a 1934, ...) reaches the
    app as an error, not as a result row the screen reads as success.
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
	/* MBA-1060: re-raise, so a failure (2601 from the unique index, 1934, ...) reaches the app
	   instead of coming back as an ordinary result row that the screen reads as success */
	IF @@TRANCOUNT > 0 ROLLBACK;
	THROW;
END CATCH

END
GO

/* ==== dbo.EditEquipmentRecord ================================================================= */
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

    The CATCH now re-raises instead of "ROLLBACK SELECT ERROR_MESSAGE()", so whatever fails inside
    the TRY (the index's 2601 when two users save the same number at once, a 1934, ...) reaches the
    app as an error, not as a result row the screen reads as success.
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
   AND NOT EXISTS (SELECT 1 FROM [dbo].[MeasurementDevices] WHERE ID = @ID AND [MabaID] = @MabaID)
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
	/* MBA-1060: re-raise, so a failure (2601 from the unique index, 1934, ...) reaches the app
	   instead of coming back as an ordinary result row that the screen reads as success */
	IF @@TRANCOUNT > 0 ROLLBACK;
	THROW;
END CATCH
END
GO

/* ---- Check: expect a single row reading 4 ------------------------------------------------------ */
SELECT COUNT(*) AS mba1060_procedures_expect_4
FROM sys.sql_modules AS m
JOIN sys.objects AS o ON o.object_id = m.object_id
JOIN sys.schemas AS s ON s.schema_id = o.schema_id
WHERE s.name + '.' + o.name IN ('dbo.GetMeasurementDevicesCorrections', 'stg.MergeMeasurementDevicesCorrection', 'dbo.CreateEquipmentRecord', 'dbo.EditEquipmentRecord')
  AND m.definition LIKE '%MBA-1060%'
  AND m.uses_quoted_identifier = 1;
GO
SET NOEXEC OFF;  -- harmless when the guard did not fire
GO
