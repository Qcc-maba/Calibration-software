/*  TRANCHE B - procedures that exist on PROD with a different body.
    These CHANGE existing behaviour. Deploy after tranche A.
    Every one is CREATE OR ALTER, so re-running is safe.  */

/* ================= dbo.AddCalibrationCycle ================= */
CREATE OR ALTER PROCEDURE [dbo].[AddCalibrationCycle]
@UserEmail NVARCHAR(50),
@OrderDetailsItemId INT,
@CalibrationCycleStartDate DATETIME2(0),
@CalibrationCycleEndDate DATETIME2(0),
@CalibrationCycleName NVARCHAR(200),
@UnitId INT,
@TestedValue DECIMAL(18,6),
@SpecificationReferenceIds NVARCHAR(100),
@CalibrationCycleStatusId INT = NULL,
@CalibrationCycleNameStatusId INT = NULL
AS
BEGIN
SET NOCOUNT ON;

DECLARE @UserId INT = (SELECT ID FROM [dbo].[Users] WHERE Email = @UserEmail) 

IF EXISTS (SELECT 1 FROM [dbo].[CalibrationCycles] WHERE [OrderDetailsItemId] = @OrderDetailsItemId AND [CalibrationCycleStartDate] = @CalibrationCycleStartDate) 
BEGIN
    UPDATE [dbo].[CalibrationCycles]
    SET [CalibrationCycleEndDate] = @CalibrationCycleEndDate,
        [CalibrationCycleStatusId] = @CalibrationCycleStatusId,
        [CalibrationCycleName] = @CalibrationCycleName,
        [UnitId] = @UnitId,
        [TestedValue] = @TestedValue,
        [SpecificationReferenceIds] = @SpecificationReferenceIds,
        [CalibrationCycleNameStatusId] = @CalibrationCycleNameStatusId,
        [IsDeleted] = 0,
        [UpdatedDate] = GETDATE(),
        [UpdateUserID] = @UserId
    WHERE [OrderDetailsItemId] = @OrderDetailsItemId AND [CalibrationCycleStartDate] = @CalibrationCycleStartDate
END
ELSE
BEGIN
    INSERT INTO [dbo].[CalibrationCycles]
               ([OrderDetailsItemId]
               ,[CalibrationCycleStartDate]
               ,[CalibrationCycleEndDate]
               ,[CalibrationCycleStatusId]
               ,[CreatedUserID]
               ,[CalibrationCycleName]
               ,[UnitId]
               ,[TestedValue]
               ,[SpecificationReferenceIds]
               ,[CalibrationCycleNameStatusId]
               )
         VALUES
               (@OrderDetailsItemId,
                @CalibrationCycleStartDate,
                @CalibrationCycleEndDate,
                @CalibrationCycleStatusId,
                @UserId,
                @CalibrationCycleName,
                @UnitId,
                @TestedValue,
                @SpecificationReferenceIds,
                @CalibrationCycleNameStatusId
                )
END
END
GO

/* ================= dbo.AssignCalibrationEnvironmentalConditions ================= */
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 07/01/2026
-- Description:	Assign environmental conditions for calibrated device
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-478
--Json example
--'
--[
--  {"OrderDetailsItemId": 1254,"MeasurementDeviceUnitId": 12, "NominalValue": 30,"Tolerance": 12.54,"MinToleranceBorder": 1.54,"MaxToleranceBorder": 1.54},
--  {"OrderDetailsItemId": 1255,"MeasurementDeviceUnitId": 10,"NominalValue": 33,"Tolerance": 1.54,"MinToleranceBorder": 1.54,"MaxToleranceBorder": 1.54 }
--]'
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[AssignCalibrationEnvironmentalConditions]
@ConditionsJson NVARCHAR(MAX),
@LoggedInUserEmail NVARCHAR(50),
@IsDelete BIT = NULL

AS

BEGIN

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d


	MERGE INTO [dbo].[CalibrationEnvironmentalConditions] AS dest
	USING (
		SELECT 
			OrderDetailsItemId,
			MeasurementDeviceUnitId,
			NominalValue,
			Tolerance,
			MinToleranceBorder,
			MaxToleranceBorder
		FROM OPENJSON (@ConditionsJson) WITH (
			OrderDetailsItemId INT '$.OrderDetailsItemId',
			MeasurementDeviceUnitId INT'$.MeasurementDeviceUnitId',
			NominalValue DECIMAL(18,6) '$.NominalValue',
			Tolerance DECIMAL(18,6) '$.Tolerance',
			MinToleranceBorder DECIMAL(18,6) '$.MinToleranceBorder',
			MaxToleranceBorder DECIMAL(18,6) '$.MaxToleranceBorder'
		)
		) AS source
		ON dest.[OrderDetailsItemId] = source.[OrderDetailsItemId]
			AND dest.[MeasurementDeviceUnitId] = source.[MeasurementDeviceUnitId]
	WHEN MATCHED
		THEN
			UPDATE
			SET  dest.[NominalValue] = source.[NominalValue]
				,dest.[Tolerance] = source.[Tolerance]
				,dest.[MinToleranceBorder] = source.[MinToleranceBorder]
				,dest.[MaxToleranceBorder] = source.[MaxToleranceBorder]
				,dest.[UpdatedDate] = GETDATE()
				,dest.[UpdateUserID] = @LoggedInUserId
				,dest.[IsDeleted] = IIF(@IsDelete IS NULL, 0, 1)
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				[OrderDetailsItemId]
				,[MeasurementDeviceUnitId]
				,[NominalValue]
				,[Tolerance]
				,[MinToleranceBorder]
				,[MaxToleranceBorder]
				,[CreateDate]
				,[UpdateUserID]
				)
			VALUES (
				source.[OrderDetailsItemId]
				,source.[MeasurementDeviceUnitId]
				,source.[NominalValue]
				,source.[Tolerance]
				,source.[MinToleranceBorder]
				,source.[MaxToleranceBorder]
				,GETDATE()
				,@LoggedInUserId
				);

END
GO

/* ================= dbo.AssignCarToOrder ================= */
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/03/2025
-- Description:	This SP should assign a car to a specific order. It should return the status of the operation.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-182
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[AssignCarToOrder]
@CarID INT,
@OrderNumber NCHAR(12),
@Date DATE,
@QuartersOfDay NVARCHAR(10),
@LoggedInUserEmail NVARCHAR(100) = NULL
--EXEC dbo.AssignCarToOrder @CarID = 3,@OrderNumber = 'LA25101669',@Date = '2025-04-11',@QuartersOfDay ='0,1,2,3'

AS
BEGIN

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

DROP TABLE IF EXISTS #QuartersOfDay
CREATE TABLE #QuartersOfDay
(
QuarterId INT
)

INSERT #QuartersOfDay(QuarterId)
SELECT Value FROM dbo.ParseCSVToTable(@QuartersOfDay)

if (SELECT SUM(QuarterId) FROM #QuartersOfDay) > 6
THROW 51000, 'Incorrect values passed for quaters.', 1;

DECLARE @OrderWorkPlanId INT
SELECT @OrderWorkPlanId =  o.OrderWorkPlanId FROM [dbo].[OrderWorkPlans] as o 
WHERE o.OrderNumber = @OrderNumber AND o.IsCancelled = 0
IF @OrderWorkPlanId IS NULL
THROW 51000, 'Incorrect or not active order number passed.', 1;

if NOT EXISTS (
SELECT 1 FROM dbo.Cars as c
WHERE c.CarId = @CarID
)
THROW 51000, 'Incorrect car id passed.', 1;

DECLARE 
@part0db BIT,
@part1db BIT,
@part2db BIT,
@part3db BIT,
@exists BIT

SELECT  
    @part0db = MAX(CASE WHEN QuarterId = 0 THEN 1 ELSE NULL END),
    @part1db = MAX(CASE WHEN QuarterId = 1 THEN 1 ELSE NULL END),
    @part2db = MAX(CASE WHEN QuarterId = 2 THEN 1 ELSE NULL END),
    @part3db = MAX(CASE WHEN QuarterId = 3 THEN 1 ELSE NULL END)
FROM #QuartersOfDay;

SELECT  @part0db =  COALESCE(@part0db,AssignQuater0),
		@part1db =  COALESCE(@part1db,AssignQuater1),
		@part2db =  COALESCE(@part2db,AssignQuater2),
		@part3db =  COALESCE(@part3db,AssignQuater3),
		@exists = 1
FROM [dbo].[CarsToOrder] as cto
WHERE cto.CarId = @CarID AND cto.OrderWorkPlanId = @OrderWorkPlanId 
		AND cto.AssignDate = @Date AND cto.IsDeleted = 0

BEGIN TRY
	BEGIN TRAN
		IF @exists IS NULL

		INSERT [dbo].[CarsToOrder](CarId,OrderWorkPlanId,AssignDate,AssignQuater0,AssignQuater1,AssignQuater2,AssignQuater3,UpdateUserID)
		SELECT @CarID as CarID, 
			   @OrderWorkPlanId as OrderWorkPlanId,
			   @Date as AssignDate,
			   @part0db as AssignQuater0,
			   @part1db as AssignQuater1,
			   @part2db as AssignQuater2,
			   @part3db as AssignQuater3,
			   @LoggedInUserId


		ELSE

		UPDATE [dbo].[CarsToOrder]
		SET AssignQuater0 = @part0db,
			AssignQuater1 = @part1db,
			AssignQuater2 = @part2db,
			AssignQuater3 = @part3db,
			UpdatedDate = GETDATE(),
			UpdateUserID = @LoggedInUserId
		WHERE CarId = @CarID AND OrderWorkPlanId = @OrderWorkPlanId 
				AND AssignDate = @Date AND IsDeleted = 0
		
		IF EXISTS (SELECT 1 FROM [dbo].[MeasurementDevicesToOrderHeaders] WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId IS NULL AND AssigmentDate IS NULL AND IsDeleted = 0)
			UPDATE [dbo].[MeasurementDevicesToOrderHeaders]
			SET CarId = @CarID,
				AssigmentDate = @Date
			WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId IS NULL AND AssigmentDate IS NULL
		
		IF NOT EXISTS (SELECT 1 FROM [dbo].[MeasurementDevicesToOrderHeaders] WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId = @CarID AND AssigmentDate = @Date AND IsDeleted = 0)
			INSERT INTO [dbo].[MeasurementDevicesToOrderHeaders]
					   ([OrderWorkPlanId]
					   ,[MeasurementDeviceId]
					   ,[CreatedByUserId]
					   ,[AssigmentDate]
					   ,[CarId])

			SELECT TOP 1 WITH TIES
					@OrderWorkPlanId,
					[MeasurementDeviceId],
					@LoggedInUserId,
					@Date,
					@CarID
			FROM [dbo].[MeasurementDevicesToOrderHeaders] 
			WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId = @CarID AND IsDeleted = 0
			ORDER BY RANK() OVER(PARTITION BY OrderWorkPlanId ORDER BY AssigmentDate)

		IF EXISTS (SELECT 1 FROM [dbo].[CalibratorsToWorkPlan] WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId IS NULL AND AssigmentDate IS NULL AND IsDeleted = 0)
			UPDATE [dbo].[CalibratorsToWorkPlan]
			SET CarId = @CarID,
				AssigmentDate = @Date
			WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId IS NULL AND AssigmentDate IS NULL

		IF NOT EXISTS (SELECT 1 FROM [dbo].[CalibratorsToWorkPlan] WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId = @CarID AND AssigmentDate = @Date AND IsDeleted = 0)
			INSERT INTO [dbo].[CalibratorsToWorkPlan]
					   ([OrderWorkPlanId]
					   ,[CalibratorId]
					   ,[UpdateUserID]
					   ,[AssigmentDate]
					   ,[CarId])

			SELECT TOP 1 WITH TIES
					@OrderWorkPlanId,
					[CalibratorId],
					@LoggedInUserId,
					@Date,
					@CarID
			FROM [dbo].[CalibratorsToWorkPlan] 
			WHERE OrderWorkPlanId = @OrderWorkPlanId AND CarId = @CarID AND IsDeleted = 0
			ORDER BY RANK() OVER(PARTITION BY OrderWorkPlanId ORDER BY AssigmentDate)

	COMMIT
END TRY

BEGIN CATCH
	ROLLBACK
END CATCH

/*
UPDATE [dbo].[OrderWorkPlans]
SET AssigmentDate = @Date
WHERE OrderNumber = @OrderNumber
*/

END
GO

/* ================= dbo.AssignMeasurmentDevicesToCalibrator ================= */
/*
    dbo.AssignMeasurmentDevicesToCalibrator
    ---------------------------------------------------------------------------------------------
    Original author: Eduard Kudlaiev, 02/07/2025
    Assigns a logger + sensor + channel combination to a calibrator.

    MBA-902 (2026-08-24): pressing refresh in the logger popup wiped the sensor's channel
    assignments. Two defects, both in how @ChannelNumbers was turned into #Channels.

      1. STRING_SPLIT('', ',') returns ONE row holding an empty string, and CAST('' AS INT) is 0.
         An empty parameter therefore inserted a phantom assignment to channel 0. Five such rows
         were found on STAGE.

      2. The final UPDATE marks every already-assigned channel that is not in #Channels as deleted.
         That is right when the calibrator genuinely removed a channel, but an empty list made it
         delete all of them at once - 11 rows in the same second on 2026-07-15.

    Fixed by ignoring blank and non-numeric entries when building #Channels, and by treating an
    empty list as "I have nothing to say about the channels" rather than "remove them all".
    Deliberate removal has its own procedure, DeleteCalibratorSensorChannelAssignment.
*/
CREATE OR ALTER PROCEDURE [dbo].[AssignMeasurmentDevicesToCalibrator]
@LoggedInUserEmail NVARCHAR(100),
@LoggerMeasurementDeviceId INT,
@FlowRate NVARCHAR(20),
@Interval INT,
@CommunicationProtocol NVARCHAR(100),
@CommunicationDetails NVARCHAR(100),
@SensorMeasurementDeviceId INT,
@UnitId INT NULL,
@WorkRangeUnitId INT NULL,
@ChannelNumbers NVARCHAR(MAX)

AS
BEGIN

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

if NOT EXISTS (
SELECT 1 FROM dbo.MeasurementDevices as md
JOIN dbo.MeasurementDevicesMainClasses as mc ON md.MainClassId = mc.Id
WHERE mc.NameEnglish = 'Data logger' AND md.ID = @LoggerMeasurementDeviceId AND md.IsDeleted = 0
)
THROW 51000, 'Incorrect @LoggerMeasurementDeviceId passed. Device is not data logger or inactive.', 1;

if NOT EXISTS (
SELECT 1 FROM dbo.MeasurementDevices as md
JOIN dbo.MeasurementDevicesMainClasses as mc ON md.MainClassId = mc.Id
WHERE mc.NameEnglish = 'Sensor' AND md.ID = @SensorMeasurementDeviceId AND md.IsDeleted = 0
)
THROW 51000, 'Incorrect @SensorMeasurementDeviceId passed. Device is not sensor or inactive.', 1;

DROP TABLE IF EXISTS #Channels

CREATE TABLE #Channels
(
ChannelNumber INT
)

/* MBA-902: blanks and stray separators must not become channel 0. */
INSERT #Channels(ChannelNumber)
SELECT DISTINCT CAST(LTRIM(RTRIM(value)) AS INT)
FROM STRING_SPLIT(@ChannelNumbers,',')
WHERE LTRIM(RTRIM(value)) <> ''
      AND LTRIM(RTRIM(value)) NOT LIKE '%[^0-9]%'

DECLARE @HasChannels BIT = IIF(EXISTS (SELECT 1 FROM #Channels), 1, 0)

BEGIN TRY
	
	BEGIN TRAN

	UPDATE [dbo].[MeasurementDevices]
	SET FlowRate = @FlowRate,
		Interval = @Interval,
		Connection = @CommunicationProtocol,
		IP = @CommunicationDetails,
		UpdateDate = GETDATE(),
		UpdateUserID = @LoggedInUserId
	WHERE ID = @LoggerMeasurementDeviceId
	
	/* MBA-902: record WHO configured this. The insert named only the two device ids, so
	   UpdateUserID stayed NULL on every relation ever created - which is why the logger popup
	   could not tell one calibrator's configuration from another's and showed everybody
	   everything. */
	INSERT [dbo].[SensorToLoggerRelation](
	[SensorMeasurementDeviceId],
	[LoggerMeasurementDeviceId],
	[UpdateUserID])
	SELECT @SensorMeasurementDeviceId ,@LoggerMeasurementDeviceId ,@LoggedInUserId
	WHERE NOT EXISTS (SELECT 1 FROM [dbo].[SensorToLoggerRelation] 
					  WHERE [SensorMeasurementDeviceId] = @SensorMeasurementDeviceId
	                  AND [LoggerMeasurementDeviceId] = @LoggerMeasurementDeviceId
					  AND [IsDeleted] = 0)

	/* an existing relation re-used by this calibrator becomes theirs to see */
	UPDATE [dbo].[SensorToLoggerRelation]
	SET UpdateUserID = @LoggedInUserId, UpdatedDate = GETDATE()
	WHERE [SensorMeasurementDeviceId] = @SensorMeasurementDeviceId
	  AND [LoggerMeasurementDeviceId] = @LoggerMeasurementDeviceId
	  AND [IsDeleted] = 0
	  AND UpdateUserID IS NULL
	
--Insert new data
	INSERT [dbo].[ChannelsToSensorRelation]([SensorMeasurementDeviceId],[LoggerMeasurementDeviceId],[ChannelNumber])
	SELECT @SensorMeasurementDeviceId,@LoggerMeasurementDeviceId, c.ChannelNumber
	FROM #Channels as c
	LEFT JOIN [dbo].[ChannelsToSensorRelation] as cr ON cr.[SensorMeasurementDeviceId] = @SensorMeasurementDeviceId
	                                                AND cr.[LoggerMeasurementDeviceId] = @LoggerMeasurementDeviceId
													AND c.ChannelNumber = cr.ChannelNumber
							
	WHERE cr.[SensorMeasurementDeviceId] IS NULL

--In case if it was previously assigned revert deleted flag
--MBA-902: only when a list was actually supplied. An empty list is not a request to unassign
--         everything - that is what pressing refresh was doing.
    IF @HasChannels = 1
    BEGIN
        UPDATE cr
	    SET IsDeleted = IIF(c.ChannelNumber IS NULL,1,0),
		    UpdatedDate = GETDATE(),
		    UpdateUserID = @LoggedInUserId
	    FROM [dbo].[ChannelsToSensorRelation] as cr
	    LEFT JOIN #Channels as c ON cr.ChannelNumber = c.ChannelNumber
	    WHERE cr.[SensorMeasurementDeviceId] = @SensorMeasurementDeviceId
	          AND cr.[LoggerMeasurementDeviceId] = @LoggerMeasurementDeviceId
    END

	COMMIT
END TRY

BEGIN CATCH
	SELECT ERROR_MESSAGE() as error
	ROLLBACK
END CATCH 
END
GO

/* ================= dbo.AssignMeasurmentPointsToOrderDetailsItems ================= */
CREATE OR ALTER PROCEDURE [dbo].[AssignMeasurmentPointsToOrderDetailsItems]
@LoggedInUserEmail NVARCHAR(100),
@Data NVARCHAR(MAX),
@ReturnSummary BIT = 0
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 31/07/2025
-- Description:	Populate table MeasurmentPointsToOrderDetailsItems during calibration process setup
-- 2026-08-13 hardening: the calibration wizard was getting a bare 500 from this proc whenever the
-- payload was slightly off. Reproduced on STAGE: an empty MeasurmentPointCoordX -> 8114 (nvarchar
-- to decimal), a comma decimal "4,35" -> 8114, a coordinate >= 1,000,000 -> 8115 (overflow), and an
-- empty SensorMeasurementDeviceId -> 547 (FK violation). The FE types all of these as z.string()
-- with no numeric validation, so an empty string passes zod and explodes here.
-- Now: every decimal is read out of the JSON as text and coerced with TRY_CONVERT (a comma decimal
-- is accepted, anything unparseable becomes NULL), and a point whose sensor id does not exist in
-- dbo.MeasurementDevices is skipped instead of breaking the whole save.
-- TRADE-OFF, deliberate: this turns a total failure into a partial save, so a malformed point is
-- dropped quietly. The proper fix is on the FE (send numbers, not strings) — see the Jira ticket.
-- 2026-08-24 (MBA-902) two follow-ups to that hardening, both visible on the chamber diagram.
--   THE EMPTY CIRCLE. 220 of the 366 saved points carry MeasurmentPointName = ''. The column is
--   NOT NULL, so a blank name is stored rather than refused, and the diagram draws a circle with
--   nothing in it. The 146 points that do have a name all follow one convention, T1..T11 - and T1
--   appears once against sixteen each for T2..T10, so it is the FIRST point that arrives unnamed.
--   A blank name is now filled in as T<n>, numbered per order item and skipping every T number
--   that item already uses, so a placed point always has something to draw.
--   THE POINT THAT VANISHES. The partial-save trade-off below is right - one bad point must not
--   take the whole save down - but it was silent. An item declaring two points on the first page
--   and showing one on the diagram looks like a rendering bug rather than a dropped record. Pass
--   @ReturnSummary = 1 to get back what was received, saved and skipped, and why. Off by default:
--   the caller uses $executeRaw, which cannot take a result set.
-- ON ChannelNumber, because it is easy to confuse with the point count on the first page - they
--   are different things and there are three of them in the chain:
--     OrderDetailsItems.MeasurementPoints  how many points the calibration requires
--     ChannelsToSensorRelation             which of the logger's channels that sensor occupies
--     this table's ChannelNumber           which ONE of those channels this point is wired to
--   Measured on STAGE: of the 366 saved points, 128 carry a channel that really is one of the
--   sensor's assigned channels, which is what confirms the column means a logger channel and not a
--   point index. The other 238 do not, and they split cleanly: 167 carry ChannelNumber = 99 on a
--   sensor that has NO channels assigned at all. 99 is not an arbitrary placeholder - it is what
--   gets written when the sensor-to-logger step was never completed and there was nothing to pick.
--   A further 12 points name a channel their sensor does not have, which is a genuine mis-wiring.
--   The procedure reports all of this through @ReturnSummary but does NOT refuse the point: a
--   calibrator has physically placed it in the chamber, and dropping that is worse than storing it
--   with a channel that still needs fixing.
-- 2026-08-24, same round: OrderDetailsItemId, SensorMeasurementDeviceId and ChannelNumber were
--   still typed INT in the OPENJSON WITH clauses. A non-numeric value in any of them raised error
--   245 and the caller saw a bare Internal Server Error - exactly the failure mode the 2026-08-13
--   hardening removed for the coordinates but never applied to the ids. Reproduced on STAGE with
--   OrderDetailsItemId = 'abc' and SensorMeasurementDeviceId = 'abc'. All three are now read as
--   text and coerced with TRY_CONVERT, so a bad id skips its point and is reported instead of
--   taking the whole save down.
-- JiraLink:
-- =============================================
--Example of json needs to be passed
--'
--{
--  "OrderDetailsItemId": "1",
--  "Points": [
--    {
--      "MeasurmentPointName": "T1",
--      "MeasurmentPointCoordX": "4.35",
--      "MeasurmentPointCoordY": "3.35",
--      "SensorMeasurementDeviceId": "1",
--      "ChannelNumber": 1,
--      "UncertancyValue": 2,
--		"MasterValue": 36.44,
--		"MasterValueUnitId": 1,
--		"MeasuredValue": 35,
--		"MeasuredValueUnitId": 1,
--		"StabilityValue": 2,
--		"AdditionalValue": 33,
--		"AdditionalValueUnitId": 3
--    },
--    {
--      "MeasurmentPointName": "T2",
--      "MeasurmentPointCoordX": "8.35",
--      "MeasurmentPointCoordY": "4.25",
--      "SensorMeasurementDeviceId": "1",
--      "ChannelNumber": 15,
--      "UncertancyValue": 2,
--		"MasterValue": 39.44,
--		"MasterValueUnitId": 1,
--		"MeasuredValue": 35,
--		"MeasuredValueUnitId": 1,
--		"StabilityValue": 2,
--		"AdditionalValue": 33,
--		"AdditionalValueUnitId":3
--    },
--    {
--      "MeasurmentPointName": "T3",
--      "MeasurmentPointCoordX": "12.35",
--      "MeasurmentPointCoordY": "5.3",
--      "SensorMeasurementDeviceId": "2",
--      "ChannelNumber": 17,
--      "UncertancyValue": 2,
--		"MasterValue": 38.44,
--		"MasterValueUnitId": 1,
--		"MeasuredValue": 35,
--		"MeasuredValueUnitId": 1,
--		"StabilityValue": 2,
--		"AdditionalValue": 33,
--		"AdditionalValueUnitId":3
--    }
--  ]
--}
--'


AS

BEGIN 

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

DROP TABLE IF EXISTS #parsedData

CREATE TABLE #parsedData
(
	OrderDetailsItemId INT,
    MeasurmentPointName NVARCHAR(100) COLLATE Latin1_General_100_CI_AI_SC,
    SensorMeasurementDeviceId INT,
    MeasurmentPointCoordX DECIMAL(10,4),
    MeasurmentPointCoordY DECIMAL(10,4),
	ChannelNumber INT,
	MasterValue DECIMAL(10,4),
    MasterValueUnitId INT,
    AdditionalValue DECIMAL(10,4),
    AdditionalValueUnitId INT,
    StabilityValue DECIMAL(10,4),
    UncertancyValue DECIMAL(10,4),
    MeasuredValue DECIMAL(10,4),
    MeasuredValueUnitId INT
)

INSERT #parsedData
(
	OrderDetailsItemId,
    MeasurmentPointName,
    SensorMeasurementDeviceId,
    MeasurmentPointCoordX,
    MeasurmentPointCoordY,
	ChannelNumber,
	MasterValue,
    MasterValueUnitId,
    AdditionalValue,
    AdditionalValueUnitId,
    StabilityValue,
    UncertancyValue,
    MeasuredValue,
    MeasuredValueUnitId
)

SELECT 
    TRY_CONVERT(INT, d.OrderDetailsItemId)        AS OrderDetailsItemId,
    c.MeasurmentPointName,
    TRY_CONVERT(INT, c.SensorMeasurementDeviceId) AS SensorMeasurementDeviceId,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.MeasurmentPointCoordX, ',', '.')) AS MeasurmentPointCoordX,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.MeasurmentPointCoordY, ',', '.')) AS MeasurmentPointCoordY,
    TRY_CONVERT(INT, c.ChannelNumber)             AS ChannelNumber,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.MasterValue, ',', '.')) AS MasterValue,
    c.MasterValueUnitId,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.AdditionalValue, ',', '.')) AS AdditionalValue,
    c.AdditionalValueUnitId,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.StabilityValue, ',', '.')) AS StabilityValue,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.UncertancyValue, ',', '.')) AS UncertancyValue,
    TRY_CONVERT(DECIMAL(10,4), REPLACE(c.MeasuredValue, ',', '.')) AS MeasuredValue,
    c.MeasuredValueUnitId
FROM OPENJSON(@Data) 
WITH (
    /* MBA-902: read as text and coerce. Typed INT here, a non-numeric id raised error 245 and the
       caller got a bare Internal Server Error - the same failure the 2026-08-13 hardening fixed for
       the coordinates but did not apply to the three id columns. */
    OrderDetailsItemId NVARCHAR(50),
    Points NVARCHAR(MAX) AS JSON
) AS d
OUTER APPLY OPENJSON(d.Points)
WITH (
    MeasurmentPointName NVARCHAR(100),
    MeasurmentPointCoordX NVARCHAR(50),
    MeasurmentPointCoordY NVARCHAR(50),
    SensorMeasurementDeviceId NVARCHAR(50),   /* MBA-902: was INT - see the outer WITH above */
    ChannelNumber NVARCHAR(50),               /* MBA-902: was INT */
	MasterValue NVARCHAR(50),
    MasterValueUnitId INT,
    AdditionalValue NVARCHAR(50),
    AdditionalValueUnitId INT,
    StabilityValue NVARCHAR(50),
    UncertancyValue NVARCHAR(50),
    MeasuredValue NVARCHAR(50),
    MeasuredValueUnitId INT
) AS c
/* MBA-902: a point with no name draws an empty circle. Give it the next free T number for its
   order item, counting the names already stored and the named points in this same payload. */
;WITH Used AS
(
    SELECT OrderDetailsItemId, TRY_CAST(SUBSTRING(MeasurmentPointName, 2, 10) AS INT) AS Num
    FROM dbo.MeasurmentPointsToOrderDetailsItems
    WHERE IsDeleted = 0 AND MeasurmentPointName LIKE 'T[0-9]%'
    UNION ALL
    SELECT OrderDetailsItemId, TRY_CAST(SUBSTRING(MeasurmentPointName, 2, 10) AS INT)
    FROM #parsedData
    WHERE MeasurmentPointName LIKE 'T[0-9]%'
),
Base AS
(
    SELECT pd.OrderDetailsItemId, ISNULL(MAX(u.Num), 0) AS MaxUsed
    FROM #parsedData AS pd
    LEFT JOIN Used AS u ON u.OrderDetailsItemId = pd.OrderDetailsItemId
    GROUP BY pd.OrderDetailsItemId
),
Blanks AS
(
    SELECT pd.MeasurmentPointName, pd.OrderDetailsItemId,
           ROW_NUMBER() OVER (PARTITION BY pd.OrderDetailsItemId
                              ORDER BY pd.ChannelNumber, pd.MeasurmentPointCoordX,
                                       pd.MeasurmentPointCoordY) AS rn
    FROM #parsedData AS pd
    WHERE LTRIM(RTRIM(ISNULL(pd.MeasurmentPointName, ''))) = ''
)
UPDATE b
SET MeasurmentPointName = 'T' + CAST(bs.MaxUsed + b.rn AS NVARCHAR(10))
FROM Blanks AS b
INNER JOIN Base AS bs ON bs.OrderDetailsItemId = b.OrderDetailsItemId;

/* MBA-902: a point is wired to ONE of the channels its sensor occupies on the logger. Flag the
   ones that are not - reported, never refused; the point has been physically placed. */
DROP TABLE IF EXISTS #channelWarnings;
SELECT pd.OrderDetailsItemId, pd.MeasurmentPointName, pd.SensorMeasurementDeviceId, pd.ChannelNumber,
       CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.ChannelsToSensorRelation AS c
                             WHERE c.SensorMeasurementDeviceId = pd.SensorMeasurementDeviceId
                               AND c.IsDeleted = 0)
                 THEN 'this sensor has no channels assigned to any logger yet'
            ELSE 'channel is not one of the channels this sensor occupies'
       END AS Warning
INTO #channelWarnings
FROM #parsedData AS pd
WHERE pd.SensorMeasurementDeviceId IS NOT NULL
  AND pd.ChannelNumber IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.ChannelsToSensorRelation AS c
                  WHERE c.SensorMeasurementDeviceId = pd.SensorMeasurementDeviceId
                    AND c.ChannelNumber = pd.ChannelNumber
                    AND c.IsDeleted = 0);

/* MBA-902: what this save is about to drop, captured before the MERGE filters it away. */
DECLARE @Received INT = (SELECT COUNT(*) FROM #parsedData);

DROP TABLE IF EXISTS #skipped;
SELECT pd.OrderDetailsItemId, pd.MeasurmentPointName, pd.SensorMeasurementDeviceId, pd.ChannelNumber,
       CASE
           WHEN pd.OrderDetailsItemId IS NULL         THEN 'no order item supplied'
           WHEN pd.SensorMeasurementDeviceId IS NULL  THEN 'no sensor supplied'
           WHEN pd.ChannelNumber IS NULL              THEN 'no channel supplied'
           WHEN pd.MeasurmentPointCoordX IS NULL
             OR pd.MeasurmentPointCoordY IS NULL      THEN 'coordinate could not be read as a number'
           ELSE 'sensor does not exist'
       END AS Reason
INTO #skipped
FROM #parsedData AS pd
WHERE pd.OrderDetailsItemId IS NULL
   OR pd.ChannelNumber IS NULL
   OR pd.SensorMeasurementDeviceId IS NULL
   OR pd.MeasurmentPointCoordX IS NULL
   OR pd.MeasurmentPointCoordY IS NULL
   OR NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevices md WHERE md.ID = pd.SensorMeasurementDeviceId);

/*Apply soft delete to data which no longer valid*/
UPDATE dest
SET IsDeleted = 1,
    UpdatedDate = GETDATE()
FROM [dbo].[MeasurmentPointsToOrderDetailsItems] as dest 
LEFT JOIN #parsedData as pd
	ON pd.OrderDetailsItemId = dest.OrderDetailsItemId
	   AND pd.SensorMeasurementDeviceId = dest.SensorMeasurementDeviceId
	   AND pd.ChannelNumber = dest.ChannelNumber
WHERE dest.IsDeleted = 0 AND pd.SensorMeasurementDeviceId IS NULL
AND dest.OrderDetailsItemId IN (SELECT OrderDetailsItemId FROM #parsedData)
/*Insert new data or updating existing*/
MERGE INTO [dbo].[MeasurmentPointsToOrderDetailsItems] AS dest
USING (
	SELECT
		d.OrderDetailsItemId,
		d.SensorMeasurementDeviceId,
		d.MeasurmentPointName,
		d.MeasurmentPointCoordX,
		d.MeasurmentPointCoordY,
		d.ChannelNumber,
		d.MasterValue,
        d.MasterValueUnitId,
        d.AdditionalValue,
        d.AdditionalValueUnitId,
        d.StabilityValue,
        d.UncertancyValue,
        d.MeasuredValue,
        d.MeasuredValueUnitId
	FROM #parsedData as d
	WHERE d.OrderDetailsItemId IS NOT NULL AND d.ChannelNumber IS NOT NULL AND d.SensorMeasurementDeviceId IS NOT NULL
	  AND EXISTS (SELECT 1 FROM dbo.MeasurementDevices md WHERE md.ID = d.SensorMeasurementDeviceId)
	  /* Both coordinates are NOT NULL on the target table, so an unparseable one cannot be written.
	     Skip that point rather than defaulting to 0 — a point silently placed at (0,0) would show up
	     in the wrong spot on the chamber diagram, which is worse than a point that is missing. */
	  AND d.MeasurmentPointCoordX IS NOT NULL AND d.MeasurmentPointCoordY IS NOT NULL
	) AS source
	ON   dest.[OrderDetailsItemId] = source.[OrderDetailsItemId]
		 AND dest.[SensorMeasurementDeviceId] = source.[SensorMeasurementDeviceId]
		 AND dest.[ChannelNumber] = source.[ChannelNumber]
		 AND dest.[IsDeleted] = 0
    WHEN MATCHED AND ( 
	           COALESCE(dest.[MeasurmentPointName],'') <> COALESCE(source.[MeasurmentPointName],'')
			OR COALESCE(dest.[MeasurmentPointCoordX],0) <> COALESCE(source.[MeasurmentPointCoordX],1)
			OR COALESCE(dest.[MeasurmentPointCoordY],0) <> COALESCE(source.[MeasurmentPointCoordY],1)
            OR COALESCE(dest.[MasterValue],0) <> COALESCE(source.[MasterValue],0)
            OR COALESCE(dest.[MasterValueUnitId],0) <> COALESCE(source.[MasterValueUnitId],0)
            OR COALESCE(dest.[AdditionalValue],0) <> COALESCE(source.[AdditionalValue],0)
            OR COALESCE(dest.[AdditionalValueUnitId],0) <> COALESCE(source.[AdditionalValueUnitId],0)
            OR COALESCE(dest.[StabilityValue],0) <> COALESCE(source.[StabilityValue],0)
            OR COALESCE(dest.[UncertancyValue],0) <> COALESCE(source.[UncertancyValue],0)
            OR COALESCE(dest.[MeasuredValue],0) <> COALESCE(source.[MeasuredValue],0)
            OR COALESCE(dest.[MeasuredValueUnitId],0) <> COALESCE(source.[MeasuredValueUnitId],0)
            )
	THEN
		UPDATE
		SET  dest.[MeasurmentPointName] = source.[MeasurmentPointName]
			,dest.[MeasurmentPointCoordX] = source.[MeasurmentPointCoordX]
			,dest.[MeasurmentPointCoordY] = source.[MeasurmentPointCoordY]
			,dest.[UpdatedDate] = GETDATE()
			,dest.[UpdateUserID] = @LoggedInUserId
            ,dest.[MasterValue] = source.[MasterValue]
            ,dest.[MasterValueUnitId] = source.[MasterValueUnitId]
            ,dest.[AdditionalValue] = source.[AdditionalValue]
            ,dest.[AdditionalValueUnitId] = source.[AdditionalValueUnitId]
            ,dest.[StabilityValue] = source.[StabilityValue]
            ,dest.[UncertancyValue] = source.[UncertancyValue]
            ,dest.[MeasuredValue] = source.[MeasuredValue]
            ,dest.[MeasuredValueUnitId] = source.[MeasuredValueUnitId]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			  [OrderDetailsItemId],
			  [SensorMeasurementDeviceId],
			  [MeasurmentPointName],
			  [MeasurmentPointCoordX],
			  [MeasurmentPointCoordY],
			  [ChannelNumber],
			  [UpdateUserID],
		      [MasterValue],
              [MasterValueUnitId],
              [AdditionalValue],
              [AdditionalValueUnitId],
              [StabilityValue],
              [UncertancyValue],
              [MeasuredValue],
              [MeasuredValueUnitId]
			)
		VALUES (
             source.[OrderDetailsItemId]
			,source.[SensorMeasurementDeviceId]
			,source.[MeasurmentPointName]
			,source.[MeasurmentPointCoordX]
			,source.[MeasurmentPointCoordY]
			,source.[ChannelNumber]
			,@LoggedInUserId
            ,source.[MasterValue]
            ,source.[MasterValueUnitId]
            ,source.[AdditionalValue]
            ,source.[AdditionalValueUnitId]
            ,source.[StabilityValue]
            ,source.[UncertancyValue]
            ,source.[MeasuredValue]
            ,source.[MeasuredValueUnitId]
			);


/* MBA-902: opt-in only - the caller uses $executeRaw, which cannot take a result set. */
IF @ReturnSummary = 1
BEGIN
    SELECT @Received                                     AS pointsReceived,
           @Received - (SELECT COUNT(*) FROM #skipped)   AS pointsSaved,
           (SELECT COUNT(*) FROM #skipped)               AS pointsSkipped,
           (SELECT COUNT(*) FROM #channelWarnings)       AS pointsWithAnInvalidChannel;

    SELECT OrderDetailsItemId        AS orderDetailsItemId,
           MeasurmentPointName       AS measurementPointName,
           SensorMeasurementDeviceId AS sensorMeasurementDeviceId,
           ChannelNumber             AS channelNumber,
           Reason                    AS reason
    FROM #skipped;

    /* saved, but the channel does not belong to the sensor - the calibration will read nothing */
    SELECT OrderDetailsItemId        AS orderDetailsItemId,
           MeasurmentPointName       AS measurementPointName,
           SensorMeasurementDeviceId AS sensorMeasurementDeviceId,
           ChannelNumber             AS channelNumber,
           Warning                   AS warning
    FROM #channelWarnings;
END

END
GO

/* ================= dbo.GetAllCalibrationDevices ================= */
/*
    dbo.GetAllCalibrationDevices
    ---------------------------------------------------------------------------------------------
    Original author: Eduard Kudlaiev, 28/05/2025 (MABA-43)
    Backs the logger and sensor pickers in the calibration wizard, and the logger-connection popup.

    2026-08-24 (MBA-902): three fixes, all visible in that popup.

    1. מס' נקודות always showed 0. ChannelsNumber was sourced from md.Channels, which is NULL on
       every one of the loggers - Channels is populated on 152 rows and all of them are sensors.
       The logger's channel count lives in md.ConnectionPoints (21-142 = 21, 31-80 = 61,
       21-702 = 82), which no procedure returned. Now COALESCE(ConnectionPoints, Channels), so
       loggers report their real count and nothing that relied on Channels loses it.

    2. No ORDER BY at all, so the picker listed devices in whatever order the join produced and the
       order changed between calls. Sorted on MabaID's two numeric segments rather than as text,
       so 21-17 precedes 21-131; a plain text sort puts 21-131 first because '1' sorts before '7'.

    3. Classifying the previously unclassified devices took the logger class from 35 rows to 454,
       and the picker filled up with registry entries the system cannot actually talk to - a
       calibrator selecting 30-1100 would be selecting a device with no connection at all. A logger
       is now offered only if its Connection mentions USB, LAN or IP.

       That rule is not new: the WHERE clause already carried it, commented out, as
       "AND md.Connection IS NOT NULL AND md.Connection <> N'אוגר אלחוטי'". This turns the same
       intent back on.

       The test is "has a connection at all", not "USB or LAN". Of the 35 loggers that carry a
       connection value, 26 are USB / LAN / IP and 9 are plain RS-232 - and those 9 are real
       working loggers, the ones showing 1 and 2 connection points. Filtering on USB/LAN alone
       would silently drop them. Wireless loggers stay excluded, as the original comment intended.

       Pass @ConnectableLoggersOnly = 0 to get the unfiltered list, including the 396 registry
       entries that have no connection value at all.

    The filter applies to loggers only. Sensors carry connection values like 2W and 4W, which
    describe wiring rather than a link to this system, and must not be filtered by it.
*/
CREATE OR ALTER PROCEDURE [dbo].[GetAllCalibrationDevices]
@MeasurementDevicesMainClassId INT = NULL,
@CalibrationDeviceId INT = NULL,
@ApplyFilterByDevicesParents BIT = 0,
@ConnectableLoggersOnly BIT = 1
AS
BEGIN

	DECLARE @DataLoggerClassId INT = 7;

	DECLARE @sql NVARCHAR(MAX) =
	CONCAT(
	'
	SELECT md.[ID]
		  ,md.[MabaID]
		  ,md.[Model]
		  ,md.[SerialNumber]
		  ,md.[CalibrationDate] AS [LastCalibrationDate]
		  ,md.[NextCalibration]
		  ,NULL AS [Status]
		  ,mc.NameHebrew
		  ,mc.NameEnglish
		  ,md.UnitId
		  ,u.ShortNameHe AS UnitName
		  ,md.WorkRangeUnitId
		  ,u2.ShortNameHe as WorkRangeUnitName
		  ,md.WorkRangeMin	as LowerDomainBorder
		  ,md.WorkRangeMax as UpperDomainBorder 
		  /* MBA-902: the second range, for sensors that measure temperature and humidity at once */
		  ,md.WorkRangeMin2 as LowerDomainBorder2
		  ,md.WorkRangeMax2 as UpperDomainBorder2
		  ,u3.ShortNameHe as WorkRangeUnitName2
		  ,m.NameHe as MeasurmentName
		  ,d.[MainCategoryName] as DepartmentName
		  ,md.[IP]
		  ,COALESCE(md.Resolution,60) as Resolution
		  /* MBA-902: a logger''s channel count is ConnectionPoints; Channels is a sensor column */
		  ,COALESCE(md.ConnectionPoints, md.Channels) as ChannelsNumber
		  ,md.ConnectionPoints
		  ,md.Connection
		  ,md.MeasurementId	
		  ,md.MainClassId	
		  ,md.SubClassId
		  ,u.MeasurementDeviceUnitGroupId
	  FROM [dbo].[MeasurementDevices] as md
	  JOIN [dbo].[MeasurementDevicesMainClasses] as mc ON md.MainClassId = mc.Id
	  LEFT JOIN [dbo].[MeasurementDeviceUnits] as u ON md.UnitId = u.MeasurementDeviceUnitId
	  LEFT JOIN [dbo].[MeasurementDeviceUnits] as u2 ON md.WorkRangeUnitId = u2.MeasurementDeviceUnitId
	  LEFT JOIN [dbo].[MeasurementDeviceUnits] as u3 ON md.WorkRangeUnitId2 = u3.MeasurementDeviceUnitId
	  LEFT JOIN [dbo].[Measurements] as m ON md.MeasurementId = m.ID
	  LEFT JOIN [dbo].[MainCategories] as d ON md.MainCategoryId = d.ID
	  WHERE md.RemoveDate IS NULL AND md.IsDeleted = 0
	  '
	  ,CASE WHEN @MeasurementDevicesMainClassId IS NOT NULL THEN' AND md.MainClassId = '+CAST(@MeasurementDevicesMainClassId as NVARCHAR(50))+' ' ELSE ' ' END
	  ,CASE WHEN @CalibrationDeviceId IS NOT NULL THEN' AND md.[ID] = '+CAST(@CalibrationDeviceId as NVARCHAR(50))+' ' ELSE ' ' END
	  /* MBA-902: only loggers this system can actually connect to. Never applied to sensors. */
	  ,CASE WHEN @ConnectableLoggersOnly = 1 AND @CalibrationDeviceId IS NULL
	         THEN ' AND (md.MainClassId <> '+CAST(@DataLoggerClassId as NVARCHAR(50))+
	              ' OR (md.Connection IS NOT NULL AND LEN(LTRIM(RTRIM(md.Connection))) > 0'+
	              '     AND md.Connection <> N''אוגר אלחוטי'')) '
	         ELSE ' ' END
	  /* MBA-902: numeric order on MabaID; anything not shaped nn-nnn sorts last */
	  ,'
	  ORDER BY IIF(TRY_CAST(LEFT(md.MabaID, CHARINDEX(''-'', md.MabaID + ''-'') - 1) AS INT) IS NULL, 1, 0),
	           TRY_CAST(LEFT(md.MabaID, CHARINDEX(''-'', md.MabaID + ''-'') - 1) AS INT),
	           TRY_CAST(LEFT(STUFF(md.MabaID, 1, CHARINDEX(''-'', md.MabaID + ''-''), ''''),
	                         CHARINDEX(''/'', STUFF(md.MabaID, 1, CHARINDEX(''-'', md.MabaID + ''-''), '''') + ''/'') - 1) AS INT),
	           md.MabaID
	  '
	  )

	EXEC sp_executesql @sql

END
GO

/* ================= dbo.GetAllEquipment ================= */
/*
    dbo.GetAllEquipment
    ---------------------------------------------------------------------------------------------
    Original author: Eduard Kudlaiev, 02/04/2025
    All calibration equipment available for assignment - this is what fills the equipment and
    sensor pickers in the calibration wizard.

    2026-08-24 (MBA-902): the proc had no ORDER BY at all, so the picker listed devices in whatever
    order the join happened to produce - 21-131, 21-682, 21-528/10, 21-604, 21-697, 21-17 - which
    is unusable for finding a device by its number, and unstable between calls.

    Sorted on MabaID's numeric segments rather than as text, so 21-17 comes before 21-131 (plain
    text sort puts 21-131 first, because '1' sorts before '7'). Devices whose MabaID does not
    follow the nn-nnn shape sort last rather than being dropped.

    AassignedChannels came out of STRING_AGG in join order too, so a sensor holding 0,1,2,3,6,7
    could render as "3,0,7,1,6,2". Now numeric.

    No rows, filters or columns changed.
*/
CREATE OR ALTER PROCEDURE [dbo].[GetAllEquipment]
@MainCategoryId INT = NULL,
@CheckDate DATE = NULL,
@MainClassId INT = NULL
AS

IF @CheckDate IS NULL SET @CheckDate = GETDATE()

SELECT c.[ID]
      ,CONCAT(COALESCE(c.[Description],'N/A'), ' ',c.MabaID) AS Title
	  ,c.[MainClassId]
	  ,c.[SubClassId]
	  ,c.[MainCategoryId] as [DepartmentId]
      ,s.[StatusId]
	  ,s.[StatusDescriptionENG]	
	  ,s.[StatusDescriptionHEB] 
	  ,mmc.MainCategoryName AS [MainCategory]
      -----------------------------
	  ,op.OrderNumber as OrderNumber
	  ,coh.OrderWorkPlanId as OrderId
	  ,c.Manufacturer
	  ,c.DisplayToCoordinator
	  ,c.[MabaID]
	  ,c.[CalibrationDate]
	  ,c.[Channels]
	  ,ach.AassignedChannels
	  ,c.[StabilityTime]
	  ,c.[StabilitySize]
	  ,c.[CalibrationDate]
	  ,c.[NextCalibration]
	  ,mdmc.[NameHebrew] as DeviceMainClass
FROM [dbo].[MeasurementDevices] as c
LEFT JOIN [dbo].[MainCategories] as mmc ON c.[MainCategoryId] = mmc.ID
LEFT JOIN [dbo].[Statuses] as s ON c.MeasurementDeviceStatusId = s.StatusId
LEFT JOIN [dbo].[MeasurementDevicesMainClasses] as mc ON c.MainClassId = mc.Id
LEFT JOIN [dbo].[MeasurementDevicesToOrderHeaders] as coh ON c.ID = coh.MeasurementDeviceId AND coh.IsDeleted = 0 AND coh.AssigmentDate = @CheckDate
LEFT JOIN [dbo].[OrderWorkPlans] as op ON op.OrderWorkPlanId = coh.OrderWorkPlanId AND op.IsCancelled = 0  
LEFT JOIN [dbo].[MeasurementDevicesMainClasses] as mdmc ON c.MainClassId = mdmc.Id
LEFT JOIN 
(
SELECT sr.SensorMeasurementDeviceId, STRING_AGG(sr.ChannelNumber,',') WITHIN GROUP (ORDER BY sr.ChannelNumber) as AassignedChannels
FROM [dbo].[ChannelsToSensorRelation] as sr
WHERE sr.IsDeleted = 0
GROUP BY sr.SensorMeasurementDeviceId
) as ach ON c.ID = ach.SensorMeasurementDeviceId
WHERE c.IsDeleted = 0  /*AND COALESCE(s.StatusDescriptionENG,'Available') = 'Available'*/ AND coh.MeasurementDeviceId IS NULL
AND (@MainCategoryId IS NULL OR c.[MainCategoryId]  = @MainCategoryId)
AND (@MainClassId IS NULL OR c.MainClassId  = @MainClassId)
-- MBA-902: numeric order on MabaID's two segments; anything not shaped nn-nnn sorts last
ORDER BY
	 IIF(TRY_CAST(LEFT(c.MabaID, CHARINDEX('-', c.MabaID + '-') - 1) AS INT) IS NULL, 1, 0),
	 TRY_CAST(LEFT(c.MabaID, CHARINDEX('-', c.MabaID + '-') - 1) AS INT),
	 TRY_CAST(LEFT(STUFF(c.MabaID, 1, CHARINDEX('-', c.MabaID + '-'), ''),
	               CHARINDEX('/', STUFF(c.MabaID, 1, CHARINDEX('-', c.MabaID + '-'), '') + '/') - 1) AS INT),
	 c.MabaID
GO

/* ================= dbo.GetCalibrationCycles ================= */
CREATE OR ALTER PROCEDURE [dbo].[GetCalibrationCycles]
@OrderDetailsItemId INT,
@ShowOnlyLatest BIT = 0 
/*
EXEC [dbo].[GetCalibrationCycles]
@OrderDetailsItemId = 3077,
@ShowOnlyLatest = 1
*/
AS
BEGIN
SET NOCOUNT ON;

WITH ds
AS
(
SELECT
	 cc.[OrderDetailsItemId]
	,cc.[CalibrationCycleStartDate]
	,cc.[CalibrationCycleEndDate]
	,cc.[CalibrationCycleStatusId]
	,cc.[CreatedUserID]
	,cc.[CalibrationCycleName]
	,cc.[UnitId]	
	,mu.[LongNameHe] as UnitName
	,cc.[TestedValue]
	,sr.[SpecificationReferences]
	,cc.[CalibrationCycleNameStatusId]
	,ROW_NUMBER() OVER( PARTITION BY cc.[OrderDetailsItemId] ORDER BY [CalibrationCycleStartDate]) as CycleNumber
	,ROW_NUMBER() OVER( PARTITION BY cc.[OrderDetailsItemId] ORDER BY [CalibrationCycleStartDate] DESC) as LatestCycle
FROM [dbo].[CalibrationCycles] as cc
LEFT JOIN [dbo].[MeasurementDeviceUnits] as mu ON cc.[UnitId] = mu.MeasurementDeviceUnitId
OUTER APPLY
(
SELECT STRING_AGG(Name,', ') as SpecificationReferences
FROM [dbo].[SpecificationReference] WHERE ID IN (SELECT value FROM STRING_SPLIT(cc.SpecificationReferenceIds,','))
) as sr
WHERE cc.[OrderDetailsItemId] = @OrderDetailsItemId AND cc.IsDeleted = 0
)
SELECT 
	 ds.[OrderDetailsItemId]
	,ds.[CalibrationCycleStartDate]
	,ds.[CalibrationCycleEndDate]
	,ds.[CalibrationCycleStatusId]
	,ds.[CreatedUserID]
	,ds.[CycleNumber]
	,ds.[CalibrationCycleName]
	,ds.[UnitId]	
	,ds.[UnitName]
	,ds.[TestedValue]
	,ds.[SpecificationReferences]
	,ds.[CalibrationCycleNameStatusId]
FROM ds
JOIN [dbo].[OrderDetailsItems] as oi ON ds.[OrderDetailsItemId] = oi.[OrderDetailsItemId] 
WHERE (@ShowOnlyLatest = 0 OR ds.LatestCycle = 1)
ORDER BY ds.[CycleNumber] ASC  -- Bug #2 fix: ensure cycles are always returned in creation order

END
GO

/* ================= dbo.GetCalibrationValuesForOrderDetailItem ================= */
CREATE OR ALTER PROCEDURE [dbo].[GetCalibrationValuesForOrderDetailItem]
@OrderDetailId INT, 
@OrderDetailsItemId INT
AS
BEGIN
    SELECT 
         COALESCE(combined.[MbaReportNumber], itm.[MbaReportNumber]) as [MbaReportNumber]
        ,COALESCE(combined.[SerialNumber], itm.[SerialNumber]) as [SerialNumber]
        ,itm.[UnitUnderTestValue]
        ,itm.[MeasurementUnitId] as UUTId
        ,mdu4.[ShortNameHe] as UUTDescription
        ,N'P' + CAST(combined.[ChannelNumber] as NVARCHAR(30)) as [ChannelNumber]
        ,combined.[SensorMeasurementDeviceId]
        ,md.[MabaID] AS MasterSensorMabaID
        ,md.ID as [MeasurementDeviceId] 
        ,combined.[Tolerance]
        ,combined.[NominalValue]
        ,wp.[OrderNumber]
        ,combined.[MasterValue]
        ,combined.[MasterValueUnitId] 
        ,mdu.[ShortNameHe] as MasterValueUnitDescription
        ,'0_mocked_val' as [MasterValueAfterCorrection]
        ,combined.MeasuredValue
        ,combined.MeasuredValueUnitId
        ,mdu3.[ShortNameHe] as MeasuredUUTDescription
        ,combined.[AdditionalValue]
        ,combined.[AdditionalValueUnitId]
        ,mdu2.[ShortNameHe] as AdditionalUUTDescription
        ,combined.[MasterValue] - combined.[NominalValue] as [Deviation]
        ,((combined.[MasterValue] - combined.[NominalValue])/COALESCE(NULLIF(combined.[Tolerance],0),1))*100 as AllowedDeviation
        ,combined.[UncertancyValue]
        ,'0_mocked_val' as DriftFromLastCalibration
        ,combined.StabilityValue
        ,combined.[MeasurmentPointsToOrderDetailsItemId]  
    FROM [dbo].[OrderDetailsItems] as itm
    JOIN [dbo].[OrderDetails] as od ON itm.OrderDetailId = od.OrderDetailId
    JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
    LEFT JOIN (
        SELECT 
            COALESCE(mpo.OrderDetailsItemId, evnc.OrderDetailsItemId) as OrderDetailsItemId,
            mpo.ChannelNumber,
            mpo.SensorMeasurementDeviceId,
            mpo.MasterValue,
            mpo.MasterValueUnitId,
            mpo.MeasuredValue,
            mpo.MeasuredValueUnitId,
            mpo.AdditionalValue,
            mpo.AdditionalValueUnitId,
            mpo.UncertancyValue,
            mpo.StabilityValue,
            mpo.MeasurmentPointsToOrderDetailsItemId,
            mpo.SerialNumber,
            mpo.MbaReportNumber,
            COALESCE(mpo.Tolerance, evnc.Tolerance) as Tolerance,
            COALESCE(mpo.NominalValue, evnc.NominalValue) as NominalValue
        FROM (
            SELECT *, 
                   ROW_NUMBER() OVER(PARTITION BY OrderDetailsItemId ORDER BY MeasurmentPointsToOrderDetailsItemId) as rn
            FROM [dbo].[MeasurmentPointsToOrderDetailsItems]
            WHERE IsDeleted = 0 AND OrderDetailsItemId = @OrderDetailsItemId
        ) mpo
        FULL OUTER JOIN (
            SELECT *, 
                   ROW_NUMBER() OVER(PARTITION BY OrderDetailsItemId ORDER BY NominalValue, CreateDate) as rn
            FROM [dbo].[CalibrationEnvironmentalConditions]
            WHERE IsDeleted = 0 AND OrderDetailsItemId = @OrderDetailsItemId
        ) evnc ON mpo.OrderDetailsItemId = evnc.OrderDetailsItemId AND mpo.rn = evnc.rn
    ) as combined ON itm.OrderDetailsItemId = combined.OrderDetailsItemId
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu ON combined.[MasterValueUnitId] = mdu.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu2 ON combined.[AdditionalValueUnitId] = mdu2.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu3 ON combined.MeasuredValueUnitId = mdu3.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu4 ON itm.MeasurementUnitId = mdu4.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDevices] as md ON md.ID = combined.[SensorMeasurementDeviceId]
    WHERE itm.OrderDetailId = @OrderDetailId 
      AND itm.OrderDetailsItemId = @OrderDetailsItemId
    ORDER BY combined.[MeasurmentPointsToOrderDetailsItemId], combined.NominalValue
END
GO

/* ================= dbo.GetCustomerDashboardData ================= */
/*
    dbo.GetCustomerDashboardData                                                   MBA-865
    ---------------------------------------------------------------------------------
    The חזרה צפויה column is labelled *expected* return, but the procedure was
    returning ActualReturnDate. It now returns ExpectedReturnDate, and only for in-house
    (lab) calibration - for on-site work there is nothing to return, so it is NULL.

    The output alias stays ActualReturnDate on purpose: the front end already binds to it,
    and renaming would break the screen for no gain.
*/
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 26/02/2026
-- Description:	Get customer dashboad data
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerDashboardData] 
@PageNumber AS INT = 1,                  -- Resulting page for pagination, starting in 1
@RowsOfPage AS INT = 50,                 -- Result page size
@OrderBy AS NVARCHAR(MAX) = 'CalibratioinDate',      -- OrderBy column
@OrderByAsc AS BIT = 0,                  -- OrderBy direction (ASC/DESC)
@LoggedInUserEmail NVARCHAR(50),
@GlobalSearch NVARCHAR(200) = NULL
AS

DECLARE @CustomerId INT = 0
DECLARE @SourceId TINYINT



SELECT 
	@CustomerId  = d.CustomerId 
,@SourceId = d.SourceId
FROM [dbo].[CustomerContacts] as d
WHERE CustomerContactEmail = @LoggedInUserEmail 

DROP TABLE IF EXISTS #CustomerOrdersIds
CREATE TABLE #CustomerOrdersIds
(
OrderWorkPlanId INT NOT NULL
)

INSERT #CustomerOrdersIds(OrderWorkPlanId)
SELECT wp.OrderWorkPlanId
FROM [dbo].[OrderWorkPlans] as wp
WHERE wp.[CustomerId] = @CustomerId

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'
;WITH ds
AS
(
SELECT 
COALESCE(clst.StatusDescriptionHEB,N'''+N'מחכה לכיול'+''') as DeviceStatus
,itm.ActualCalibrationDate as CalibratioinDate
,itm.NextCalibrationDate
,od.OrderWorkPlanId
,IIF(od.IsInHouse = 1,N'''+N'מעבדה'+''',N'''+N'לקוח'+''') as CalibratioinLocation
,pt.OrdersProductTypeName as DeviceDescription
,itm.SerialNumber
,IIF(od.IsInHouse = 1, itm.ExpectedReturnDate, NULL) as ActualReturnDate
,od.CalibratorId
,u.FirstName as CalibratorFirstName
,u.LastName as CalibratorLastName
,u.Phone as CalibratorPhoneNumber
,ctwp.AssigmentDate as CalibratorAssigmentDate
,ROW_NUMBER() OVER( PARTITION BY itm.SerialNumber ORDER BY wp.OrderWorkPlanId DESC) as IsLatestOrder
FROM 
[dbo].[OrderWorkPlans] as wp
JOIN #CustomerOrdersIds as f ON wp.OrderWorkPlanId = f.OrderWorkPlanId
JOIN [dbo].[OrderDetails] as od ON wp.OrderWorkPlanId = od.OrderWorkPlanId
LEFT JOIN [dbo].[OrderDetailsItems] as itm ON itm.OrderDetailId = od.OrderDetailId
LEFT JOIN [dbo].[Customers] as c ON wp.[CustomerId] = c.[CustomerId]
LEFT JOIN [dbo].[Statuses] as clst ON itm.[CalibrationStatusId] = clst.[StatusId]
LEFT JOIN [dbo].[MainCategories] as mcf ON od.MainCategoryId	= mcf.ID
LEFT JOIN [dbo].[Users] as u ON od.CalibratorId = u.[ID]
LEFT JOIN [dbo].[CalibratorsToWorkPlan] as ctwp ON ctwp.[OrderWorkPlanId] = wp.[OrderWorkPlanId] AND ctwp.[CalibratorId] = od.CalibratorId AND ctwp.IsDeleted = 0
LEFT JOIN [dbo].[SecondaryCategories] as scf ON od.SecondaryCategoryId = scf.ID
LEFT JOIN [dbo].[CustomerSites] as css ON css.CustomerSiteId = od.CustomerSiteId
LEFT JOIN [dbo].[OrdersProductTypes] as pt ON od.OrdersProductTypeId = pt.OrdersProductTypeId
--WHERE wp.[CustomerId] = 2159
),
devices_cnt
AS
(
SELECT 
COALESCE(NULLIF(d.DeviceStatus,N''''),N''לא ניתן לקבוע'') as DeviceStatus
,d.CalibratioinDate
,d.NextCalibrationDate
,d.CalibratioinLocation
,d.DeviceDescription
,d.SerialNumber
,d.ActualReturnDate
,d.CalibratorId
,d.CalibratorFirstName
,d.CalibratorLastName
,d.CalibratorPhoneNumber
,d.CalibratorAssigmentDate
,d.IsLatestOrder
,SUM(IIF(d.IsLatestOrder = 1,1,NULL)) OVER( ORDER BY d.DeviceStatus) as OverallDevicesCount
,SUM(IIF(d.IsLatestOrder = 1 AND COALESCE(d.CalibratioinDate,''1900-01-01'') < GETDATE(),1,NULL)) OVER( ORDER BY d.DeviceStatus) as ExpiredevicesCount
,COALESCE(SUM(IIF(d.IsLatestOrder = 1 AND d.CalibratioinDate > GETDATE(),1,NULL)) OVER( ORDER BY d.DeviceStatus),0) as CalibratedDevicesCount
,COALESCE(SUM(IIF(d.IsLatestOrder = 1 AND d.DeviceStatus=N'''+N'מחכה לכיול'+''',1,NULL)) OVER( ORDER BY d.DeviceStatus),0) as DevicesWaitingForCalibrationCount
FROM ds as d
)
SELECT 
 ds.DeviceStatus
,ds.CalibratioinDate
,ds.NextCalibrationDate
,ds.CalibratioinLocation
,ds.DeviceDescription
,ds.SerialNumber
,ds.ActualReturnDate
,ds.CalibratorId
,ds.CalibratorFirstName
,ds.CalibratorLastName
,ds.CalibratorPhoneNumber
,ds.CalibratorAssigmentDate
,ds.OverallDevicesCount
,ds.ExpiredevicesCount
,ds.CalibratedDevicesCount
,ds.DevicesWaitingForCalibrationCount
,SUM(IsLatestOrder) OVER( ORDER BY ds.DeviceStatus) as ItemsCount
FROM devices_cnt as ds
WHERE ds.IsLatestOrder = 1'
,CASE WHEN @GlobalSearch IS NOT NULL THEN ' AND CONCAT(ds.DeviceDescription,ds.SerialNumber,ds.CalibratorFirstName,ds.CalibratorLastName,ds.CalibratorPhoneNumber) LIKE N''%'+ @GlobalSearch +'%'''ELSE ' ' END
,'ORDER BY ' , @OrderBy , CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END , ' OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')

PRINT CAST(@sql as VARCHAR(MAX))
EXEC (@sql)
GO

/* ================= dbo.GetCustomerSupportData ================= */
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 10/03/2026
-- Description:	Get customer support data. 
--              We can define only one employee as customer support contact
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerSupportData] 
@LoggedInUserEmail NVARCHAR(50)
AS

DECLARE @CustomerId INT = 0
DECLARE @SourceId TINYINT

SELECT 
	@CustomerId  = d.CustomerId 
	,@SourceId = d.SourceId
FROM [dbo].[Users] as d
WHERE d.Email = @LoggedInUserEmail 

SELECT 
	 u.FirstName
	,u.LastName
	,u.Email	
	,u.Phone
FROM [dbo].[Customers] as c
JOIN [dbo].[Users] as u ON c.[CustomerSupportContactId] = u.ID
WHERE c.CustomerId = @CustomerId
GO

/* ================= dbo.GetDevicesGroupsByOrder ================= */
CREATE OR ALTER PROCEDURE [dbo].[GetDevicesGroupsByOrder] 
	@OrderNumber NVARCHAR(20),
	@MainCategories NVARCHAR(MAX) = NULL,
	@SecondaryCategories NVARCHAR(MAX) = NULL,
	@DeviceManufacturer NVARCHAR(MAX) = NULL,
	@DeviceModels NVARCHAR(MAX) = NULL,
	@Page NVARCHAR(100) = 'coordinator-orders'
AS
BEGIN

SET NOCOUNT ON;

/*
Filter logic by page
/coordinator-orders - @page = ‘coordinator-orders’ 
/external-schedule - @page = ‘external-schedule’
/internal-orders - @page = ‘internal-orders’
/calibration-wizard - @page = ‘calibration-wizard’ 
/external-orders - @page = 'external-orders'
*/
/*-------------------------------------------------*/
DECLARE @ExtIntFilter BIT = NULL

IF @Page IN (N'external-schedule',N'external-orders',N'coordinator-orders') SET @ExtIntFilter = 0 -- IsInHouse = 0 for external orders

IF @Page IN (N'internal-orders') SET @ExtIntFilter = 1 -- IsInHouse = 0 for internal orders

/*-------------------------------------------------*/	

DROP TABLE IF EXISTS #MainCategories
CREATE TABLE #MainCategories
(
MainCategory NVARCHAR(50) 
)
INSERT #MainCategories(MainCategory)
SELECT DISTINCT CAST(v.Value AS NVARCHAR(50)) FROM dbo.ParseCSVToTable(@MainCategories) as v


DROP TABLE IF EXISTS #SecondaryCategories
CREATE TABLE #SecondaryCategories
(
SecondaryCategory NVARCHAR(50) 
)
INSERT #SecondaryCategories(SecondaryCategory)
SELECT DISTINCT v.Value FROM dbo.ParseCSVToTable(@SecondaryCategories) as v

DROP TABLE IF EXISTS #DeviceManufacturer
CREATE TABLE #DeviceManufacturer
(
DeviceManufacturer NVARCHAR(255) 
)
INSERT #DeviceManufacturer(DeviceManufacturer)
SELECT DISTINCT v.Value FROM dbo.ParseCSVToTable(@DeviceManufacturer) as v

DROP TABLE IF EXISTS #DeviceModels
CREATE TABLE #DeviceModels
(
DeviceModel NVARCHAR(30) 
)
INSERT #DeviceModels(DeviceModel)
SELECT DISTINCT v.Value FROM dbo.ParseCSVToTable(@DeviceModels) as v

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'SELECT DISTINCT
     op.OrderNumber
	,od.OrderWorkPlanId as OrderId
	,od.OrderDetailId
	--,itm.OrderDetailsItemId
	,opt.OrdersProductTypeName AS DeviceType
	,mc.ID AS DepartmentId
	,mc.MainCategoryName as MainCategory
	,sc.SecondaryCategoryName AS SecondCategory
	--,itm.OrderDetailsItemId
	--,itm.SerialNumber
	--,itm.DeviceModel
	--,itm.MbaReportNumber
	--,od.OrderDetailId
	,odm.OrdersDeviceManufacturerName as DeviceManufacturer
	,od.OrderLineCnt
	,od.PartName
	,odm.[StatusDescriptionHEB] as CalibrationStatus
	,odm.[StatusDescriptionENG] as CalibrationStatusENG 
	,ptxt.TextToCatalogNumber
	,dtxt.TextToDevice 
	--,itm.[IsChecked]
FROM [dbo].[OrderDetails] as od
JOIN [dbo].[OrderWorkPlans] as op ON od.OrderWorkPlanId = op.OrderWorkPlanId
LEFT JOIN [dbo].[OrderDetailsItems] as itm ON itm.OrderDetailId = od.OrderDetailId
LEFT JOIN [dbo].[MainCategories] as mc ON od.MainCategoryId = mc.ID
LEFT JOIN [dbo].[SecondaryCategories] sc ON od.SecondaryCategoryId = sc.ID
LEFT JOIN [dbo].[OrdersProductTypes] as opt ON od.OrdersProductTypeId = opt.OrdersProductTypeId
OUTER APPLY
(
SELECT TOP 1 itm.OrdersDeviceManufacturer as OrdersDeviceManufacturerName , cals.[StatusDescriptionHEB], [StatusDescriptionENG] 
FROM 
[dbo].[OrderDetailsItems] as itm
LEFT JOIN [dbo].[Statuses] as cals ON cals.[StatusId] = itm.[CalibrationStatusId]
) as odm
'
+ '
OUTER APPLY
(
    SELECT
        STRING_AGG(x.CleanText, NCHAR(10))
            WITHIN GROUP (ORDER BY x.TEXTORD, x.TEXTLINE) AS TextToCatalogNumber
    FROM (
        SELECT
            pt.TEXTORD,
            pt.TEXTLINE,
            CleanText =
                LTRIM(RTRIM(
                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        REVERSE(CAST(pt.[TEXT] AS NVARCHAR(MAX))),
                        N''<style> p,div,li'', N''''),
                        N''</style>'', N''''),
                        N''<style>'', N''''),
                        N''<P dir=rtl align=right>'', N''''),
                        N''<P dir=rtl>'', N''''),
                        N''dir=rtl>'', N''''),
                        N''<FONT size=3 face=David>'', N''''),
                        N''<FONT face=David size=3>'', N''''),
                        N''<FONT face=David size=2>'', N''''),
                        N''<FONT face=David>'', N''''),
                        N''</FONT>'', N''''),
                        N''<BR>'', NCHAR(10)),
                        N''</P>'', NCHAR(10)),
                        N''&nbsp;'', N'' ''),
                        N''<B>'', N''''),
                        N''</B>'', N''''),
                        N''<STRONG>'', N''''),
                        N''</STRONG>'', N''''),
                        N''</strong>'', N'''')
                ))
        FROM [31.168.173.93].[amaba].[dbo].[PARTTEXT] AS pt
        WHERE pt.PART = od.PART
    ) x
    WHERE x.CleanText <> N''''
      AND x.CleanText NOT LIKE N''%font-family%''
      AND x.CleanText NOT LIKE N''%font-size%''
      AND x.CleanText NOT LIKE N''%margin%''
      AND x.CleanText NOT LIKE N''%style%''
      AND x.CleanText NOT LIKE N''%p,div,li%''
) as ptxt

OUTER APPLY
(
    SELECT
        STRING_AGG(x.CleanText, NCHAR(10))
            WITHIN GROUP (ORDER BY x.TEXTORD, x.TEXTLINE) AS TextToDevice
    FROM (
        SELECT
            st.TEXTORD,
            st.TEXTLINE,
            CleanText =
                LTRIM(RTRIM(
                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        REVERSE(CAST(st.[TEXT] AS NVARCHAR(MAX))),
                        N''<style> p,div,li'', N''''),
                        N''</style>'', N''''),
                        N''<style>'', N''''),
                        N''<P dir=rtl align=right>'', N''''),
                        N''<P dir=rtl>'', N''''),
                        N''dir=rtl>'', N''''),
                        N''<FONT size=3 face=David>'', N''''),
                        N''<FONT face=David size=3>'', N''''),
                        N''<FONT face=David size=2>'', N''''),
                        N''<FONT face=David>'', N''''),
                        N''</FONT>'', N''''),
                        N''<BR>'', NCHAR(10)),
                        N''</P>'', NCHAR(10)),
                        N''&nbsp;'', N'' ''),
                        N''<B>'', N''''),
                        N''</B>'', N''''),
                        N''<STRONG>'', N''''),
                        N''</STRONG>'', N''''),
                        N''</strong>'', N'''')
                ))
        FROM [31.168.173.93].[amaba].[dbo].[SERNUMBERSTEXT] AS st
        WHERE st.SERN = itm.SERN AND od.OrderLineCnt = 1
    ) x
    WHERE x.CleanText <> N''''
      AND x.CleanText NOT LIKE N''%font-family%''
      AND x.CleanText NOT LIKE N''%font-size%''
      AND x.CleanText NOT LIKE N''%margin%''
      AND x.CleanText NOT LIKE N''%style%''
      AND x.CleanText NOT LIKE N''%p,div,li%''
) as dtxt
'
+'
'
,IIF(@MainCategories IS NOT NULL,' JOIN #MainCategories as mcf ON mc.MainCategoryName COLLATE DATABASE_DEFAULT = mcf.MainCategory COLLATE DATABASE_DEFAULT',' ')
,IIF(@SecondaryCategories IS NOT NULL,' JOIN #SecondaryCategories as scf ON sc.OrdersSecondaryCategoryName COLLATE DATABASE_DEFAULT   = scf.SecondaryCategory COLLATE DATABASE_DEFAULT ',' ')
,IIF(@DeviceManufacturer IS NOT NULL,' JOIN #DeviceManufacturer as dmf ON odm.OrdersDeviceManufacturerName COLLATE DATABASE_DEFAULT  = dmf.DeviceManufacturer COLLATE DATABASE_DEFAULT ',' ')
,IIF(@DeviceModels IS NOT NULL,' JOIN #DeviceModels as dm ON itm.DeviceModel COLLATE DATABASE_DEFAULT = dm.DeviceModel COLLATE DATABASE_DEFAULT ',' ')
,'
WHERE OrderNumber = TRIM(''',@OrderNumber,''')

'
,CASE WHEN @ExtIntFilter IS NOT NULL THEN ' AND od.IsInHouse='+CAST(@ExtIntFilter as NVARCHAR(MAX))+' 'ELSE ' ' END
)
PRINT @sql
EXEC sp_executesql @sql

END
GO

/* ================= dbo.GetDevicesUngroupedByOrder ================= */
-- =============================================

-- Author:		Eduard Kudlaiev

-- Create date: 24/11/2025

-- Description:	Get ungrouped devices data to show lowest level data about device for calibration

-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[GetDevicesUngroupedByOrder]

	@OrderNumber NVARCHAR(20) = NULL,

	@MainCategories NVARCHAR(MAX) = NULL,

	@SecondaryCategories NVARCHAR(MAX) = NULL,

	@DeviceManufacturer NVARCHAR(50) = NULL,

	@DeviceModels NVARCHAR(MAX) = NULL,

	@GlobalSearch NVARCHAR(MAX) = NULL,

	@Page NVARCHAR(100) = 'coordinator-orders',

    @PageNumber AS INT = 1,                  -- Resulting page for pagination, starting in 1

    @RowsOfPage AS INT = 10,                 -- Result page size

    @OrderBy AS NVARCHAR(MAX) = 'OrderNumber',      -- OrderBy column

    @OrderByAsc AS BIT = 1,                   -- OrderBy direction (ASC/DESC)

	@OrderWorkPlanIds NVARCHAR(MAX) = NULL,

	@OrderWorkDetailsItemsIds NVARCHAR(MAX) = NULL,

	@ExcludeAwaitingCollectionOrders BIT = 0

AS

BEGIN



SET NOCOUNT ON;



--IF @OrderNumber IS NULL OR @OrderWorkPlanIds IS NULL 

--	THROW 51000, 'Parameters @OrderNumber or @OrderWorkPlanIds should be specified.',1

/*

Filter logic by page

/coordinator-orders - @page = ‘coordinator-orders’ 

/external-schedule - @page = ‘external-schedule’

/internal-orders - @page = ‘internal-orders’

/calibration-wizard - @page = ‘calibration-wizard’ 

/external-orders - @page = 'external-orders'

*/

/*-------------------------------------------------*/



DECLARE @ExtIntFilter BIT = NULL



IF @Page IN (N'external-schedule',N'external-orders',N'coordinator-orders') SET @ExtIntFilter = 0 -- IsInHouse = 0 for external orders



IF @Page IN (N'internal-orders') SET @ExtIntFilter = 1 -- IsInHouse = 0 for internal orders



IF @ExcludeAwaitingCollectionOrders = 1

BEGIN

   

	DROP TABLE IF EXISTS #AwaitingCollectionOrders

	CREATE TABLE #AwaitingCollectionOrders(OrderWorkPlanId INT)



	INSERT #AwaitingCollectionOrders(OrderWorkPlanId)

	SELECT wp.OrderWorkPlanId

	FROM [dbo].[OrderWorkPlans] as wp

	JOIN Statuses as s ON wp.OrderOverallStatusId = s.StatusId

	WHERE s.StatusDescriptionENG='AwaitingCollection'

/*	SELECT od.OrderWorkPlanId

	FROM [dbo].[OrderDetails] as od

	JOIN [dbo].[OrderDetailsItems] as itm ON itm.OrderDetailId = od.OrderDetailId

	LEFT JOIN [dbo].[Statuses] as scs ON itm.CalibrationStatusId = scs.StatusId

	GROUP BY od.OrderWorkPlanId

	HAVING MIN(COALESCE(scs.StatusDescriptionENG,'N/A')) = MAX(COALESCE(scs.StatusDescriptionENG,'N/A'))

	AND MAX(COALESCE(scs.StatusDescriptionENG,'N/A')) IN('AwaitingCollection','ReadyForPacking','AwaitingCollection','ReadyForDelivery')

	*/

	CREATE UNIQUE CLUSTERED INDEX IDX_AwaitingCollectionOrders ON #AwaitingCollectionOrders(OrderWorkPlanId)







END



/*-------------------------------------------------*/	



/*IF @OrderBy NOT IN 

(N'OrderNumber',

N'OrderId',N'OrderDetailId',N'OrderDetailsItemId',

N'DeviceType',N'DepartmentId',N'MainCategory',N'SecondCategory',N'SerialNumber',N'AdditionalDeviceNumber',N'DeviceModel',N'MbaReportNumber',N'DeviceManufacturer',

N'CalibrationStatus',N'IsChecked',N'CustomerId',N'ActualCalibrationDate',N'CalibrationDeadline',N'CustomerName',N'Calibrators',N'SpecialTreatment'

)

THROW 51000, 'Incorrect value for parameter @OrderBy. Available values 

|OrderNumber

|OrderId|OrderDetailId|OrderDetailsItemId

|DeviceType|DepartmentId|MainCategory|SecondCategory|SerialNumber|AdditionalDeviceNumber|DeviceModel|MbaReportNumber|DeviceManufacturer

|CalibrationStatus|IsChecked|CustomerId|ActualCalibrationDate|CalibrationDeadline|CustomerName|Calibrators|SpecialTreatment

', 1;*/



DROP TABLE IF EXISTS #MainCategories

CREATE TABLE #MainCategories

(

MainCategory NVARCHAR(50) 

)

INSERT #MainCategories(MainCategory)

SELECT DISTINCT CAST(v.Value AS NVARCHAR(50)) FROM dbo.ParseCSVToTable(@MainCategories) as v





DROP TABLE IF EXISTS #SecondaryCategories

CREATE TABLE #SecondaryCategories

(

SecondaryCategory NVARCHAR(50) 

)

INSERT #SecondaryCategories(SecondaryCategory)

SELECT DISTINCT v.Value FROM dbo.ParseCSVToTable(@SecondaryCategories) as v



DROP TABLE IF EXISTS #DeviceModels

CREATE TABLE #DeviceModels

(

DeviceModel NVARCHAR(30) 

)

INSERT #DeviceModels(DeviceModel)

SELECT DISTINCT v.Value FROM dbo.ParseCSVToTable(@DeviceModels) as v





DECLARE @StatusesForOrders NVARCHAR(MAX)



SELECT @StatusesForOrders=STRING_AGG(s.StatusId,',')

FROM [dbo].[Statuses] as s

JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId

WHERE sc.StatusDescriptionENG='OrderStatus' AND s.StatusDescriptionENG <> 'Executed'





DECLARE @sql NVARCHAR(MAX) =

CONCAT(

'SELECT

     IIF(',COALESCE(@ExtIntFilter,0),' = 1,itm.MbaReportNumber,op.OrderNumber) as OrderNumber

	,od.OrderWorkPlanId as OrderId

	,od.OrderDetailId

	,itm.OrderDetailsItemId

	,opt.OrdersProductTypeName AS DeviceType

	,mc.ID AS DepartmentId

	,mc.MainCategoryName as MainCategory

	,sc.SecondaryCategoryName AS SecondCategory

	,itm.SerialNumber

    ,itm.AdditionalDeviceNumber

	,itm.DeviceModel

	,itm.MbaReportNumber

	,itm. OrdersDeviceManufacturer as DeviceManufacturer

	,cals.[StatusDescriptionHEB] as CalibrationStatus

	,ordst.[StatusDescriptionHEB] as OrderStatus

	,ordst.[StatusDescriptionENG] as OrderStatusENG

	,itm.[IsChecked]

	,op.[CustomerId]

	,itm.[ActualCalibrationDate]

	,itm.ExpectedReturnDate as CalibrationDeadline

	,c.CustomerName

	,cbl.Calibrators

	,scs.StatusDescriptionHEB as SpecialTreatment

	,itm.CustomerReceivingDate	

	,itm.ShippingDoc	

	,itm.ShippingAddress

	,c.CustomerAddress

	,custeqv.details as AdditionalEquipment

	,op.ShipTypeDesc as ShippingMethod

	,itm.[StickerAmount]

	,stist.[StatusDescriptionHEB] as [StickerType]

	,COUNT(1) OVER() as ItemsCount

FROM [dbo].[OrderDetails] as od

JOIN [dbo].[OrderWorkPlans] as op ON od.OrderWorkPlanId = op.OrderWorkPlanId

LEFT JOIN [dbo].[Statuses] as scs ON od.SpecialCareTypeId = scs.StatusId

LEFT JOIN [dbo].[OrderDetailsItems] as itm ON itm.OrderDetailId = od.OrderDetailId

LEFT JOIN [dbo].[Customers] as c ON op.[CustomerId] = c.[CustomerId]

LEFT JOIN [dbo].[MainCategories] as mc ON od.MainCategoryId = mc.ID

LEFT JOIN [dbo].[SecondaryCategories] sc ON od.SecondaryCategoryId = sc.ID

LEFT JOIN [dbo].[OrdersProductTypes] as opt ON od.OrdersProductTypeId = opt.OrdersProductTypeId

LEFT JOIN [dbo].[Statuses] as cals ON cals.[StatusId] = itm.[CalibrationStatusId]

LEFT JOIN [dbo].[Statuses] as ordst ON ordst.[StatusId] = op.[OrderOverallStatusId]

LEFT JOIN [dbo].[Statuses] as stist ON stist.[StatusId] = itm.[StickerTypeId]

OUTER APPLY

(

SELECT [OrderWorkPlanId]

      ,STRING_AGG(CONCAT(u.FirstName,'' '',u.LastName),'','') as Calibrators

  FROM [dbo].[CalibratorsToWorkPlan] as c

  JOIN [dbo].[Users] as u ON c.[CalibratorId] = u.[ID]

  WHERE op.OrderWorkPlanId = c.[OrderWorkPlanId] 

  GROUP BY [OrderWorkPlanId]

) as cbl 

OUTER APPLY

(

SELECT

    d.OrderDetailsItemId,

    ''['' +

    STRING_AGG(

        CONCAT(''{'',

       ''"ItemsCount":'', d.[ItemsCount],'','',

       ''"AccessoryDescription":'',''"'',d.[AccessoryDescription],''",'',

       ''"AccessoryLocation":'',''"'',d.[AccessoryLocation],''"'',

       ''}''

        ),

        '',''

    )

    + '']'' AS details

FROM [dbo].[ClientAccessoryOrderDetailsItems] AS d

WHERE d.OrderDetailsItemId = itm.OrderDetailsItemId

GROUP BY d.OrderDetailsItemId

) as custeqv

'

,IIF(@OrderWorkPlanIds IS NOT NULL,' JOIN STRING_SPLIT('''+@OrderWorkPlanIds+''','','') as wpf ON op.OrderWorkPlanId = wpf.value',' ')

,IIF(@OrderWorkDetailsItemsIds IS NOT NULL,' JOIN STRING_SPLIT('''+@OrderWorkDetailsItemsIds+''','','') as wpf1 ON itm.OrderDetailsItemId = wpf1.value',' ')

,IIF(@MainCategories IS NOT NULL,' JOIN #MainCategories as mcf ON mc.MainCategoryName COLLATE DATABASE_DEFAULT = mcf.MainCategory COLLATE DATABASE_DEFAULT',' ')

,IIF(@SecondaryCategories IS NOT NULL,' JOIN #SecondaryCategories as scf ON sc.SecondaryCategoryName COLLATE DATABASE_DEFAULT   = scf.SecondaryCategory COLLATE DATABASE_DEFAULT ',' ')

,IIF(@DeviceModels IS NOT NULL,' JOIN #DeviceModels as dm ON itm.DeviceModel COLLATE DATABASE_DEFAULT = dm.DeviceModel COLLATE DATABASE_DEFAULT ',' ')

,'

WHERE op.OrderOverallStatusId IN(',@StatusesForOrders,') 

'

,IIF(@ExcludeAwaitingCollectionOrders = 1,'AND NOT EXISTS (SELECT 1 FROM #AwaitingCollectionOrders as f WHERE f.OrderWorkPlanId = op.OrderWorkPlanId)','')

,IIF(@OrderNumber IS NOT NULL,'AND op.OrderNumber = TRIM('''+@OrderNumber+''')',' ')

,IIF(@DeviceManufacturer IS NOT NULL,'AND itm.OrdersDeviceManufacturer LIKE ''%'+@DeviceManufacturer+'%''',' ')

,CASE WHEN @ExtIntFilter IS NOT NULL THEN ' AND od.IsInHouse='+CAST(@ExtIntFilter as NVARCHAR(MAX))+' 'ELSE ' ' END
/* The packing team works from the delivery note, so an item without one has nothing
   to pack against. Scoped to @Page='packing' so no other screen changes. */
,CASE WHEN @Page = N'packing'
      THEN ' AND NULLIF(LTRIM(RTRIM(itm.ShippingDoc)),'''') IS NOT NULL '
      ELSE ' ' END

 ,CASE WHEN @GlobalSearch IS NOT NULL THEN ' AND CONCAT(op.OrderNumber,opt.OrdersProductTypeName,mc.MainCategoryName,sc.SecondaryCategoryName,itm.SerialNumber,itm.AdditionalDeviceNumber,itm.DeviceModel,itm.MbaReportNumber,itm.OrdersDeviceManufacturer,cals.[StatusDescriptionHEB],c.CustomerName,cbl.Calibrators,scs.StatusDescriptionHEB) LIKE N''%'+ @GlobalSearch +'%'''ELSE ' ' END

,  'ORDER BY ' , @OrderBy , CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END , ' OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')



PRINT @sql

EXEC sp_executesql @sql



END
GO

/* ================= dbo.GetDevicesUngroupedByOrderV2 ================= */
CREATE OR ALTER PROCEDURE [dbo].[GetDevicesUngroupedByOrderV2]
    @OrderNumber NVARCHAR(20) = NULL,
    @MainCategories NVARCHAR(MAX) = NULL,
    @SecondaryCategories NVARCHAR(MAX) = NULL,
    @DeviceManufacturer NVARCHAR(50) = NULL,
    @DeviceModels NVARCHAR(MAX) = NULL,
    @GlobalSearch NVARCHAR(MAX) = NULL,
    @Page NVARCHAR(100) = 'coordinator-orders',
    @PageNumber AS INT = 1,
    @RowsOfPage AS INT = 10,
    @OrderBy AS NVARCHAR(MAX) = 'OrderNumber',
    @OrderByAsc AS BIT = 1,
    @OrderWorkPlanIds NVARCHAR(MAX) = NULL,
    @OrderWorkDetailsItemsIds NVARCHAR(MAX) = NULL,
    @ExcludeAwaitingCollectionOrders BIT = 0
AS
BEGIN
SET NOCOUNT ON;

DECLARE @ExtIntFilter BIT = NULL

IF @Page IN (N'external-schedule', N'external-orders', N'coordinator-orders') SET @ExtIntFilter = 0
IF @Page IN (N'internal-orders') SET @ExtIntFilter = 1

IF @ExcludeAwaitingCollectionOrders = 1
BEGIN
    DROP TABLE IF EXISTS #AwaitingCollectionOrders
    CREATE TABLE #AwaitingCollectionOrders(OrderWorkPlanId INT)

    INSERT #AwaitingCollectionOrders(OrderWorkPlanId)
    SELECT wp.OrderWorkPlanId
    FROM [dbo].[OrderWorkPlans] as wp
    JOIN Statuses as s ON wp.OrderOverallStatusId = s.StatusId
    WHERE s.StatusDescriptionENG = 'AwaitingCollection'

    CREATE UNIQUE CLUSTERED INDEX IDX_AwaitingCollectionOrders
    ON #AwaitingCollectionOrders(OrderWorkPlanId)
END

DROP TABLE IF EXISTS #MainCategories
CREATE TABLE #MainCategories(MainCategory NVARCHAR(50))

INSERT #MainCategories(MainCategory)
SELECT DISTINCT CAST(v.Value AS NVARCHAR(50))
FROM dbo.ParseCSVToTable(@MainCategories) as v

DROP TABLE IF EXISTS #SecondaryCategories
CREATE TABLE #SecondaryCategories(SecondaryCategory NVARCHAR(50))

INSERT #SecondaryCategories(SecondaryCategory)
SELECT DISTINCT v.Value
FROM dbo.ParseCSVToTable(@SecondaryCategories) as v

DROP TABLE IF EXISTS #DeviceModels
CREATE TABLE #DeviceModels(DeviceModel NVARCHAR(30))

INSERT #DeviceModels(DeviceModel)
SELECT DISTINCT v.Value
FROM dbo.ParseCSVToTable(@DeviceModels) as v

DECLARE @StatusesForOrders NVARCHAR(MAX)

SELECT @StatusesForOrders = STRING_AGG(s.StatusId, ',')
FROM [dbo].[Statuses] as s
JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
WHERE sc.StatusDescriptionENG = 'OrderStatus'
  AND s.StatusDescriptionENG <> 'Executed'

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
N'SELECT
     IIF(', COALESCE(CAST(@ExtIntFilter AS NVARCHAR(1)), N'0'), N' = 1, itm.MbaReportNumber, op.OrderNumber) as OrderNumber
    ,od.OrderWorkPlanId as OrderId
    ,od.OrderDetailId
    ,itm.OrderDetailsItemId
    ,od.PART as CatalogPartId
    ,od.PartName as CatalogNumber
    ,itm.SERN
    ,opt.OrdersProductTypeName AS DeviceType
    ,mc.ID AS DepartmentId
    ,mc.MainCategoryName as MainCategory
    ,sc.SecondaryCategoryName AS SecondCategory
    ,itm.SerialNumber
    ,itm.AdditionalDeviceNumber
    ,itm.DeviceModel
    ,itm.MbaReportNumber
    ,itm.OrdersDeviceManufacturer as DeviceManufacturer
    ,cals.[StatusDescriptionHEB] as CalibrationStatus
    ,ordst.[StatusDescriptionHEB] as OrderStatus
    ,ordst.[StatusDescriptionENG] as OrderStatusENG
    ,itm.[IsChecked]
    ,op.[CustomerId]
    ,itm.[ActualCalibrationDate]
    ,itm.ExpectedReturnDate as CalibrationDeadline
    ,c.CustomerName
    ,cbl.Calibrators
    ,scs.StatusDescriptionHEB as SpecialTreatment
    ,itm.CustomerReceivingDate
    ,itm.ShippingDoc
    ,itm.ShippingAddress
    ,c.CustomerAddress
    ,custeqv.details as AdditionalEquipment
    ,op.ShipTypeDesc as ShippingMethod
    ,itm.[StickerAmount]
    ,stist.[StatusDescriptionHEB] as [StickerType]
    ,ct.CatalogText as TextToCatalogNumber
    ,dt.DeviceText as TextToDevice
    ,op.CustomerComment
    ,COUNT(1) OVER() as ItemsCount
FROM [dbo].[OrderDetails] as od
JOIN [dbo].[OrderWorkPlans] as op ON od.OrderWorkPlanId = op.OrderWorkPlanId
LEFT JOIN [dbo].[Statuses] as scs ON od.SpecialCareTypeId = scs.StatusId
LEFT JOIN [dbo].[OrderDetailsItems] as itm ON itm.OrderDetailId = od.OrderDetailId
LEFT JOIN [dbo].[Customers] as c ON op.[CustomerId] = c.[CustomerId]
LEFT JOIN [dbo].[MainCategories] as mc ON od.MainCategoryId = mc.ID
LEFT JOIN [dbo].[SecondaryCategories] sc ON od.SecondaryCategoryId = sc.ID
LEFT JOIN [dbo].[OrdersProductTypes] as opt ON od.OrdersProductTypeId = opt.OrdersProductTypeId
LEFT JOIN [dbo].[Statuses] as cals ON cals.[StatusId] = itm.[CalibrationStatusId]
LEFT JOIN [dbo].[Statuses] as ordst ON ordst.[StatusId] = op.[OrderOverallStatusId]
LEFT JOIN [dbo].[Statuses] as stist ON stist.[StatusId] = itm.[StickerTypeId]
LEFT JOIN [dbo].[CrmCatalogText] as ct ON ct.PART = od.PART
LEFT JOIN [dbo].[CrmDeviceText] as dt ON dt.SERN = itm.SERN

OUTER APPLY
(
    SELECT
        [OrderWorkPlanId],
        STRING_AGG(CONCAT(u.FirstName, '' '', u.LastName), '','') as Calibrators
    FROM [dbo].[CalibratorsToWorkPlan] as c
    JOIN [dbo].[Users] as u ON c.[CalibratorId] = u.[ID]
    WHERE op.OrderWorkPlanId = c.[OrderWorkPlanId]
    GROUP BY [OrderWorkPlanId]
) as cbl

OUTER APPLY
(
    SELECT
        d.OrderDetailsItemId,
        ''['' +
        STRING_AGG(
            CONCAT(
                ''{'',
                ''"ItemsCount":'', d.[ItemsCount], '','',
                ''"AccessoryDescription":'', ''"'', d.[AccessoryDescription], ''","'',
                ''"AccessoryLocation":'', ''"'', d.[AccessoryLocation], ''"'',
                ''}''
            ),
            '',''
        )
        + '']'' AS details
    FROM [dbo].[ClientAccessoryOrderDetailsItems] AS d
    WHERE d.OrderDetailsItemId = itm.OrderDetailsItemId
    GROUP BY d.OrderDetailsItemId
) as custeqv
'
,IIF(@OrderWorkPlanIds IS NOT NULL, N' JOIN STRING_SPLIT(''' + @OrderWorkPlanIds + N''', '','') as wpf ON op.OrderWorkPlanId = wpf.value', N' ')
,IIF(@OrderWorkDetailsItemsIds IS NOT NULL, N' JOIN STRING_SPLIT(''' + @OrderWorkDetailsItemsIds + N''', '','') as wpf1 ON itm.OrderDetailsItemId = wpf1.value', N' ')
,IIF(@MainCategories IS NOT NULL, N' JOIN #MainCategories as mcf ON mc.MainCategoryName COLLATE DATABASE_DEFAULT = mcf.MainCategory COLLATE DATABASE_DEFAULT', N' ')
,IIF(@SecondaryCategories IS NOT NULL, N' JOIN #SecondaryCategories as scf ON sc.SecondaryCategoryName COLLATE DATABASE_DEFAULT = scf.SecondaryCategory COLLATE DATABASE_DEFAULT ', N' ')
,IIF(@DeviceModels IS NOT NULL, N' JOIN #DeviceModels as dm ON itm.DeviceModel COLLATE DATABASE_DEFAULT = dm.DeviceModel COLLATE DATABASE_DEFAULT ', N' ')
,N'
WHERE op.OrderOverallStatusId IN(', @StatusesForOrders, N')
'
,IIF(@ExcludeAwaitingCollectionOrders = 1, N'AND NOT EXISTS (SELECT 1 FROM #AwaitingCollectionOrders as f WHERE f.OrderWorkPlanId = op.OrderWorkPlanId)', N'')
,IIF(@OrderNumber IS NOT NULL, N'AND op.OrderNumber = TRIM(''' + @OrderNumber + N''')', N' ')
,IIF(@DeviceManufacturer IS NOT NULL, N'AND itm.OrdersDeviceManufacturer LIKE ''%' + @DeviceManufacturer + N'%''', N' ')
,CASE WHEN @ExtIntFilter IS NOT NULL THEN N' AND od.IsInHouse=' + CAST(@ExtIntFilter as NVARCHAR(MAX)) + N' ' ELSE N' ' END
,CASE WHEN @GlobalSearch IS NOT NULL THEN
    N' AND CONCAT(op.OrderNumber,opt.OrdersProductTypeName,mc.MainCategoryName,sc.SecondaryCategoryName,itm.SerialNumber,itm.AdditionalDeviceNumber,itm.DeviceModel,itm.MbaReportNumber,itm.OrdersDeviceManufacturer,cals.[StatusDescriptionHEB],c.CustomerName,cbl.Calibrators,scs.StatusDescriptionHEB,od.PART,od.PartName,itm.SERN,ct.CatalogText,dt.DeviceText,op.CustomerComment) LIKE N''%' + @GlobalSearch + N'%'''
 ELSE N' ' END
,N'ORDER BY ', @OrderBy,
  CASE WHEN @OrderByAsc = 1 THEN N' ASC' WHEN @OrderByAsc = 0 THEN N' DESC' ELSE N'' END,
  N' OFFSET ', (@PageNumber - 1) * @RowsOfPage,
  N' ROWS FETCH NEXT ', @RowsOfPage,
  N' ROWS ONLY OPTION(RECOMPILE); '
)

PRINT @sql
EXEC sp_executesql @sql

END
GO

/* ================= dbo.GetLogersConfiguredByCalibrator ================= */
/*
    dbo.GetLogersConfiguredByCalibrator
    ---------------------------------------------------------------------------------------------
    Original author: Eduard Kudlaiev, 02/07/2025
    The loggers a calibrator has configured, for the logger-connection popup.

    2026-08-24 (MBA-902): the popup showed "0" under מס' נקודות for every logger, and the channel
    picker had nothing to size itself from. The reason was simply that this proc never returned the
    number - MeasurementDevices.ConnectionPoints holds it (21-142 = 21, 31-80 = 61) but no
    procedure exposed it. Channel count is a property of the LOGGER, not of the sensor, so it
    belongs here.

    Added, all straight off the logger's own row, no filter or row changes:
        MabaID, Model, Manufacturer   - identity, so the caller need not look it up separately
        ConnectionPoints              - how many channels this logger has
    Plus a deterministic ORDER BY: the list came back in whatever order the join produced, which
    made the dropdown reshuffle between calls.

    MabaID sorts on its two numeric segments rather than as text, so 21-9 comes before 21-86.
    The DISTINCT is kept in a derived table because ORDER BY cannot reference expressions that are
    not in a DISTINCT select list, and the sort keys are not worth returning to the caller.

    2026-08-25 (MBA-902): the popup showed every logger anyone had ever configured. This procedure
    resolved @LoggedInUserId and @SourceId at the top and then never used them, so a calibrator saw
    other people's work and could not find their own.

    It now returns the loggers THIS caller configured. Relations with no owner recorded are still
    returned: SensorToLoggerRelation.UpdateUserID was NULL on every row because the insert in
    dbo.AssignMeasurmentDevicesToCalibrator named only the two device ids and never the user. That
    is fixed on the write side as of the same date, so the unowned set is historical and shrinks;
    dropping it instead would have emptied the popup for everyone on the day of the change.

    Pass @OnlyMine = 0 to see every configured logger, which is what this did before.
*/
CREATE OR ALTER PROCEDURE [dbo].[GetLogersConfiguredByCalibrator] 
@LoggedInUserEmail NVARCHAR(100),
@OnlyMine BIT = 1
AS
BEGIN
SET NOCOUNT ON;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

	SELECT
	       l.LoggerMeasurementDeviceId,
	       l.FlowRate,
	       l.Interval,
	       l.CommunicationProtocol,
	       l.CommunicationDetails,
	       l.MabaID,
	       l.Model,
	       l.Manufacturer,
	       l.ConnectionPoints,
	       l.CountAssignedLoggers
	FROM (
		SELECT DISTINCT
		       ltc.ID as LoggerMeasurementDeviceId,
		       ltc.FlowRate,	
			   ltc.Interval,	
			   ltc.Connection as CommunicationProtocol,	
			   ltc.IP AS CommunicationDetails,
			   -- MBA-902: identity + channel count, which the popup had no way to get
			   ltc.MabaID,
			   ltc.Model,
			   ltc.Manufacturer,
			   ltc.ConnectionPoints,
			   SUM(1) OVER( PARTITION BY ltc.ID) as CountAssignedLoggers
		FROM dbo.MeasurementDevices as ltc
		JOIN dbo.MeasurementDevicesMainClasses as mc ON ltc.MainClassId = mc.Id
		JOIN dbo.SensorToLoggerRelation as srl ON ltc.ID = srl.LoggerMeasurementDeviceId AND srl.IsDeleted = 0
		WHERE mc.NameEnglish = 'Data logger' AND ltc.IsDeleted = 0
		  -- MBA-902: this caller's own configurations, plus the ones that predate owner tracking
		  AND (@OnlyMine = 0
		       OR srl.UpdateUserID = @LoggedInUserId
		       OR srl.UpdateUserID IS NULL)
	) AS l
	ORDER BY
		 TRY_CAST(LEFT(l.MabaID, CHARINDEX('-', l.MabaID + '-') - 1) AS INT),
		 TRY_CAST(LEFT(STUFF(l.MabaID, 1, CHARINDEX('-', l.MabaID + '-'), ''),
		               CHARINDEX('/', STUFF(l.MabaID, 1, CHARINDEX('-', l.MabaID + '-'), '') + '/') - 1) AS INT),
		 l.MabaID

END
GO

/* ================= dbo.GetOrderDetailsDevices ================= */
-- =============================================
-- Author:		Kate Zashalovska
-- Create date: 18/06/2026
-- Description:	
-- JiraLink: 
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[GetOrderDetailsDevices] 
@OrderWorkPlanId INT,
@OrderDetailId INT = NULL,
@LoggedInUserEmail NVARCHAR(50) = NULL,
@OrderDetailsItems INT =NULL
AS

DECLARE @LoggedInUserId INT = 0
DECLARE @SourceId TINYINT
DECLARE @IsUserCalibrator BIT 

SELECT 
	@LoggedInUserId  = d.UserId 
   ,@SourceId = d.SourceId
   ,@IsUserCalibrator = IIF(ur.UserRoleName = N'Calibrator',1,0)
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d
JOIN dbo.Users as u ON d.UserId  = u.ID
JOIN dbo.UserRoles as ur ON u.UserRoleId = ur.UserRoleId


;WITH numbers
as
(
SELECT 1 as cnt, od.OrderLineCnt, od.OrderDetailId, od.OrdersProductTypeId, od.OrderWorkPlanId
FROM [dbo].[OrderDetails] as od 
WHERE od.OrderWorkPlanId = @OrderWorkPlanId
UNION ALL
SELECT n.cnt +1, od.OrderLineCnt, od.OrderDetailId, od.OrdersProductTypeId, od.OrderWorkPlanId
FROM numbers as n
JOIN [dbo].[OrderDetails] as od ON od.OrderDetailId = n.OrderDetailId AND od.OrderLineCnt = n.OrderLineCnt
WHERE od.OrderWorkPlanId = @OrderWorkPlanId
AND cnt < od.OrderLineCnt
)
,
result as
(
SELECT 
wp.[OrderWorkPlanId],
wp.[OrderNumber],
wp.[CustomerId],
cust.[CustomerName],
cust.[CustomerNameENG],
cust.[CustomerAddress] as [CustAddress],
cust.[CustomerCity] as [CustCity],
cust.[CustomerAddressENG] as [CustAddressENG],
cust.[CustomerCityENG] as [CustCityENG],
od.[OrderDetailId],
od.[OrderLineCnt],
od.[OrdersProductTypeId],
opt.[OrdersProductTypeName] as [OrdersProductType],
odi.[OrderDetailsItemId],
GETDATE() AS [ActualCalibrationDate],	
odi.[NextCalibrationDate],	
odi.[SerialNumber],
odi.[ManufacturerNumber],
odi.[DeviceModel],
odi.[AdditionalDeviceNumber],	
odi.[MbaReportNumber],
od.[MainCategoryId],	
omc.[MainCategoryName] as [OrdersMainCategory],
od.SecondaryCategoryId as [OrdersSecondaryCategoryId],
oc.[SecondaryCategoryName] as [OrdersSecondaryCategory],
odi.[CalibrationSpecificationId],
mc.Name as [CalibrationSpecification],
odi.[SpecificationReferenceId],	
sr.[Name] as [SpecificationReference],
odi.[MeasurementUnitId],
mu.ShortNameHe as [MeasurementUnit],
odi.[MeasurementPoints],	
odi.[MeasurementValueList],	
odi.[ProductLocation],
--e.[EquipmentNames], will be deprecated
scs.[StatusDescriptionENG] as [CalibrationStatus],
scs.[StatusDescriptionHEB] as [CalibrationStatusHEB],
odi.Accuracy,
odi.IsManuallyAdded,
odi.IsChecked,
odi.StickerAmount,
odi.StickerTypeId,
stit.StatusDescriptionHEB as StickerType,
ROW_NUMBER() OVER( PARTITION BY odi.OrderDetailId ORDER BY odi.OrderDetailId) as rn
 FROM [dbo].[OrderWorkPlans] as wp 
JOIN  [dbo].[OrderDetails] as od ON od.OrderWorkPlanId = wp.OrderWorkPlanId
LEFT JOIN [dbo].[Customers] as cust ON wp.CustomerId = cust.CustomerId
LEFT JOIN [dbo].[OrderDetailsItems] as odi ON od.OrderDetailId = odi.OrderDetailId
LEFT JOIN [dbo].[OrdersProductTypes] as opt ON od.[OrdersProductTypeId] = opt.[OrdersProductTypeId]
LEFT JOIN [dbo].[MainCategories] as omc ON od.[MainCategoryId] = omc.ID
LEFT JOIN [dbo].[SecondaryCategories] as oc ON od.[SecondaryCategoryId] = oc.ID
LEFT JOIN [dbo].[MeasurementsSpecifications] mc ON odi.[CalibrationSpecificationId] = mc.ID
LEFT JOIN [dbo].[SpecificationReference] as sr ON odi.[SpecificationReferenceId] = sr.ID
LEFT JOIN [dbo].[MeasurementDeviceUnits] as mu ON odi.[MeasurementUnitId] = mu.MeasurementDeviceUnitId
LEFT JOIN [dbo].[Statuses] as scs ON odi.[CalibrationStatusId] = scs.StatusId
LEFT JOIN [dbo].[Statuses] as stit ON odi.StickerTypeId = stit.StatusId
LEFT JOIN [dbo].[CalibratorsToWorkPlan] as ctwp ON ctwp.[OrderWorkPlanId] = wp.[OrderWorkPlanId] AND ctwp.[CalibratorId] = @LoggedInUserId AND ctwp.IsDeleted = 0
WHERE wp.[OrderWorkPlanId] = @OrderWorkPlanId 
)
SELECT
FIRST_VALUE(r.[OrderWorkPlanId]) OVER(ORDER BY r.[OrderWorkPlanId] DESC) as [OrderWorkPlanId],
FIRST_VALUE(r.[OrderNumber]) OVER(ORDER BY r.[OrderWorkPlanId] DESC) as [OrderNumber],
FIRST_VALUE(r.[CustomerId]) OVER(ORDER BY r.[OrderWorkPlanId] DESC) as [CustomerId],
FIRST_VALUE(r.[CustomerName]) OVER(ORDER BY r.[OrderWorkPlanId] DESC) as [CustomerName],
FIRST_VALUE(r.[CustomerNameENG]) OVER(ORDER BY r.[OrderWorkPlanId] DESC) as [CustomerNameENG],
FIRST_VALUE(COALESCE(r.[OrderDetailId],n.[OrderDetailId])) OVER(PARTITION BY r.[OrderDetailId] ORDER BY r.[OrderDetailId]) as [OrderDetailId],
FIRST_VALUE(COALESCE(r.[OrderLineCnt],n.[OrderLineCnt])) OVER(PARTITION BY r.[OrderDetailId] ORDER BY r.[OrderDetailId]) as [OrderLineCnt],
FIRST_VALUE(COALESCE(r.[OrdersProductTypeId],n.[OrdersProductTypeId])) OVER(PARTITION BY r.[OrderDetailId] ORDER BY r.[OrderDetailId]) as [OrdersProductTypeId],
COALESCE(opt1.[OrdersProductTypeName],opt2.[OrdersProductTypeName]) AS [OrdersProductType],
COALESCE(opt1.[OrdersProductTypeNameENG],opt2.[OrdersProductTypeNameENG]) AS [OrdersProductTypeENG],
r.[OrderDetailsItemId],
r.[ActualCalibrationDate],	
r.[NextCalibrationDate],	
r.[SerialNumber],
r.[ManufacturerNumber],
r.[DeviceModel],
r.[AdditionalDeviceNumber],	
CASE 
	WHEN @IsUserCalibrator = 1 THEN IIF(CHARINDEX(ctwp.OrderDetailsMbaReportNumber,r.[MbaReportNumber] ) <> 0,r.[MbaReportNumber],CONCAT(ctwp.OrderDetailsMbaReportNumber,'',ROW_NUMBER() OVER (PARTITION BY COALESCE(r.[OrderWorkPlanId],n.[OrderWorkPlanId]) ORDER BY r.[OrderWorkPlanId])  ))
ELSE r.[MbaReportNumber]
END as [MbaReportNumber],
r.[MainCategoryId] as [OrdersMainCategoryId],	
r.[OrdersMainCategory],
r.[OrdersSecondaryCategoryId],	
r.[OrdersSecondaryCategory],
r.[CalibrationSpecificationId],	
r.[CalibrationSpecification],
r.[SpecificationReferenceId],	
r.[SpecificationReference],
r.[MeasurementUnitId],
r.[MeasurementUnit],
r.[MeasurementPoints],	
r.[MeasurementValueList],	
r.[ProductLocation],
--r.[EquipmentNames],
r.[CalibrationStatus],
r.[CalibrationStatusHEB],
r.[Accuracy],
r.[IsManuallyAdded],
r.IsChecked,
r.StickerAmount,
r.StickerTypeId,
r.StickerType,
ds.EnvironmentalConditions,
odi.SecondCalibratorId,
odi.MainCalibratorId,
odi.Volume,
odi.VisualCheck,
odi.ShouldShowGraphV, 
odi.ShouldShowCertificateIcon,
odi.RequiredProbability,
odi.ReportLanguage,
CONCAT(u.FirstName,' ',u.LastName) as CalibratorFullName,
COALESCE(odi.SiteAddress,cs.CustomerSiteAddress, CONCAT(r.[CustAddress], ', ', r.[CustCity])) as SiteAddress,
COALESCE(cs.CustomerSiteAddressENG, IIF(r.[CustAddressENG] IS NOT NULL AND r.[CustCityENG] IS NOT NULL, CONCAT(r.[CustAddressENG], ', ', r.[CustCityENG]), r.[CustAddressENG])) as SiteAddressENG,
odi.ProductLocation,
odi.[OrdersDeviceManufacturer],
odi.[ControllerType],
odi.[DiagramMapLink],
-- MBA-666: Calibration Item / device description sourced from Priority (amaba.dbo.PART +
-- FAMILY) and the CRM free-text blocks, all served from the local cache refreshed by
-- dbo.RefreshCrmTextCache - no per-request linked-server round-trip.
cpi.[PartDescription]   as [PartDescription],    -- PART.PARTDES  (numbers appear in visual order)
cpi.[FamilyId]          as [DeviceFamilyId],     -- PART.FAMILY
cpi.[FamilyDescription] as [DeviceFamily],       -- FAMILY.FAMILYDES, e.g. מאזניים / מד לחץ / תנור
cct.[CatalogText]       as [TextToCatalogNumber],-- טקסט למק"ט   (PARTTEXT)
cdt.[DeviceText]        as [TextToDevice]        -- טקסט למכשיר  (SERNUMBERSTEXT)
FROM  numbers as n
LEFT JOIN result as r ON  r.OrderDetailId = n.OrderDetailId and r.rn = n.cnt 
LEFT JOIN [dbo].[OrdersProductTypes] as opt1 ON n.[OrdersProductTypeId] = opt1.[OrdersProductTypeId]
LEFT JOIN [dbo].[OrdersProductTypes] as opt2 ON r.[OrdersProductTypeId] = opt2.[OrdersProductTypeId]
LEFT JOIN [dbo].[CalibratorsToWorkPlan] as ctwp ON ctwp.[OrderWorkPlanId] = COALESCE(r.[OrderWorkPlanId],n.[OrderWorkPlanId]) AND ctwp.[CalibratorId] = @LoggedInUserId AND ctwp.IsDeleted = 0
LEFT JOIN [dbo].[OrderDetailsItems] as odi ON n.OrderDetailId = odi.OrderDetailId AND odi.[OrderDetailsItemId] = r.[OrderDetailsItemId]
LEFT JOIN [dbo].[Users] as u ON odi.MainCalibratorId = u.ID
LEFT JOIN [dbo].[OrderDetails] as od ON od.OrderDetailId = odi.OrderDetailId
LEFT JOIN [dbo].[CustomerSites] as cs ON od.CustomerSiteId = cs.CustomerSiteId
-- od is reached through odi here, so rows with no item would lose the part data;
-- join OrderDetails straight off the numbers CTE instead.
LEFT JOIN [dbo].[OrderDetails]   as odp ON odp.OrderDetailId = n.OrderDetailId
-- resolve by CATALOG NUMBER: OrderDetails.PART is wrong on 169 lines (it points at a different
-- Priority product), while PartName is authoritative and PART.PARTNAME is unique.
LEFT JOIN [dbo].[CrmPartInfo]    as cpi ON cpi.PartName = odp.PartName
LEFT JOIN [dbo].[CrmCatalogText] as cct ON cct.PART     = cpi.PART
LEFT JOIN [dbo].[CrmDeviceText]  as cdt ON cdt.SERN = odi.SERN
OUTER APPLY
(
SELECT 
	ShortNameEn as MeasurementDeviceUnitEn,
	ShortNameHe as MeasurementDeviceUnitHeb,
	ic.NominalValue,
	ic.Tolerance,
	ic.MinToleranceBorder,
	ic.MaxToleranceBorder
FROM [dbo].[CalibrationEnvironmentalConditions] as ic
JOIN [dbo].[MeasurementDeviceUnits] as mu ON ic.MeasurementDeviceUnitId = mu.MeasurementDeviceUnitId
WHERE ic.OrderDetailsItemId = r.[OrderDetailsItemId] and ic.IsDeleted = 0
FOR JSON PATH
) as ds(EnvironmentalConditions)
WHERE (@OrderDetailsItems IS NULL OR r.OrderDetailsItemId = @OrderDetailsItems)
ORDER BY [OrderDetailId]
option (maxrecursion 0)
GO

/* ================= dbo.GetSensorsConfiguredByCalibrator ================= */
-- =============================================
-- Proc:        dbo.GetSensorsConfiguredByCalibrator   (original author: Eduard Kudlaiev, 02/07/2025)
-- Jira:        MBA-476 "Connecting multiple sensors" / MBA-475 "Disconnect Detection"
--
-- 2026-08-13 change (STAGE only): the proc identified a sensor only by its internal
-- SensorMeasurementDeviceId and returned WorkRangeUnitId without the range itself, so the sensor
-- table could not show "ID, type, range" per connected sensor (MBA-476) and had no bounds to
-- compare a reading against (MBA-475). Added, all straight off the sensor's MeasurementDevices row:
--     MabaID, Model, SerialNumber, Manufacturer   - identity for the table
--     DeviceRange                                  - the range AS TEXT, which is how it is stored
--     WorkRangeMin, WorkRangeMax                   - the numeric bounds, when they exist
-- No rows/filters changed; this is additive.
--
-- 2026-08-24 (MBA-902): dual ranges, plus two ordering fixes - all three visible in the popup.
--     ChannelList came out of STRING_AGG in whatever order the join produced, so a sensor holding
--     channels 0,1,2,3,6,7 could render as "3,0,7,1,6,2". Now sorted numerically.
--     The result set itself had no ORDER BY, so the sensor list reshuffled between calls. Now
--     sorted by MabaID on its numeric segments, so 21-9 comes before 21-86.
--
-- On the work range: as of 2026-08-24, 85 of 152 sensors on STAGE have numeric WorkRangeMin/Max
-- (imported from kyulan.dbo.tblInstr by dbo.ImportInstrumentWorkRangeFromKyulan - it was 0 before).
-- The remaining 67 cannot be filled from kyulan: it holds no numeric range for any of them, and
-- only a lone minimum for 31-83. 37 of the 67 carry a free-text DeviceRange instead, and that text
-- is not machine-readable: '0-150', '-80c%1100c', '196-', '0-100%RH;-40-60C', '(-120)-100C',
-- '0-1300'. Some rows carry TWO ranges (temperature plus humidity), some are typos. Auto-parsing
-- would silently produce wrong limits on a feature whose whole job is to flag out-of-range
-- readings, so it is deliberately NOT done here. Those 37 need a human pass - a data task.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetSensorsConfiguredByCalibrator]
    @LoggedInUserEmail NVARCHAR(100),
    @LoggerMeasurementDeviceId INT = NULL,
    @SensorMeasurementDeviceId INT = NULL
AS
BEGIN

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT
DECLARE @SourceId TINYINT

SELECT
 @LoggedInUserId  = d.UserId
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

    SELECT srl.LoggerMeasurementDeviceId as  LoggerMeasurementDeviceId,
           ltc.IP AS CommunicationDetails,
           ltc.Connection as CommunicationProtocol,
           srl.SensorMeasurementDeviceId as SensorMeasurementDeviceId,
           ltc.UnitId,
           ltc.WorkRangeUnitId,
           -- MBA-476: identify each connected sensor in its own row
           ltc.MabaID,
           ltc.Model,
           ltc.SerialNumber,
           ltc.Manufacturer,
           -- MBA-475: the range. DeviceRange is the original text, kept so a calibrator can
           -- always see what the numbers were read from.
           ltc.DeviceRange,
           ltc.WorkRangeMin,
           ltc.WorkRangeMax,
           u1.ShortNameEn AS WorkRangeUnit,
           -- MBA-902: a sensor that measures two things at once carries both. Slot 1 is the
           -- temperature range where there is one; slot 2 is the humidity range.
           ltc.WorkRangeMin2,
           ltc.WorkRangeMax2,
           ltc.WorkRangeUnitId2,
           u2.ShortNameEn AS WorkRangeUnit2,
           -- The outer bounds across both ranges, for a caller with only one pair of fields to
           -- fill. Do NOT compare a reading against these when the two ranges are in different
           -- units - use the matching pair above.
           CASE WHEN ltc.WorkRangeMin2 IS NULL THEN ltc.WorkRangeMin
                ELSE IIF(ltc.WorkRangeMin2 < ltc.WorkRangeMin, ltc.WorkRangeMin2, ltc.WorkRangeMin)
           END AS WorkRangeMinOverall,
           CASE WHEN ltc.WorkRangeMax2 IS NULL THEN ltc.WorkRangeMax
                ELSE IIF(ltc.WorkRangeMax2 > ltc.WorkRangeMax, ltc.WorkRangeMax2, ltc.WorkRangeMax)
           END AS WorkRangeMaxOverall,
           IIF(ltc.WorkRangeMin2 IS NOT NULL, CAST(1 AS BIT), CAST(0 AS BIT)) AS HasSecondRange,
           -- MBA-902: numeric order, not join order
           STRING_AGG(csr.ChannelNumber,',') WITHIN GROUP (ORDER BY csr.ChannelNumber) as ChannelList
    FROM dbo.MeasurementDevices as ltc
    JOIN dbo.MeasurementDevicesMainClasses as mc ON ltc.MainClassId = mc.Id
    JOIN dbo.SensorToLoggerRelation as srl ON ltc.ID = srl.SensorMeasurementDeviceId AND srl.IsDeleted = 0
    JOIN dbo.ChannelsToSensorRelation as csr ON csr.SensorMeasurementDeviceId = srl.SensorMeasurementDeviceId AND csr.LoggerMeasurementDeviceId = srl.LoggerMeasurementDeviceId AND csr.IsDeleted = 0
    LEFT JOIN dbo.MeasurementDeviceUnits as u1 ON u1.MeasurementDeviceUnitId = ltc.WorkRangeUnitId
    LEFT JOIN dbo.MeasurementDeviceUnits as u2 ON u2.MeasurementDeviceUnitId = ltc.WorkRangeUnitId2
    WHERE  mc.NameEnglish = 'Sensor' AND ltc.IsDeleted =0
    AND (@SensorMeasurementDeviceId IS NULL OR srl.SensorMeasurementDeviceId = @SensorMeasurementDeviceId)
    AND (@LoggerMeasurementDeviceId IS NULL OR srl.LoggerMeasurementDeviceId = @LoggerMeasurementDeviceId)
    GROUP BY
    srl.LoggerMeasurementDeviceId,
    ltc.IP,
    ltc.Connection,
    srl.SensorMeasurementDeviceId,
    ltc.UnitId,
    ltc.WorkRangeUnitId,
    ltc.MabaID,
    ltc.Model,
    ltc.SerialNumber,
    ltc.Manufacturer,
    ltc.DeviceRange,
    ltc.WorkRangeMin,
    ltc.WorkRangeMax,
    u1.ShortNameEn,
    ltc.WorkRangeMin2,
    ltc.WorkRangeMax2,
    ltc.WorkRangeUnitId2,
    u2.ShortNameEn
    -- MBA-902: stable order, so the list does not reshuffle between calls
    ORDER BY
        TRY_CAST(LEFT(ltc.MabaID, CHARINDEX('-', ltc.MabaID + '-') - 1) AS INT),
        TRY_CAST(LEFT(STUFF(ltc.MabaID, 1, CHARINDEX('-', ltc.MabaID + '-'), ''),
                      CHARINDEX('/', STUFF(ltc.MabaID, 1, CHARINDEX('-', ltc.MabaID + '-'), '') + '/') - 1) AS INT),
        ltc.MabaID

END
GO

/* ================= dbo.GetUserNames ================= */
/*
    dbo.GetUserNames
    ---------------------------------------------------------------------------------------------
    The e-mail list behind the username dropdown on the sign-in screen.

    Why this changed
    ----------------
    It used to return every active address in the table. On PROD that is 2,136 rows, of which
    2,099 are CUSTOMERS - so the sign-in page of cal.qcc.co.il was publishing MABA's entire
    customer contact list to anyone who opened it, without logging in.

    Now it returns staff only: 37 rows.

    Why the filter is on the ROLE and not on the e-mail domain
    ----------------------------------------------------------
    "Only @mba.co.il" was the obvious rule and it is wrong - three active members of staff do not
    have an MABA address, and a domain filter would lock them out of the system:

        0523862631                  אלון אזולאי       Calibrator   (a phone number in the e-mail column)
        erel@larit.co.il            קבלן משנה-לרית    Calibrator   (subcontractor)
        lilach_ch@sepharma.co.il    לילך שאוט         OperationManager

    Excluding the Customer role keeps all three and still removes all 2,099 customers, which is
    what the request was actually about. It also stays correct when a new member of staff arrives
    on some other domain.

    Safe to deploy: not one of the 2,099 customers has ever signed in - LastLoginDate is NULL for
    every one of them. Customers authenticate through the separate e-mail one-time-code flow
    (MBA-892 / MBA-893), which does not use this list.

    Worth saying plainly
    --------------------
    A dropdown that lists valid usernames is an account-enumeration aid whatever it is filtered
    to. This change removes the customer leak; it does not make the pattern a good one. Replacing
    the dropdown with a plain text field is the real fix and belongs to the front end.
*/
CREATE OR ALTER PROCEDURE [dbo].[GetUserNames]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT u.Email
    FROM dbo.Users AS u
    LEFT JOIN dbo.UserRoles AS r ON r.UserRoleId = u.UserRoleId
    WHERE LEN(TRIM(u.Email)) > 0
      AND u.IsActive = 1
      AND u.ID > 0                                   -- excludes the ETL service account
      AND ISNULL(r.UserRoleName, N'') <> N'Customer' -- staff only; see header
    ORDER BY u.Email;
END
GO

/* ================= dbo.GetWorkPlanData ================= */
-- =============================================
-- Proc:        dbo.GetWorkPlanData
-- Jira:        MBA — "אישור תיאום כיול ע"י הלקוח" (order-approval by e-mail)
-- Description: Verbatim copy of the live dbo.GetWorkPlanData with ONE behavioural change:
--              the fallback ClientConfirmationStatus for orders whose
--              OrderWorkPlans.ClientConfirmationStatusId is NULL is now 'New' (חדש)
--              instead of 'Pending' (ממתין).
--
--              Why: 'Pending' now means "a coordination e-mail was sent and we are waiting
--              for the customer to answer" — it is the status that triggers the mail. Orders
--              that arrived from the Priority sync and were never sent to the customer must
--              not look pending; they are 'New'. (On STG that is ~990 of ~997 orders.)
--
--              Requires dbo.ClientConfirmationStatus.New.seed.sql to have run first, otherwise
--              @ClientConfirmationStatusDefault resolves to NULL.
--
-- Everything below this header is the live definition as of the change, only
-- CREATE OR ALTER PROCEDURE -> CREATE OR ALTER PROCEDURE and the one WHERE line differ.
-- =============================================
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 03/04/2025
-- Description:	Get work plan data
-- =============================================
CREATE   PROCEDURE [dbo].[GetWorkPlanData]
    @PageNumber AS INT = 1,                  -- Resulting page for pagination, starting in 1
    @RowsOfPage AS INT = 50,                 -- Result page size
    @OrderBy AS NVARCHAR(MAX) = 'OrderWorkPlanId',      -- OrderBy column
    @OrderByAsc AS BIT = 1,                  -- OrderBy direction (ASC/DESC)
    -- Filter parameters (all nullable)
	@ClientName NVARCHAR(255) = NULL,
	@Date DATE = NULL,
	@MainCategory NVARCHAR(100) = NULL,
	@SecondCategory NVARCHAR(100) = NULL,
	@Location NVARCHAR(100) = NULL,
	@ProductType NVARCHAR(100) = NULL,
	@ProducedIn NVARCHAR(255) = NULL,
	@DeviceModel NVARCHAR(100) = NULL,
	@DateFrom DATETIME2(0) = NULL,
	@DateTo DATETIME2(0) = NULL,
	@DeviceNumber NVARCHAR(20) = NULL,
	@DeviceManufacturer NVARCHAR(255) = NULL,
	@AssignedCalibratorsIds NVARCHAR(MAX) = NULL, -- -1 means that we should include orders with empty calibrator
	@EquipmentIds NVARCHAR(MAX) = NULL,
	@SpecialCareTypeIds NVARCHAR(255) = NULL,
	@OrderNumber NVARCHAR(MAX) = NULL,
	@GlobalSearch NVARCHAR(200) = NULL,
	@WorkPlanOpenDate DATETIME2(0) = NULL,
	@CarsIds NVARCHAR(MAX) = NULL,
	@Notes NVARCHAR(255) = NULL,
	@Page NVARCHAR(100),
	@LoggedInUserEmail NVARCHAR(50) = NULL,
	@ExcludeRejectedOrders BIT = 0,
	@ClientId INT = NULL,
	-- MBA-806/filter fix: the "קוד לקוח" field is Customers.CustomerCode (NVARCHAR, can be
	-- alphanumeric e.g. 'T005585') and is NOT Customers.CustomerId. Prefer this parameter.
	@ClientCode NVARCHAR(50) = NULL
AS

BEGIN
    SET NOCOUNT ON;
	SET ANSI_WARNINGS OFF;

	/* ---------------------------------------------------------------------------------
	   Customer filter resolution (MBA: "קוד לקוח" returned the wrong customer / no rows).
	   Customers has THREE different ids and their ranges overlap:
	     CustomerId           - local surrogate key, what OrderWorkPlans.CustomerId points at
	     CustomerIdFromSource - Priority CUST
	     CustomerCode         - the HP / קוד לקוח the user types on screen
	   Example: code 877 = 'אלכם מדיקל' (CustomerId 4428), while CustomerId 877 is a
	   different company ('פינקלמן') with no work plans - so filtering by the typed code
	   against CustomerId silently returned an empty screen.
	   @ClientCode is the correct input. @ClientId is kept for back-compat and is resolved
	   as a CODE first (that is what the UI sends today), falling back to a real CustomerId.
	   --------------------------------------------------------------------------------- */
	DECLARE @ResolvedCustomerId INT = NULL;

	IF @ClientCode IS NOT NULL
	BEGIN
		SELECT TOP (1) @ResolvedCustomerId = c.CustomerId
		FROM dbo.Customers AS c
		WHERE c.CustomerCode = @ClientCode AND ISNULL(c.IsDeleted, 0) = 0;

		IF @ResolvedCustomerId IS NULL SET @ResolvedCustomerId = -1;  -- unknown code -> no rows
	END
	ELSE IF @ClientId IS NOT NULL
	BEGIN
		SELECT TOP (1) @ResolvedCustomerId = c.CustomerId
		FROM dbo.Customers AS c
		WHERE c.CustomerCode = CAST(@ClientId AS NVARCHAR(20)) AND ISNULL(c.IsDeleted, 0) = 0;

		IF @ResolvedCustomerId IS NULL SET @ResolvedCustomerId = @ClientId;  -- treat as a real CustomerId
	END

	DECLARE @LoggedInUserId INT = 0
	DECLARE @SourceId TINYINT

	SELECT 
	 @LoggedInUserId  = d.UserId 
	,@SourceId = d.SourceId
	FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

	/*
	Filter logic by page
	/coordinator-orders - @page = ‘coordinator-orders’ 
	/external-schedule - @page = ‘external-schedule’
	/internal-orders - @page = ‘internal-orders’
	/calibration-wizard - @page = ‘calibration-wizard’ 
	/external-orders - @page = 'external-orders'
	*/
	/*-------------------------------------------------*/
	/* MBA-902 / MBA-293 AC1: "As soon as Calibrator finishes calibration and generates the report,
	   the Validator should see the calibration validation screen." The validator pages had no status
	   filter at all - internal-validator, external-validator and internal-orders returned an
	   identical 500 rows - so the screen listed orders that had not been calibrated yet, which is
	   why every CRM-sourced column on it came back empty.
	   MBA-293 AC1 is "finishes calibration AND GENERATES THE REPORT", and the report number is the
	   report - so a device belongs on the validator screen once it HAS one. That is the test used
	   below, and it is the only one that holds up in the data: CalibrationStatusId is set on 91 of
	   3,823 items, and 3,470 of the 3,471 items carrying a real report number have no calibration
	   status at all. Filtering on the status instead produced 49 orders of which 43 showed a blank
	   report number, which is the opposite of what the screen is for.
	   The status list is kept here for when the lifecycle is actually maintained. */
	DECLARE @ValidatorDeviceStatuses NVARCHAR(200) = N'29,32,33,34,35,36,37,38'
	/* The eight device statuses the design actually defines - Figma node 5429-395, the legend MBA-293
	   links. In screen order: 37 ממתין לכיול, 38 כיול, 36 ממתין לחתימה, 35 ממתין להערות,
	   34 לא ניתן לקבוע, 32 נבדק עומד, 33 נבדק - לא עומד, 29 מוכן לאריזה.

	   23 CalibrationSuccess (כיול הצליח) is NOT one of them and was wrongly listed here before. It is
	   also the status the system writes most: of the 90 items that carry any calibration status,
	   71 are 23, 16 are 33 and 3 are 32. Every other status in the category, including five of the
	   eight the design defines, has never been written once.

	   Note the near-duplicate pairs in dbo.Statuses: the design's ממתין לכיול and כיול are 37 and 38,
	   while 19 WaitingForCalibration and 20 InCalibration say the same thing and are what the
	   front-end constant maps to. Both pairs are unused, so nothing depends on the answer yet. */

	DECLARE @ExtIntFilter BIT = NULL

	/* MBA-902: external-validator and internal-validator were in neither list, so both pages
	   returned the same rows. The mechanism was already here and coordinator-orders uses it -
	   od.IsInHouse is the internal/external definition in this system. */
	IF @Page IN (N'external-schedule',N'external-orders',N'coordinator-orders',N'external-validator') SET @ExtIntFilter = 0 -- IsInHouse = 0 for external orders

	IF @Page IN (N'internal-orders',N'internal-validator') SET @ExtIntFilter = 1 -- IsInHouse = 1 for internal orders
	--validator-orders
	/*-------------------------------------------------*/

	--IF @OrderBy NOT IN 
	--(N'OrderNumber',N'SpecialCares',N'ClientName',N'Location',N'WorkPlanOpenDate',
	--N'Cars',N'Calibrators',N'EquipmentNames',N'Notes',N'MainCategory',N'CalibDate',N'ClientConfirmationStatus',N'ExpectedReturnDate',
	--N'ActualReturnDate',N'CustomerPackingExists',N'PrintedReport',N'ReceivingDate',N'WorkPlanStatus')
	--THROW 51000, 'Incorrect value for parameter @OrderBy. Available values |OrderNumber|SpecialCares|ClientName|
	--ExpectedReturnDate|ActualReturnDate
	--|Location|WorkPlanOpenDate|Cars|Calibrators|EquipmentNames|Notes|MainCategory|CalibDate|ClientConfirmationStatus', 1;

	/* MBA-902: the sparse CRM columns. Sorting one of them ascending put every empty row first, so
	   the screen opened on nothing but dashes even though values exist further down - 6 of 38 rows
	   carry a report number and 11 carry the return dates. Rows that HAVE a value now always come
	   first and the requested direction orders them, the same treatment Cars, Calibrators and
	   EquipmentNames already get below.
	   The expressions are repeated rather than referenced by alias: ORDER BY may use a select-list
	   alias on its own, but not wrapped inside IIF, and CalibratorMabaNumber is a correlated
	   subquery rather than a plain column. */
	DECLARE @SortExpr NVARCHAR(MAX) = NULL

	IF @OrderBy = N'CalibratorMabaNumber' SET @SortExpr = N'(SELECT MIN(i9.MbaReportNumber) FROM [dbo].[OrderDetailsItems] as i9 JOIN [dbo].[OrderDetails] as od9 ON od9.OrderDetailId = i9.OrderDetailId WHERE od9.OrderWorkPlanId = wp.[OrderWorkPlanId] AND ISNULL(od9.IsDeleted,0) = 0 AND ISNULL(i9.IsDeleted,0) = 0 AND i9.MbaReportNumber LIKE ''[0-9][0-9][0-9][0-9][0-9][0-9][0-9]/%'')'
	IF @OrderBy = N'ExpectedReturnDate'   SET @SortExpr = N'MAX(itm.ExpectedReturnDate)'
	IF @OrderBy = N'ActualReturnDate'     SET @SortExpr = N'MAX(itm.ActualReturnDate)'

	IF @SortExpr IS NOT NULL
	BEGIN
		SET @OrderBy = CONCAT(N'IIF(', @SortExpr, N' IS NULL,1,0) ASC, ', @SortExpr, N' ',
		                      CASE WHEN @OrderByAsc = 0 THEN N'DESC' ELSE N'ASC' END)
		SET @OrderByAsc = NULL
	END

	IF @OrderBy IN (N'Cars')
		BEGIN
		SET @OrderBy = CONCAT(N'IIF([Cars] IS NULL,0,1) ',CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END ,N' ,IIF([Calibrators] IS NULL,0,1)', N' ,IIF([EquipmentNames] IS NULL,0,1)')

		SET @OrderByAsc = NULL
		END

	IF @OrderBy IN (N'Calibrators')
		BEGIN
		SET @OrderBy = CONCAT(N' IIF([Cars] IS NULL,0,1) DESC',N' ,IIF([Calibrators] IS NULL,0,1) ',CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END , N' ,IIF([EquipmentNames] IS NULL,0,1)')

		SET @OrderByAsc = NULL
		END

	IF @OrderBy IN (N'EquipmentNames')
		BEGIN
		SET @OrderBy = CONCAT(N' IIF([Cars] IS NULL,0,1) DESC',N' ,IIF([Calibrators] IS NULL,0,1) DESC', N' ,IIF([EquipmentNames] IS NULL,0,1)',CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END )

		SET @OrderByAsc = NULL
		END	
    /*Apply filter by orders on external order page to get only orders assigned by calibrator for specific date*/
	DECLARE @FilterExternalOrdersForCalibrator BIT = 0
    IF @Page = N'external-orders' AND @DateFrom IS NOT NULL AND @DateTo IS NOT NULL
		BEGIN
			SET @FilterExternalOrdersForCalibrator = 1

			DROP TABLE IF EXISTS #FilterExternalOrdersForCalibrator
			CREATE TABLE #FilterExternalOrdersForCalibrator
			(
			[OrderWorkPlanId] INT
			)
			INSERT #FilterExternalOrdersForCalibrator([OrderWorkPlanId])
			SELECT DISTINCT cal.OrderWorkPlanId 
			FROM [dbo].[CalibratorsToWorkPlan] as cal
			JOIN [dbo].[CarsToOrder] as c ON cal.OrderWorkPlanId = c.OrderWorkPlanId AND cal.AssigmentDate = c.AssignDate AND c.IsDeleted = 0
			WHERE (cal.CalibratorId = @LoggedInUserId OR @SourceId IS NULL)
			AND cal.AssigmentDate >= @DateFrom AND cal.AssigmentDate <=@DateTo
		END

	DROP TABLE IF EXISTS #AssignedCalibrators
	CREATE TABLE #AssignedCalibrators
	(
	[OrderWorkPlanId] INT
	)
	INSERT #AssignedCalibrators([OrderWorkPlanId])
	SELECT DISTINCT wp.OrderWorkPlanId FROM dbo.ParseCSVToTable(@AssignedCalibratorsIds) as f
	JOIN [dbo].[CalibratorsToWorkPlan] as wp ON wp.CalibratorId = f.Value and wp.IsDeleted = 0

	IF EXISTS (SELECT 1 FROM dbo.ParseCSVToTable(@AssignedCalibratorsIds) WHERE [Value] = -1)
	INSERT #AssignedCalibrators([OrderWorkPlanId])
	SELECT DISTINCT wp.[OrderWorkPlanId]
	FROM [dbo].[OrderWorkPlans] as wp
	LEFT JOIN [dbo].[CalibratorsToWorkPlan] as cwp ON wp.OrderWorkPlanId = cwp.OrderWorkPlanId and cwp.IsDeleted = 0
	WHERE wp.IsCancelled = 0 AND cwp.OrderWorkPlanId IS NULL

	DROP TABLE IF EXISTS #EquipmentId
	CREATE TABLE #EquipmentId
	(
	[OrderWorkPlanId] INT
	)
	INSERT #EquipmentId([OrderWorkPlanId])
	SELECT DISTINCT ce.OrderWorkPlanId FROM dbo.ParseCSVToTable(@EquipmentIds) as f
	JOIN [dbo].[MeasurementDevicesToOrderHeaders] as ce ON ce.MeasurementDeviceId = f.Value and ce.IsDeleted = 0
	
	DROP TABLE IF EXISTS #CarsIds
	CREATE TABLE #CarsIds
	(
	[OrderWorkPlanId] INT
	)
	INSERT #CarsIds([OrderWorkPlanId])	
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@CarsIds,',') as sp
    JOIN [dbo].[CarsToOrder] as c ON sp.value = c.CarId
	JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderWorkPlanId = c.OrderWorkPlanId
	WHERE wp.IsCancelled = 0 AND c.IsDeleted = 0 

	DROP TABLE IF EXISTS #SpecialCareTypes
	CREATE TABLE #SpecialCareTypes
	(
	[SpecialCareTypeId] INT
	)
	INSERT #SpecialCareTypes([SpecialCareTypeId])
	SELECT DISTINCT f.Value FROM dbo.ParseCSVToTable(@SpecialCareTypeIds) as f

	IF @MainCategory IS NOT NULL
	BEGIN
	DROP TABLE IF EXISTS #MainCategory
	CREATE TABLE #MainCategory
	(
	[ID] INT
	)
	INSERT #MainCategory([ID])
	SELECT ID FROM [dbo].[MainCategories] as mc WHERE mc.MainCategoryName LIKE CONCAT('%',@MainCategory,'%')
	END

	IF @SecondCategory IS NOT NULL
	BEGIN
	DROP TABLE IF EXISTS #SecondCategory
	CREATE TABLE #SecondCategory
	(
	[ID] INT
	)
	INSERT #SecondCategory([ID])
	SELECT ID FROM [dbo].[SecondaryCategories] as sc WHERE sc.SecondaryCategoryName LIKE CONCAT('%',@SecondCategory,'%')
	END

	DECLARE @ClientConfirmationStatusDefault NVARCHAR(50)
	SELECT
	    @ClientConfirmationStatusDefault = s.StatusDescriptionENG
	FROM [dbo].[StatusesCategories] as c
	JOIN [dbo].[Statuses] as s ON c.StatusCategoryId = s.StatusCategoryId
	WHERE c.StatusDescriptionENG = N'ClientConfirmationStatus' AND s.StatusDescriptionENG = N'New'

	DECLARE @StatusesForOrders NVARCHAR(MAX)

	/* MBA-902: this excluded 'Executed', a status that does not exist in dbo.Statuses - so it
	   excluded nothing and finished orders stayed on every working screen. The status it meant is
	   75 Finished (הסתיים); 'Executed' was presumably its earlier name and the rename never
	   reached here.
	   A finished order now leaves the working screens and appears on the calibration history page,
	   which asks for exactly the statuses the others drop. */
	DECLARE @FinishedOrderStatus NVARCHAR(50) = N'Finished'

	SELECT @StatusesForOrders=STRING_AGG(s.StatusId,',')
	FROM [dbo].[Statuses] as s
	JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
	WHERE sc.StatusDescriptionENG='OrderStatus'
	  AND (  (@Page =  N'calibration-history' AND s.StatusDescriptionENG =  @FinishedOrderStatus)
	      OR (@Page <> N'calibration-history' AND s.StatusDescriptionENG <> @FinishedOrderStatus)
	      OR @Page IS NULL)

	DROP TABLE IF EXISTS #OrderNumbers
	CREATE TABLE #OrderNumbers
	(
	[OrderWorkPlanId] INT
	)
	INSERT #OrderNumbers([OrderWorkPlanId])	
	SELECT DISTINCT wp.[OrderWorkPlanId] 
	FROM STRING_SPLIT(@OrderNumber,',') as sp
	JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderNumber = sp.value
	WHERE wp.IsCancelled = 0 

	IF @ExcludeRejectedOrders = 1
	BEGIN
		DECLARE @ClientConfirmationStatus NVARCHAR(MAX)

		SELECT @ClientConfirmationStatus=STRING_AGG(s.StatusId,',')
		FROM [dbo].[Statuses] as s
		JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
		WHERE sc.StatusDescriptionENG='ClientConfirmationStatus' AND s.StatusDescriptionENG = 'Rejected'
	END

	-------------------------------------------------------------------------
	-- Pre-calculate metrics that use STRING_AGG into temp tables
	-------------------------------------------------------------------------

	-- 1. Main Category Names
	DROP TABLE IF EXISTS #MainCatNames;
	CREATE TABLE #MainCatNames (
		OrderWorkPlanId INT,
		MainCategoryName NVARCHAR(400) COLLATE Latin1_General_100_CI_AI_SC
	);
	INSERT INTO #MainCatNames (OrderWorkPlanId, MainCategoryName)
	SELECT maincat.OrderWorkPlanId, STRING_AGG(maincat.MainCategoryName,',') as MainCategoryName
	FROM (
		SELECT DISTINCT wp.OrderWorkPlanId, mcf.MainCategoryName 
		FROM [dbo].[OrderWorkPlans] as wp  
		JOIN [dbo].[OrderDetails] as od ON wp.OrderWorkPlanId = od.OrderWorkPlanId
		JOIN [dbo].[MainCategories] as mcf ON od.MainCategoryId = mcf.ID
	) as maincat
	GROUP BY maincat.OrderWorkPlanId;

	CREATE UNIQUE CLUSTERED INDEX UC_IDX_MainCatNames ON #MainCatNames(OrderWorkPlanId)

	-- 2. Cars and Placement Dates
	DROP TABLE IF EXISTS #CarsAndPlacement;
	CREATE TABLE #CarsAndPlacement (
		OrderWorkPlanId INT,
		Cars NVARCHAR(400) COLLATE Latin1_General_100_CI_AI_SC,
		PlacementDate NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC
	);
	IF @DateFrom IS NOT NULL AND @DateTo IS NOT NULL AND @Page <> N'external-orders'
	BEGIN
		INSERT INTO #CarsAndPlacement (OrderWorkPlanId, Cars, PlacementDate)
		SELECT co.OrderWorkPlanId, STRING_AGG(CAST(co.CarId as NVARCHAR(MAX)),','), STRING_AGG(CAST(co.AssignDate as NVARCHAR(MAX)),',')
		FROM [dbo].[CarsToOrder] as co 
		WHERE co.IsDeleted = 0 AND co.[AssignDate] >= @DateFrom AND co.[AssignDate] <= @DateTo
		GROUP BY co.OrderWorkPlanId;
	END
	ELSE
	BEGIN
		INSERT INTO #CarsAndPlacement (OrderWorkPlanId, Cars, PlacementDate)
		SELECT co.OrderWorkPlanId, STRING_AGG(CAST(co.CarId as NVARCHAR(MAX)),','), STRING_AGG(CAST(co.AssignDate as NVARCHAR(MAX)),',')
		FROM [dbo].[CarsToOrder] as co 
		WHERE co.IsDeleted = 0
		GROUP BY co.OrderWorkPlanId;
	END
	CREATE UNIQUE CLUSTERED INDEX UC_IDX_CarsAndPlacement ON #CarsAndPlacement(OrderWorkPlanId)

	-- 3. Calibrators
	DROP TABLE IF EXISTS #WorkPlanCalibrators;
	CREATE TABLE #WorkPlanCalibrators (
		OrderWorkPlanId INT,
		Calibrators NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC
	);
	INSERT INTO #WorkPlanCalibrators (OrderWorkPlanId, Calibrators)
	SELECT cwp.OrderWorkPlanId, STRING_AGG(CONCAT(u.FirstName,' ',u.LastName),',') as Calibrators
	FROM [dbo].[CalibratorsToWorkPlan] as cwp
	JOIN [dbo].[Users] as u ON cwp.CalibratorId = u.ID
	WHERE cwp.IsDeleted = 0
	GROUP BY cwp.OrderWorkPlanId;
	
	CREATE UNIQUE CLUSTERED INDEX UC_IDX_WorkPlanCalibrators ON #WorkPlanCalibrators(OrderWorkPlanId)


	-- 4. Statuses (SpecialCareTypeId Statuses)
	DROP TABLE IF EXISTS #WorkPlanStatuses;
	CREATE TABLE #WorkPlanStatuses (
		OrderWorkPlanId INT,
		StatusDescriptionENG NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC,
		StatusDescriptionHEB NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC
	);
	INSERT INTO #WorkPlanStatuses (OrderWorkPlanId, StatusDescriptionENG, StatusDescriptionHEB)
	SELECT OrderWorkPlanId, STRING_AGG(StatusDescriptionENG,',') AS StatusDescriptionENG, STRING_AGG(StatusDescriptionHEB,',') AS StatusDescriptionHEB
	FROM (
		SELECT DISTINCT od.OrderWorkPlanId, s.StatusDescriptionENG, s.StatusDescriptionHEB
		FROM [dbo].[OrderDetails] as od
		JOIN [dbo].[Statuses] as s ON od.SpecialCareTypeId = s.StatusId
	) ds 
	GROUP BY OrderWorkPlanId;

	CREATE UNIQUE CLUSTERED INDEX UC_IDX_WorkPlanStatuses ON #WorkPlanStatuses(OrderWorkPlanId)

	-- 5. Equipment
	DROP TABLE IF EXISTS #WorkPlanEquipment;
	CREATE TABLE #WorkPlanEquipment (
		OrderWorkPlanId INT,
		EquipmentIds NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC,
		EquipmentNames NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC
	);
	INSERT INTO #WorkPlanEquipment (OrderWorkPlanId, EquipmentIds, EquipmentNames)
	SELECT coh.OrderWorkPlanId, STRING_AGG(CAST(coh.MeasurementDeviceId AS NVARCHAR(MAX)),', ') as EquipmentIds, STRING_AGG(ce.Description,', ') as EquipmentNames
	FROM [dbo].[MeasurementDevicesToOrderHeaders] as coh
	JOIN [dbo].[MeasurementDevices] as ce ON coh.MeasurementDeviceId = ce.ID AND ce.IsDeleted = 0
	WHERE coh.IsDeleted = 0 
	GROUP BY coh.OrderWorkPlanId;

	CREATE UNIQUE CLUSTERED INDEX UC_IDX_WorkPlanEquipment ON #WorkPlanEquipment(OrderWorkPlanId)

	-- 6. Special Cares
	DROP TABLE IF EXISTS #WorkPlanSpecialCares;
	CREATE TABLE #WorkPlanSpecialCares (
		OrderWorkPlanId INT,
		SpecialCares NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC
	);
	INSERT INTO #WorkPlanSpecialCares (OrderWorkPlanId, SpecialCares)
	SELECT OrderWorkPlanId, STRING_AGG(CAST(SpecialCareTypeId AS NVARCHAR(MAX)),',') as SpecialCares
	FROM [dbo].[OrderDetails]
	GROUP BY OrderWorkPlanId;

	CREATE UNIQUE CLUSTERED INDEX UC_IDX_WorkPlanSpecialCares ON #WorkPlanSpecialCares(OrderWorkPlanId)

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'SELECT 
  --      MAX(CASE ''',@Page,'''
		--	WHEN ''internal-validator'' THEN itm.MbaReportNumber
		--	WHEN ''external-validator'' THEN itm.MbaReportNumber
		--	WHEN ''validator-orders'' THEN itm.MbaReportNumber	
		--	ELSE wp.[OrderNumber] 
		--END) AS [OrderNumber],
		wp.[OrderNumber],
        MAX(co.[PlacementDate]) AS [CalibDate], -- possible bug. Not clear which date should be used
		wp.[CustomerId] as [CustomerId], 
		wp.[OrderWorkPlanId],
        spc.[SpecialCares],
        c.[CustomerName] as [ClientName],
        IIF(css.CustomerSiteId IS NOT NULL,CONCAT_WS('', '',css.CustomerSiteAddress,css.CustomerSiteState,css.CustomerSiteZIP), CONCAT_WS('', '',c.CustomerAddress, c.CustomerCity)) as [Location],
        wp.[WorkPlanOpenDate] as [WorkPlanOpenDate],
		sp.StatusDescriptionENG AS SpecialCareENG,
		sp.StatusDescriptionHEB AS SpecialCareHEB, 
        co.[Cars],
        coh.EquipmentIds,
		coh.EquipmentNames,
		cwp.Calibrators,
        wp.Notes as Notes,
		MIN(mcat.[MainCategoryName]) as MainCategory,
		wp.[IsCancelled],
		MAX(CAST(od.CustomerPackingExists as TINYINT)) as CustomerPackingExists,
		MAX(itm.ExpectedReturnDate) as ExpectedReturnDate,
		MAX(itm.ActualReturnDate) as ActualReturnDate,
		(SELECT MIN(i9.MbaReportNumber) FROM [dbo].[OrderDetailsItems] as i9 JOIN [dbo].[OrderDetails] as od9 ON od9.OrderDetailId = i9.OrderDetailId WHERE od9.OrderWorkPlanId = wp.[OrderWorkPlanId] AND ISNULL(od9.IsDeleted,0) = 0 AND ISNULL(i9.IsDeleted,0) = 0 AND i9.MbaReportNumber LIKE ''[0-9][0-9][0-9][0-9][0-9][0-9][0-9]/%'') as CalibratorMabaNumber, 
		/* MBA-902: the delivery note. Priority calls it ShippingDoc and it is what the packing
		   screen means by its order-number column - the values are D26009347, D26009342 and the
		   like. 2,353 of the 3,838 items carry one and every single one starts with D. An order can
		   be shipped on more than one note, so they are listed rather than reduced to the first.
		   STRING_AGG over a DISTINCT subquery rather than FOR XML: the XML data type methods need
		   particular SET options and fail on a connection that does not have them. */
		(SELECT STRING_AGG(sd.ShippingDoc, N'', '')
		   FROM (SELECT DISTINCT i8.ShippingDoc
		           FROM [dbo].[OrderDetailsItems] as i8
		           JOIN [dbo].[OrderDetails] as od8 ON od8.OrderDetailId = i8.OrderDetailId
		          WHERE od8.OrderWorkPlanId = wp.[OrderWorkPlanId]
		            AND ISNULL(od8.IsDeleted,0) = 0 AND ISNULL(i8.IsDeleted,0) = 0
		            AND NULLIF(LTRIM(RTRIM(i8.ShippingDoc)), '''') IS NOT NULL) as sd) as ShippingDoc, 
		/* MBA-907: the notes a coordinator or validator wrote on this order. The column shows the
		   latest and the count; the popup calls dbo.GetOrderNotes for the thread. */
		(SELECT TOP 1 n.NoteText FROM dbo.OrderNote AS n
		  WHERE n.OrderWorkPlanId = wp.[OrderWorkPlanId] AND n.IsDeleted = 0
		  ORDER BY n.CreatedDate DESC, n.OrderNoteId DESC) as LatestOrderNote,
		(SELECT COUNT(*) FROM dbo.OrderNote AS n
		  WHERE n.OrderWorkPlanId = wp.[OrderWorkPlanId] AND n.IsDeleted = 0) as OrderNotesCount, /* MBA-902: a correlated subquery, not an aggregate over itm. The report number belongs to the ORDER, and aggregating over itm would only see the items the validator status filter let through - on STAGE that is 1 order out of 49 instead of 6, because 3,470 of the 3,471 items carrying a real report number have no calibration status at all. */  
	    COALESCE(MAX(clst.StatusDescriptionENG),''',@ClientConfirmationStatusDefault,''') as ClientConfirmationStatus,
		MAX(wp.ShipTypeDesc) AS ShipTypeDesc,
		MAX(c.ReportRequired) AS PrintedReport,
		MAX(wp.CreatedDate) AS ReceivingDate,
		MAX(wpstat.StatusDescriptionENG) AS WorkPlanStatus,
		MAX(wp.CustomerComment) as CustomerComment,
		-- MBA-792: הנחיות לביצוע — Priority ORDERSTEXT, NEGATIVE-ORD side, served from the local cache.
		-- The positive-ORD side is the printed order document (mostly boilerplate) and is NOT this.
		(SELECT ci.InstructionsText   -- plain text; raw HTML is available via GetOrderInstructionsByOrder
		   FROM dbo.CrmOrderInstructions ci WHERE ci.ORD = wp.OrderSourceId) as OrderInstructions,
		MAX(co.[PlacementDate]) AS [PlacementDate],
		MIN(boxcnt.BoxesCount) as BoxesCount,
		COUNT(1) OVER(PARTITION BY 1 ORDER BY wp.[OrderNumber] ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as ItemsCount
    FROM [dbo].[OrderWorkPlans] as wp'
	,IIF(@FilterExternalOrdersForCalibrator = 1,' JOIN #FilterExternalOrdersForCalibrator as filo ON wp.OrderWorkPlanId = filo.OrderWorkPlanId ',' ')
	,IIF(@AssignedCalibratorsIds IS NOT NULL,' JOIN #AssignedCalibrators as ac ON wp.OrderWorkPlanId = ac.OrderWorkPlanId ',' ')
	,IIF(@EquipmentIds IS NOT NULL,' JOIN #EquipmentId as eid ON wp.OrderWorkPlanId = eid.OrderWorkPlanId ',' ')
	,IIF(@CarsIds IS NOT NULL,' JOIN #CarsIds as cid ON wp.OrderWorkPlanId = cid.OrderWorkPlanId ',' ')
	,IIF(@OrderNumber IS NOT NULL,' JOIN #OrderNumbers as ordnf ON wp.OrderWorkPlanId = ordnf.OrderWorkPlanId ',' ')
	,'JOIN [dbo].[OrderDetails] as od ON wp.OrderWorkPlanId = od.OrderWorkPlanId
	  LEFT JOIN [dbo].[OrderDetailsItems] as itm ON itm.OrderDetailId = od.OrderDetailId
	  LEFT JOIN [dbo].[Customers] as c ON wp.[CustomerId] = c.[CustomerId]
	  LEFT JOIN [dbo].[Statuses] as wpstat ON wp.[OrderOverallStatusId] = wpstat.[StatusId]
	  LEFT JOIN [dbo].[Statuses] as clst ON wp.[ClientConfirmationStatusId] = clst.[StatusId]
	  LEFT JOIN [dbo].[MainCategories] as mcf ON od.MainCategoryId	= mcf.ID
	  LEFT JOIN [dbo].[CalibratorsToWorkPlan] as ctwp ON ctwp.[OrderWorkPlanId] = wp.[OrderWorkPlanId] AND ctwp.[CalibratorId] = ',@LoggedInUserId,' AND ctwp.IsDeleted = 0
	  LEFT JOIN [dbo].[CalibratorsToWorkPlan] as ctwpdef ON ctwpdef.[OrderWorkPlanId] = wp.[OrderWorkPlanId] AND ctwpdef.IsDeleted = 0
	  LEFT JOIN [dbo].[SecondaryCategories] as scf ON od.SecondaryCategoryId = scf.ID
	  LEFT JOIN [dbo].[CustomerSites] as css ON css.CustomerSiteId = od.CustomerSiteId
	',IIF(@SpecialCareTypeIds IS NOT NULL,' JOIN #SpecialCareTypes as sct ON od.SpecialCareTypeId = sct.SpecialCareTypeId ',' ')
	 ,IIF(@MainCategory IS NOT NULL,' JOIN #MainCategory as mainc ON od.MainCategoryId = mainc.ID ',' ')
	 ,IIF(@SecondCategory IS NOT NULL,' JOIN #SecondCategory as secc ON od.SecondaryCategoryId = secc.ID ',' ')
	,'LEFT JOIN #MainCatNames as mcat ON wp.OrderWorkPlanId = mcat.OrderWorkPlanId
	'
	,CASE WHEN @DateFrom IS NOT NULL AND @DateTo IS NOT NULL AND @Page <> N'external-orders' THEN '' ELSE 'LEFT' END
	,'
	JOIN #CarsAndPlacement as co ON wp.OrderWorkPlanId = co.OrderWorkPlanId
	LEFT JOIN #WorkPlanCalibrators as cwp ON wp.OrderWorkPlanId = cwp.OrderWorkPlanId
	LEFT JOIN #WorkPlanStatuses as sp ON wp.OrderWorkPlanId = sp.OrderWorkPlanId
	LEFT JOIN #WorkPlanEquipment as coh ON wp.OrderWorkPlanId = coh.OrderWorkPlanId
	LEFT JOIN #WorkPlanSpecialCares as spc ON wp.OrderWorkPlanId = spc.OrderWorkPlanId	
	OUTER APPLY
	(
	SELECT COUNT(DISTINCT pb.PackingBoxId) as BoxesCount
	FROM [dbo].[PackingBox] as pb
	LEFT JOIN [dbo].[PackingBoxToOrderDetailsItems] as itm ON pb.PackingBoxId = itm.PackingBoxId
	LEFT JOIN [dbo].[OrderDetailsItems] as oi ON itm.OrderDetailsItemId = oi.OrderDetailsItemId
	LEFT JOIN [dbo].[OrderDetails] as od ON oi.OrderDetailId = od.OrderDetailId
	WHERE od.OrderWorkPlanId = wp.OrderWorkPlanId AND pb.IsDeleted = 0 AND itm.IsDeleted = 0 
	GROUP BY od.OrderWorkPlanId
	) as boxcnt 
	WHERE wp.OrderOverallStatusId IN(',@StatusesForOrders,') '
	,CASE WHEN @LoggedInUserEmail IS NOT NULL AND @SourceId IS NOT NULL THEN ' AND wp.SourceId = '+CAST(@SourceId AS NVARCHAR(50))  ELSE ' ' END
	,CASE WHEN @ExcludeRejectedOrders = 1 THEN ' AND COALESCE(wp.ClientConfirmationStatusId,0) NOT IN ('+@ClientConfirmationStatus+') 'ELSE ' ' END
	,CASE WHEN @ClientName IS NOT NULL THEN ' AND c.CustomerName LIKE N''%'+ @ClientName +'%'' 'ELSE ' ' END
	,CASE WHEN @ResolvedCustomerId IS NOT NULL THEN ' AND wp.CustomerId = '+ CAST(@ResolvedCustomerId AS NVARCHAR(20)) +' 'ELSE ' ' END
--	,CASE WHEN @Date IS NOT NULL AND  @Date > '1900-01-01' THEN ' AND wp.AssigmentDate = '''+CAST(@Date as NVARCHAR(MAX)) +''' 'ELSE ' ' END
	,CASE WHEN @Location  IS NOT NULL THEN ' AND IIF(css.CustomerSiteId IS NOT NULL,CONCAT_WS('', '',css.CustomerSiteAddress,css.CustomerSiteState,css.CustomerSiteZIP), CONCAT_WS('', '',c.CustomerAddress, c.CustomerCity)) LIKE N''%'+@Location +'%'' 'ELSE ' ' END
	,CASE WHEN @ProductType IS NOT NULL THEN ' AND od.PartName LIKE N''%'+ @ProductType +'%'' 'ELSE ' ' END
	,CASE WHEN @ProducedIn IS NOT NULL THEN ' AND itm.OrdersDeviceManufacturer LIKE N''%'+ @ProducedIn +'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceModel IS NOT NULL THEN ' AND itm.DeviceModel LIKE N''%'+ @DeviceModel +'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceNumber IS NOT NULL THEN ' AND itm.SerialNumber LIKE N''%'+ @DeviceNumber +'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceManufacturer IS NOT NULL THEN ' AND dm.OrdersDeviceManufacturerDescription LIKE N''%'+ @DeviceManufacturer +'%'''ELSE ' ' END
    ,CASE WHEN @GlobalSearch IS NOT NULL THEN ' AND CONCAT(cwp.[Calibrators],mcf.[MainCategoryName],c.[CustomerCity],c.[CustomerName],scf.[SecondaryCategoryName],sp.[StatusDescriptionENG],wp.[OrderNumber],c.[CustomerCode],wp.[CustomerId]) LIKE N''%'+ @GlobalSearch +'%'''ELSE ' ' END
	,CASE WHEN @WorkPlanOpenDate IS NOT NULL THEN ' AND wp.WorkPlanOpenDate = '''+CAST(@WorkPlanOpenDate as NVARCHAR(MAX)) +''' 'ELSE ' ' END
	,CASE WHEN @Notes IS NOT NULL THEN ' AND wp.Notes LIKE N''%'+ @Notes +'%'''ELSE ' ' END
	,CASE WHEN @ExtIntFilter IS NOT NULL THEN ' AND od.IsInHouse='+CAST(@ExtIntFilter as NVARCHAR(MAX))+' 'ELSE ' ' END
	/* MBA-902: a device reaches the validator once its report exists. */
	,CASE WHEN @Page IN (N'internal-validator',N'external-validator',N'validator-orders')
	      THEN ' AND itm.MbaReportNumber LIKE ''[0-9][0-9][0-9][0-9][0-9][0-9][0-9]/%'' ' ELSE ' ' END
	,'GROUP BY 
	wp.[CustomerId],
 --   CASE ''',@Page,'''
	--	WHEN ''internal-validator'' THEN itm.MbaReportNumber
	--	WHEN ''external-validator'' THEN itm.MbaReportNumber
	--	WHEN ''validator-orders'' THEN itm.MbaReportNumber
	--ELSE wp.[OrderNumber] 
	--END, 
	wp.[OrderNumber],
	wp.[OrderWorkPlanId],
	spc.[SpecialCares],
	c.[CustomerName], 
	IIF(css.CustomerSiteId IS NOT NULL,CONCAT_WS('', '',css.CustomerSiteAddress,css.CustomerSiteState,css.CustomerSiteZIP), CONCAT_WS('', '',c.CustomerAddress, c.CustomerCity)),
	wp.[WorkPlanOpenDate],
	co.[Cars],
    coh.EquipmentIds,
	coh.EquipmentNames,
	cwp.Calibrators,
	wp.Notes,
	sp.StatusDescriptionENG,
	sp.StatusDescriptionHEB, 
	wp.[IsCancelled],
	wp.OrderSourceId '
  ,  'ORDER BY ' , @OrderBy , CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END , ' OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')
PRINT LEN(@sql)
PRINT CAST(@sql as VARCHAR(MAX))
EXEC (@sql)

END
GO

/* ================= dbo.RefreshCrmTextCache ================= */
CREATE OR ALTER PROCEDURE [dbo].[RefreshCrmTextCache]
    @IncrementalOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('dbo.CrmCatalogText') IS NULL
        CREATE TABLE dbo.CrmCatalogText(PART INT PRIMARY KEY, CatalogText NVARCHAR(MAX) NULL, RefreshedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
    IF OBJECT_ID('dbo.CrmDeviceText') IS NULL
        CREATE TABLE dbo.CrmDeviceText(SERN INT PRIMARY KEY, DeviceText NVARCHAR(MAX) NULL, RefreshedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
    IF OBJECT_ID('dbo.CrmOrderInstructions') IS NULL
        CREATE TABLE dbo.CrmOrderInstructions(
             ORD                INT PRIMARY KEY      -- = OrderWorkPlans.OrderSourceId (positive)
            ,OrderInstructionsZ VARBINARY(MAX) NULL  -- COMPRESS(HTML). 18.2:1 on real data.
            ,InstructionsText   NVARCHAR(MAX)  NULL  -- tags stripped, for table cells
            ,RefreshedAt        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
    IF OBJECT_ID('dbo.CrmPartInfo') IS NULL
        CREATE TABLE dbo.CrmPartInfo(
             PartName          NVARCHAR(30) NOT NULL PRIMARY KEY  -- = OrderDetails.PartName = PART.PARTNAME
            ,PART              INT           NULL                 -- the real Priority key
            ,PartDescription   NVARCHAR(200) NULL                 -- PART.PARTDES (תיאור מכשיר)
            ,FamilyId          INT           NULL                 -- PART.FAMILY
            ,FamilyDescription NVARCHAR(200) NULL                 -- FAMILY.FAMILYDES
            ,RefreshedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());

    -- ── what the cache is expected to hold; in incremental mode only what it is missing ──────
    -- COLLATE DATABASE_DEFAULT is required: a temp table inherits tempdb's collation
-- (Latin1_General_100_CI_AI_SC here) while the user database is Hebrew_CI_AS, so every
-- comparison against a local column fails with a collation conflict.
    CREATE TABLE #WantedName(PartName NVARCHAR(30) COLLATE DATABASE_DEFAULT PRIMARY KEY);
    INSERT INTO #WantedName(PartName)
    SELECT DISTINCT LTRIM(RTRIM(od.PartName)) FROM dbo.OrderDetails AS od
    WHERE od.PartName IS NOT NULL AND LTRIM(RTRIM(od.PartName)) <> N''
      AND (@IncrementalOnly = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CrmPartInfo c WHERE c.PartName = LTRIM(RTRIM(od.PartName))));

    CREATE TABLE #WantedSern(SERN INT PRIMARY KEY);
    INSERT INTO #WantedSern(SERN)
    SELECT DISTINCT itm.SERN FROM dbo.OrderDetailsItems AS itm
    WHERE itm.SERN IS NOT NULL
      AND (@IncrementalOnly = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CrmDeviceText c WHERE c.SERN = itm.SERN));

    CREATE TABLE #WantedOrd(ORD INT PRIMARY KEY);
    INSERT INTO #WantedOrd(ORD)
    SELECT DISTINCT wp.OrderSourceId FROM dbo.OrderWorkPlans AS wp
    WHERE wp.OrderSourceId IS NOT NULL
      AND (@IncrementalOnly = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CrmOrderInstructions c WHERE c.ORD = wp.OrderSourceId));

    IF @IncrementalOnly = 0
    BEGIN
        TRUNCATE TABLE dbo.CrmCatalogText;
        TRUNCATE TABLE dbo.CrmDeviceText;
        TRUNCATE TABLE dbo.CrmPartInfo;
        TRUNCATE TABLE dbo.CrmOrderInstructions;
    END

    -- ── part description + family, resolved by CATALOG NUMBER ────────────────────────────────
    IF EXISTS (SELECT 1 FROM #WantedName)
        INSERT INTO dbo.CrmPartInfo(PartName, PART, PartDescription, FamilyId, FamilyDescription)
        SELECT w.PartName,
               p.PART,
               LTRIM(RTRIM(CONVERT(NVARCHAR(200), p.PARTDES))),
               p.FAMILY,
               LTRIM(RTRIM(CONVERT(NVARCHAR(200), f.FAMILYDES)))
        FROM #WantedName AS w
        -- both sides collated explicitly: the remote PARTNAME comes back as
        -- Latin1_General_100_CI_AI_SC and the local column is Hebrew_CI_AS, which cannot be
        -- compared without this.
        JOIN [31.168.173.93].amaba.dbo.PART AS p
             ON LTRIM(RTRIM(p.PARTNAME)) COLLATE Hebrew_BIN = w.PartName COLLATE Hebrew_BIN
        LEFT JOIN [31.168.173.93].amaba.dbo.FAMILY AS f ON f.FAMILY = p.FAMILY;

    -- ── catalog text, for the PARTs we just resolved ─────────────────────────────────────────
    CREATE TABLE #WantedPart(PART INT PRIMARY KEY);
    INSERT INTO #WantedPart(PART)
    SELECT DISTINCT c.PART FROM dbo.CrmPartInfo c
    WHERE c.PART IS NOT NULL
      AND (@IncrementalOnly = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CrmCatalogText t WHERE t.PART = c.PART));

    IF EXISTS (SELECT 1 FROM #WantedPart)
        INSERT INTO dbo.CrmCatalogText(PART, CatalogText)
        SELECT pt.PART,
               STRING_AGG(REVERSE(CONVERT(NVARCHAR(MAX), pt.[TEXT])), N' ') WITHIN GROUP (ORDER BY pt.TEXTLINE, pt.TEXTORD)
        FROM [31.168.173.93].amaba.dbo.PARTTEXT AS pt
        WHERE pt.PART IN (SELECT PART FROM #WantedPart)
        GROUP BY pt.PART;

    IF EXISTS (SELECT 1 FROM #WantedSern)
        INSERT INTO dbo.CrmDeviceText(SERN, DeviceText)
        SELECT st.SERN,
               STRING_AGG(REVERSE(CONVERT(NVARCHAR(MAX), st.[TEXT])), N' ') WITHIN GROUP (ORDER BY st.TEXTLINE, st.TEXTORD)
        FROM [31.168.173.93].amaba.dbo.SERNUMBERSTEXT AS st
        WHERE st.SERN IN (SELECT SERN FROM #WantedSern)
        GROUP BY st.SERN;

    /* ORDERSTEXT is ~89.6M rows, so it is fetched in BATCHES over the orders Calibrator knows.
       Measured: one order alone ~0.7s, but 20 in a single remote query ~1.9s together — roughly
       7x cheaper per order. NOTE THE MINUS SIGN; the cache key stays the positive OrderSourceId. */
    IF EXISTS (SELECT 1 FROM #WantedOrd)
    BEGIN
        CREATE TABLE #OrdQueue(ORD INT PRIMARY KEY);       -- drain a copy; #WantedOrd is needed below
        INSERT INTO #OrdQueue(ORD) SELECT ORD FROM #WantedOrd;

        DECLARE @OrdBatch TABLE(ORD INT PRIMARY KEY);
        WHILE EXISTS (SELECT 1 FROM #OrdQueue)
        BEGIN
            DELETE FROM @OrdBatch;
            INSERT INTO @OrdBatch(ORD) SELECT TOP (20) ORD FROM #OrdQueue ORDER BY ORD;

            INSERT INTO dbo.CrmOrderInstructions(ORD, OrderInstructionsZ)
            SELECT -ot.ORD,
                   COMPRESS(STRING_AGG(REVERSE(CONVERT(NVARCHAR(MAX), ot.[TEXT])), N' ') WITHIN GROUP (ORDER BY ot.TEXTLINE, ot.TEXTORD))
            FROM [31.168.173.93].amaba.dbo.ORDERSTEXT AS ot
            WHERE ot.ORD IN (SELECT -ORD FROM @OrdBatch)
            GROUP BY ot.ORD;

            DELETE q FROM #OrdQueue AS q WHERE q.ORD IN (SELECT ORD FROM @OrdBatch);
        END
    END

    /* Plain-text rendering for table cells. Outside the block above on purpose: that block only
       runs when there are new ORDs, so keeping this inside meant text added later never filled. */
    UPDATE ci SET ci.InstructionsText =
           dbo.fnStripHtml(CAST(DECOMPRESS(ci.OrderInstructionsZ) AS NVARCHAR(MAX)))
    FROM dbo.CrmOrderInstructions AS ci
    WHERE ci.OrderInstructionsZ IS NOT NULL AND ci.InstructionsText IS NULL;

    /* Negative caching — do not remove.
       Most keys have no CRM text at all, and without a row saying "checked, nothing there",
       absence is indistinguishable from "not cached yet": every incremental run re-queried them
       over the linked server, measured at 96.7s per no-op run versus 0.09s now. A row with NULL
       content means CHECKED-AND-EMPTY. Callers LEFT JOIN these tables and see NULL either way. */
    INSERT INTO dbo.CrmPartInfo(PartName, PART, PartDescription, FamilyId, FamilyDescription)
    SELECT w.PartName, NULL, NULL, NULL, NULL FROM #WantedName AS w
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CrmPartInfo c WHERE c.PartName = w.PartName);

    INSERT INTO dbo.CrmCatalogText(PART, CatalogText)
    SELECT w.PART, NULL FROM #WantedPart AS w
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CrmCatalogText c WHERE c.PART = w.PART);

    INSERT INTO dbo.CrmDeviceText(SERN, DeviceText)
    SELECT w.SERN, NULL FROM #WantedSern AS w
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CrmDeviceText c WHERE c.SERN = w.SERN);

    INSERT INTO dbo.CrmOrderInstructions(ORD, OrderInstructionsZ)
    SELECT w.ORD, NULL FROM #WantedOrd AS w
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CrmOrderInstructions c WHERE c.ORD = w.ORD);
END
GO

/* ================= dbo.fnStripHtml ================= */
-- =============================================
-- Func:        dbo.fnStripHtml
-- Jira:        MBA-792 / MBA-806
-- Description: Turns the CRM's Word-exported HTML into readable single-line plain text, so a
--              coordinator sees "כיול מבוצע ע\"י לרית / לרית צריכים להגיע עם 1000 ק\"ג" in a table
--              cell instead of "<P dir=rtl><SPAN lang=HE style='FONT-SIZE...".
--
-- Deliberately used at CACHE-FILL time (dbo.RefreshCrmTextCache), not inside a list query: this is
-- a scalar UDF with a WHILE loop, so it is fine over ~1,000 rows once and a bad idea per request.
--
-- Order matters: the <style> block goes first (it is CSS, not content), then block-level tags
-- become separators so two sentences do not weld into one, then all remaining tags are stripped,
-- then entities are decoded, then whitespace is collapsed.
-- =============================================
CREATE OR ALTER FUNCTION dbo.fnStripHtml (@html NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
WITH SCHEMABINDING
AS
BEGIN
    IF @html IS NULL RETURN NULL;

    DECLARE @s NVARCHAR(MAX) = @html;
    DECLARE @i INT, @j INT;

    -- 1. drop the CSS block entirely
    SET @i = CHARINDEX('<style', @s);
    WHILE @i > 0
    BEGIN
        SET @j = CHARINDEX('</style>', @s, @i);
        IF @j = 0 BREAK;
        SET @s = STUFF(@s, @i, @j + 8 - @i, N'');
        SET @i = CHARINDEX('<style', @s);
    END

    -- 2. block-level tags become separators, so lines stay distinguishable
    SET @s = REPLACE(@s, N'<BR>',  N' | ');
    SET @s = REPLACE(@s, N'<br>',  N' | ');
    SET @s = REPLACE(@s, N'<BR/>', N' | ');
    SET @s = REPLACE(@s, N'</P>',  N' | ');
    SET @s = REPLACE(@s, N'</p>',  N' | ');
    SET @s = REPLACE(@s, N'</DIV>', N' | ');
    SET @s = REPLACE(@s, N'</div>', N' | ');
    SET @s = REPLACE(@s, N'</LI>', N' | ');
    SET @s = REPLACE(@s, N'</TR>', N' | ');
    SET @s = REPLACE(@s, N'</tr>', N' | ');
    -- MBA-902: most of this text is a two-column instructions table, so a cell boundary is a real
    -- separator. Without these, "סוג לקוח:" ran straight into its value and the popup read as one
    -- unbroken wall of words.
    SET @s = REPLACE(@s, N'</TD>', N' | ');
    SET @s = REPLACE(@s, N'</td>', N' | ');
    SET @s = REPLACE(@s, N'</TABLE>', N' | ');
    SET @s = REPLACE(@s, N'</table>', N' | ');
    SET @s = REPLACE(@s, N'</UL>', N' | ');
    SET @s = REPLACE(@s, N'</ul>', N' | ');
    SET @s = REPLACE(@s, N'</li>', N' | ');

    -- 3. strip every remaining tag, leaving a SPACE behind rather than nothing.
    --    Priority breaks its text mid-sentence across TEXTLINE rows, and the reconstruction joins
    --    them with no delimiter, so removing a tag outright welds words together
    --    ("חייב להיות עד27/08/26"). The space is collapsed again in step 5.
    SET @i = CHARINDEX('<', @s);
    WHILE @i > 0
    BEGIN
        SET @j = CHARINDEX('>', @s, @i);
        IF @j = 0 BREAK;                      -- a stray '<' with no closing '>' — leave it alone
        SET @s = STUFF(@s, @i, @j - @i + 1, N' ');
        SET @i = CHARINDEX('<', @s);
    END

    -- 4. entities
    SET @s = REPLACE(@s, N'&nbsp;', N' ');
    SET @s = REPLACE(@s, N'&amp;',  N'&');
    SET @s = REPLACE(@s, N'&quot;', N'"');
    SET @s = REPLACE(@s, N'&#39;',  N'''');
    SET @s = REPLACE(@s, N'&lt;',   N'<');
    SET @s = REPLACE(@s, N'&gt;',   N'>');

    -- 5. collapse whitespace and tidy the separators
    SET @s = REPLACE(REPLACE(REPLACE(@s, CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' ');
    WHILE CHARINDEX(N'  ', @s) > 0 SET @s = REPLACE(@s, N'  ', N' ');
    WHILE CHARINDEX(N'| |', @s) > 0 SET @s = REPLACE(@s, N'| |', N'|');
    SET @s = LTRIM(RTRIM(@s));
    WHILE LEN(@s) > 0 AND RIGHT(@s, 1) IN (N'|', N' ') SET @s = LTRIM(RTRIM(LEFT(@s, LEN(@s) - 1)));
    WHILE LEN(@s) > 0 AND LEFT(@s, 1) IN (N'|', N' ') SET @s = LTRIM(RTRIM(RIGHT(@s, LEN(@s) - 1)));

    RETURN NULLIF(@s, N'');
END
GO

/* ================= stg.MergeCustomersContactsData ================= */
CREATE OR ALTER PROCEDURE [stg].[MergeCustomersContactsData]
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 04/06/2025
-- Description:	Merge customer contact data and create user for them to be able login to app
-- JiraLink: 
-- =============================================
AS
BEGIN

	SET NOCOUNT ON;

	MERGE INTO [dbo].[CustomerContacts] AS dest
	USING (
		SELECT 
			 c.[CustomerId]
			,cc.[CustomerContactName]
			,cc.[CustomerContactPersonRole]
			,cc.[CustomerContactPhone]
			,cc.[CustomerContactAdditionalPhoneNumber]
			,cc.[CustomerContactEmail]
			,cc.[CustomerContactIdFromSource]
			,ss.SourceId as [SourceId]
			,0 [UpdateUserID]
		FROM stg.stg_CustomerContacts as cc
		JOIN dbo.Source as ss ON cc.SourceSystem = ss.SourceName
		JOIN [dbo].[Customers] as c ON cc.[CustomerId] = c.[CustomerIdFromSource] AND c.[SourceId] = ss.SourceId 
		) AS source
		ON dest.CustomerContactIdFromSource = source.CustomerContactIdFromSource
			AND dest.[SourceId] = source.[SourceId]
	WHEN MATCHED
		AND dest.[CustomerContactName] <> source.[CustomerContactName]
		AND dest.[CustomerContactPersonRole] <> source.[CustomerContactPersonRole]
		AND dest.[CustomerContactPhone] <> source.[CustomerContactPhone]
		AND dest.[CustomerContactAdditionalPhoneNumber] = source.[CustomerContactAdditionalPhoneNumber]
		AND dest.[CustomerContactEmail] <> source.[CustomerContactEmail]
		AND dest.[CustomerContactIdFromSource] <> source.[CustomerContactIdFromSource]
		THEN
			UPDATE
			SET  dest.[CustomerId] = source.[CustomerId]
				,dest.[CustomerContactName] = source.[CustomerContactName]
				,dest.[CustomerContactPersonRole] = source.[CustomerContactPersonRole]
				,dest.[CustomerContactPhone] = source.[CustomerContactPhone]
				,dest.[CustomerContactAdditionalPhoneNumber] = source.[CustomerContactAdditionalPhoneNumber]
				,dest.[CustomerContactEmail] = source.[CustomerContactEmail]
				,dest.[CustomerContactIdFromSource] = source.[CustomerContactIdFromSource]
				,dest.[UpdatedDate] = GETDATE()
				,dest.[UpdateUserID] = 0
	WHEN NOT MATCHED
		THEN
			INSERT (
				 [CustomerId]
				,[CustomerContactName]
				,[CustomerContactPersonRole]
				,[CustomerContactPhone]
				,[CustomerContactAdditionalPhoneNumber]
				,[CustomerContactEmail]
				,[CustomerContactIdFromSource]
				,[SourceId]
				,[UpdateUserID]
				)
			VALUES (
				 source.[CustomerId]
				,source.[CustomerContactName]
				,source.[CustomerContactPersonRole]
				,source.[CustomerContactPhone]
				,source.[CustomerContactAdditionalPhoneNumber]
				,source.[CustomerContactEmail]
				,source.[CustomerContactIdFromSource]
				,source.[SourceId]
				,source.[UpdateUserID]
				);
/*
--Add customer contact as a user
	DECLARE @UserRoleId INT
	SELECT @UserRoleId = UserRoleId FROM UserRoles
	WHERE UserRoleDescriptionENG = N'Customer'

	MERGE INTO [dbo].[Users] AS dest
	USING (
		SELECT 
			 IIF(CHARINDEX(N' ', c.CustomerContactName) > 0,LEFT(c.CustomerContactName, CHARINDEX(N' ', c.CustomerContactName) - 1),'') as [FirstName]
			,IIF(CHARINDEX(N' ', REVERSE(c.CustomerContactName)) > 0,RIGHT(c.CustomerContactName,CHARINDEX(N' ', REVERSE(c.CustomerContactName)) - 1),'') as [LastName]
			,c.[CustomerContactEmail] as [Email]
			,1234 AS [Password]
			,IIF(LEN(c.[CustomerContactPhone]) > 0,c.[CustomerContactPhone], c.[CustomerContactAdditionalPhoneNumber]) as [Phone]
			,1 as [IsActive]
			,0 as [UpdateUserID]
			,@UserRoleId as[UserRoleId]
			,c.[SourceId]
	FROM [dbo].[CustomerContacts] as c
	WHERE LEN(c.[CustomerContactEmail]) > 0
		) AS source
		ON dest.[Email] = source.[Email]
	/*WHEN MATCHED
		THEN
			UPDATE
			SET  dest.[FirstName] = source.[FirstName]
				,dest.[LastName] = source.[LastName]
				,dest.[Password] = source.[Password]
				,dest.[Phone] = source.[Phone]
				,dest.[IsActive] = source.[IsActive]
				,dest.[UpdateUserID] = source.[UpdateUserID]
				,dest.[UserRoleId] = source.[UserRoleId]
				,dest.[SourceId] = source.[SourceId]*/
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [FirstName]
				,[LastName]
				,[Email]
				,[Password]
				,[Phone]
				,[IsActive]
				,[UpdateUserID]
				,[UserRoleId]
				,[SourceId]
				)
			VALUES (
				 source.[FirstName]
				,source.[LastName]
				,source.[Email]
				,source.[Password]
				,source.[Phone]
				,source.[IsActive]
				,source.[UpdateUserID]
				,source.[UserRoleId]
				,source.[SourceId]
				);
				*/

END
GO

/* ================= stg.MergeOrdersData ================= */
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/04/2025
-- Description:	Merge orders data from amaba
-- JiraLink: 
-- =============================================
CREATE OR ALTER PROCEDURE [stg].[MergeOrdersData]
AS
BEGIN

SET NOCOUNT ON;

/*Clean-up Main categories*/

UPDATE t
SET MainCategorySourceId =
    CASE LTRIM(RTRIM(t.MainCategorySourceId))
        WHEN N'אורך'                    THEN N'אורך וזווית'
        WHEN N'אורך מדוייקים'           THEN N'אורך וזווית'
        WHEN N'אל חמה'                  THEN N'NA'
        WHEN N'אלקטרוניקה'              THEN N'אלקטרוניקה'
        WHEN N'בדיקות דגם'              THEN N'NA'
        WHEN N'גלאי גזים'               THEN N'גזים'
        WHEN N'גפן'                     THEN N'NA'
        WHEN N'זמן'                     THEN N'זמן'
        WHEN N'טמפרטורה'                THEN N'טמפרטורה ולחות'
        WHEN N'כח'                      THEN N'כוח'
        WHEN N'לחות'                    THEN N'טמפרטורה ולחות'
        WHEN N'לחץ'                     THEN N'לחץ'
        WHEN N'ללא מחלקה'               THEN N'NA'
        WHEN N'מאגנוס'                  THEN N'אלקטרוניקה'
        WHEN N'מדידים'                  THEN N'אורך וזווית'
        WHEN N'מהירות אוויר'            THEN N'מהירות אוויר'
        WHEN N'מומנט'                   THEN N'מומנט'
        WHEN N'מכונות'                  THEN N'NA'
        WHEN N'מסה'                     THEN N'מסה'
        WHEN N'מקבילונים'               THEN N'אורך וזווית'
        WHEN N'נפח'                     THEN N'נפח'
        WHEN N'סיבוב'                   THEN N'אורך וזווית'
        WHEN N'ספיקה'                   THEN N'ספיקה'
        WHEN N'קבלני משנה'              THEN N'NA'
        WHEN N'קבלני משנה כללי'         THEN N'NA'
        WHEN N'קושי'                    THEN N'קשיות'
        WHEN N'רדיומטריה ופוטומטריה'    THEN N'רדיומטריה'
        WHEN N'שירותי איכות ורגולציה'   THEN N'NA'
        WHEN N'תעשיה אוירית'            THEN N'NA'
        ELSE t.MainCategorySourceId
    END
FROM [stg].[stg_Orders] AS t;



DROP TABLE IF EXISTS #OrderStatus
CREATE TABLE #OrderStatus
(
StatusId INT NOT NULL,
CodeINT INT,
StatusType NVARCHAR(50)COLLATE Latin1_General_100_CI_AI_SC,
Code NVARCHAR(255) COLLATE Latin1_General_100_CI_AI_SC,
StatusDescriptionENG NVARCHAR(255) COLLATE Latin1_General_100_CI_AI_SC
)
INSERT #OrderStatus (StatusId,CodeINT,StatusType,Code,StatusDescriptionENG)
SELECT s.StatusId, TRY_CAST(s.Code AS INT) as CodeINT, sc.StatusDescriptionENG as StatusType, s.Code ,s.StatusDescriptionENG
FROM [dbo].[Statuses] as s
JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
WHERE sc.StatusDescriptionENG IN('OrderStatus','ReportStatus','CalibrationStatuses')

DECLARE @InintialOrderStatus INT  
SELECT @InintialOrderStatus = StatusId FROM #OrderStatus as os WHERE os.StatusType = N'OrderStatus' AND os.StatusDescriptionENG = 'WaitingForCalibration'

MERGE INTO [dbo].[OrderWorkPlans] AS dest
USING (
SELECT DISTINCT
	     o.ORDNAME as [OrderNumber]
		,o.OpenDate as [WorkPlanOpenDate]
		,GETDATE() AS [CreatedDate]
		,0 as [UpdateUserID]
		,0 as [CreatedByUserId]
		,0 as [IsCancelled]
		,c.[CustomerId]
		,NULL as [Notes]
		,ss.[SourceId]
		,@InintialOrderStatus as OrderOverallStatusId
		,IIF(LEN(o.[ShipTypeDesc]) > 1,o.[ShipTypeDesc],NULL) as [ShipTypeDesc]
		,o.SourceOrderId as [OrderSourceId]
		FROM [stg].[stg_Orders] as o
	JOIN [dbo].[Source] as ss ON o.[SourceSystem] = ss.SourceName
    LEFT JOIN [dbo].[Customers] as c ON c.CustomerIdFromSource = o.CustomerSourceId AND c.SourceId = ss.SourceId AND c.IsDeleted = 0
	) AS source
	ON dest.[OrderSourceId] = source.[OrderSourceId] AND dest.[SourceId] = source.[SourceId]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
             [OrderNumber]
			,[WorkPlanOpenDate]
			,[CreatedDate]
			,[CreatedByUserId]
			,[UpdateUserID]
			,[IsCancelled]
			,[Notes]
			,[OrderSourceId]
			,[SourceId]
			,[CustomerId]
			,[OrderOverallStatusId]
			,[ShipTypeDesc]
			)
		VALUES (
			 source.[OrderNumber]
			,source.[WorkPlanOpenDate]
			,source.[CreatedDate]
			,source.[CreatedByUserId]
			,source.[UpdateUserID]
			,source.[IsCancelled]
			,source.[Notes]
			,source.[OrderSourceId]
			,source.[SourceId]
			,source.[CustomerId]
			,source.[OrderOverallStatusId]
			,source.[ShipTypeDesc]

			);


MERGE INTO [dbo].[OrderDetails] AS dest
USING (
	SELECT DISTINCT
	    wp.[OrderWorkPlanId]
		,o.[SpecialCareTypeId]
		,CASE 
			WHEN RIGHT(o.[PartName], 2) IN ('-7','-8','-9') AND TRY_CAST(RIGHT(o.[PartName], 2) AS INT) IS NOT NULL THEN 0 
			WHEN RIGHT(o.[PartName], 2) IN ('-3','-0','-1') AND TRY_CAST(RIGHT(o.[PartName], 2) AS INT) IS NOT NULL THEN 1 --10 should be external 
		ELSE NULL END  as [IsInHouse]
		,o.[PartName]
		--,o.[KLINE]
		,o.[PART]
		,GETDATE() as [CreatedDate]
		,GETDATE() as [UpdatedDate]
		,0 as [CreatedByUserId]
		,0 as [UpdateUserID]
		,o.OrderLineCnt
		,pt.OrdersProductTypeId
		,o.DeviceType 
		,o.OrderDetailId as OrderDetailSourceId
		,o.VPRICE	
		,o.PRICE
		,mc.[ID] as [MainCategoryId]
		,sc.ID as [SecondaryCategoryId]
		,o.[CustomerPackingExists]
	    ,o.[PackageLocation]
		,cs.CustomerSiteId
	FROM [stg].[stg_Orders] as o
	JOIN [dbo].[Source] as s ON o.SourceSystem = s.SourceName
	JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderSourceId = o.SourceOrderId AND o.SourceSystem = s.SourceName
	LEFT JOIN [dbo].[OrdersProductTypes] as pt ON pt.OrdersProductTypeName = o.DeviceType and pt.IsDeleted = 0
	LEFT JOIN [dbo].[MainCategories] as mc ON o.MainCategorySourceId = mc.MainCategoryName and mc.IsDeleted = 0
	LEFT JOIN [dbo].[SecondaryCategories] as sc ON o.SecondCategorySourceId = sc.SecondaryCategoryName and sc.IsDeleted = 0
    LEFT JOIN [dbo].[Customers] as c ON c.CustomerIdFromSource = o.CustomerSourceId AND c.SourceId = s.SourceId AND c.IsDeleted = 0
	LEFT JOIN [dbo].[CustomerSites] as cs ON c.CustomerId = cs.CustomerId AND cs.CustomerSiteCode = o.[DESTCODE] AND cs.IsDeleted = 0
	) AS source
	ON dest.[OrderWorkPlanId] = source.[OrderWorkPlanId] AND source.OrderDetailSourceId = dest.[OrderDetailSourceId] 
WHEN MATCHED AND
	(
		  COALESCE(dest.[SpecialCareTypeId],0) <> COALESCE(source.[SpecialCareTypeId],0)
		OR COALESCE(dest.[IsInHouse],0) <> COALESCE(source.[IsInHouse],0)
		OR COALESCE(dest.[OrderLineCnt],0) <> COALESCE(source.[OrderLineCnt],0)
		OR COALESCE(dest.OrdersProductTypeId,0) <> COALESCE(source.[OrdersProductTypeId],0)
		OR COALESCE(dest.[PART],0) <> COALESCE(source.[PART],0)
		OR COALESCE(dest.[VPRICE],0) <> COALESCE(source.[VPRICE],0)
		OR COALESCE(dest.[PRICE],0) <> COALESCE(source.[PRICE],0)
		OR COALESCE(dest.[MainCategoryId],0) <> COALESCE(source.[MainCategoryId],0)
		OR COALESCE(dest.[SecondaryCategoryId],0) <> COALESCE(source.[SecondaryCategoryId],0)
		OR COALESCE(dest.[CustomerPackingExists],0) <> COALESCE(source.[CustomerPackingExists],0) 
		OR COALESCE(dest.[CustomerSiteId],0) <> COALESCE(source.[CustomerSiteId],0)
		OR COALESCE(dest.[PackageLocation],'') <> COALESCE(source.[PackageLocation],'')
		OR COALESCE(dest.[PartName],'') <> COALESCE(source.[PartName],'')
	)
	THEN
		UPDATE
		SET  dest.[SpecialCareTypeId] = source.[SpecialCareTypeId]
			,dest.[IsInHouse] = source.[IsInHouse]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[UpdateUserID] = source.[UpdateUserID]
			,dest.[OrderLineCnt] = source.[OrderLineCnt]
			,dest.[OrdersProductTypeId] = source.[OrdersProductTypeId]
			,dest.[PART] = source.[PART]
			,dest.[VPRICE] = source.[VPRICE]
			,dest.[PRICE] = source.[PRICE]
			,dest.[MainCategoryId] = source.[MainCategoryId]
			,dest.[SecondaryCategoryId] = source.[SecondaryCategoryId]
			,dest.[CustomerPackingExists] = source.[CustomerPackingExists]
			,dest.[CustomerSiteId] = source.[CustomerSiteId]
			,dest.[PackageLocation] = source.[PackageLocation]
			,dest.[PartName] = source.[PartName]

WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[OrderWorkPlanId]
			,[SpecialCareTypeId]
			,[IsInHouse]
			,[PartName]
			--,[KLINE]
			,[CreatedDate]
			,[UpdatedDate]
			,[CreatedByUserId]
			,[UpdateUserID]
			,[OrderLineCnt]
			,[OrdersProductTypeId]
			,[PART]
			,[OrderDetailSourceId]
			,[VPRICE]	
			,[PRICE]
			,[MainCategoryId]
			,[SecondaryCategoryId]
			,[CustomerPackingExists]
			,[CustomerSiteId]
			,[PackageLocation]
			)
		VALUES (
			 source.[OrderWorkPlanId]
			,source.[SpecialCareTypeId]
			,source.[IsInHouse]
			,source.[PartName]
		--	,source.[KLINE]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[CreatedByUserId]
			,source.[UpdateUserID]
			,source.[OrderLineCnt]
			,source.[OrdersProductTypeId]
			,source.[PART]
			,source.[OrderDetailSourceId]
			,source.[VPRICE]	
			,source.[PRICE]
			,source.[MainCategoryId]
			,source.[SecondaryCategoryId]
			,source.[CustomerPackingExists]
			,source.[CustomerSiteId]
			,source.[PackageLocation]
			);

MERGE INTO [dbo].[OrderDetailsItems] AS dest
USING (
	SELECT DISTINCT
	     o.[SerialNumber]
		,od.OrderDetailId
		,o.[ManufacturerNumber]
		,REVERSE(o.[Devicemodel]) as [DeviceModel]
		,o.[SpecialCareTypeId]
		,o.[InHouse] as [IsInHouse]
		,o.[PartName]
		,o.[MbaReportNumber]
		,c.[CustomerId]
		,o.[KLINE]
		,o.[SERN]
	    ,o.[ProductLocation]
		,NULL AS [StatusId]
		,GETDATE() as [CreatedDate]
		,GETDATE() as [UpdatedDate]
		,0 as [CreatedByUserId]
		,0 as [UpdateUserID]
		,o.[Doc]
		,o.[NextCalibrationDate]
		,o.AdditionalDeviceNumber
		,NULL /*o.CalibDate*/ as [ActualCalibrationDate]
		--,os.StatusId as CalibrationReportStatusId
		--,IIF(os2.Code <> N'CO',os2.StatusId,-1) as CalibrationStatusId
		,NULL AS CustomerReceivingDate
		,IIF(LEN(o.ShippingDoc) > 1,o.ShippingDoc,NULL) as ShippingDoc
		,IIF(LEN(o.ShippingAddress) > 1,o.ShippingAddress,NULL) as  ShippingAddress
		,o.DOC_N
	    ,IIF(o.[ActualReturnDate] > GETDATE()-100,o.[ActualReturnDate],NULL) as [ActualReturnDate]
	    ,IIF(o.[ExpectedReturnDate] > GETDATE()-100,o.[ExpectedReturnDate],NULL) as [ExpectedReturnDate]
		,o.OrdersDeviceManufacturer
	FROM [stg].[stg_Orders] as o
	JOIN [dbo].[Source] as s ON o.SourceSystem = s.SourceName
	JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderSourceId = o.SourceOrderId
	JOIN [dbo].[OrderDetails] as od ON wp.[OrderWorkPlanId] = od.[OrderWorkPlanId] AND od.OrderDetailSourceId = o.OrderDetailId
	LEFT JOIN [dbo].[Customers] as c ON c.CustomerIdFromSource = o.CustomerSourceId AND c.SourceId = s.SourceId and c.IsDeleted = 0
	--LEFT JOIN #OrderStatus AS os ON o.CurrentCalibrationStatus = os.Code AND os.StatusType = N'ReportStatus'
	--LEFT JOIN #OrderStatus AS os2 ON o.CurrentCalibrationStatus = os2.Code AND os2.StatusType = N'CalibrationStatuses'
	WHERE o.OrderDetailId IS NOT NULL AND o.Doc IS NOT NULL
	) AS source
	ON dest.OrderDetailId = source.OrderDetailId AND source.[Doc] = dest.[Doc]
  WHEN MATCHED
        AND (
		-- change-detection corrected 2026-08-23: every predicate below is '<>', the group closes
		-- at the END of the list, and dest.[Doc] = source.[Doc] is gone because the MERGE ON
		-- clause already requires it — as a predicate it was always TRUE and on its own forced
		-- an UPDATE of every matched row on every run.
		   COALESCE(dest.[SerialNumber],'') <> COALESCE(source.[SerialNumber],'')
		OR COALESCE(dest.[ManufacturerNumber],'') <> COALESCE(source.[ManufacturerNumber],'')
		OR COALESCE(dest.[DeviceModel],'') <> COALESCE(source.[DeviceModel],'')
		OR COALESCE(dest.[MbaReportNumber],'') <> COALESCE(source.[MbaReportNumber],'')
		OR COALESCE(dest.[UpdatedDate],'1900-01-01') <> source.[UpdatedDate]
		OR COALESCE(dest.[UpdateUserID],0) <> source.[UpdateUserID]
		OR COALESCE(dest.[ProductLocation],'') <> COALESCE(source.[ProductLocation],'')
		OR COALESCE(dest.[NextCalibrationDate],'1900-01-01') <> COALESCE(source.[NextCalibrationDate],'1900-01-01')
		OR COALESCE(dest.[AdditionalDeviceNumber],'') <> COALESCE(source.[AdditionalDeviceNumber],'')
		OR COALESCE(dest.[ActualCalibrationDate],'1900-01-01') <> COALESCE(source.[ActualCalibrationDate],'1900-01-01')
		OR COALESCE(dest.CustomerReceivingDate,'1900-01-01') <> COALESCE(source.CustomerReceivingDate,'1900-01-01')
		OR COALESCE(dest.[ShippingDoc],'') <> COALESCE(source.[ShippingDoc],'')
		OR COALESCE(dest.[ShippingAddress],'') <> COALESCE(source.[ShippingAddress],'')
		OR COALESCE(dest.[DOC_N],0) <> COALESCE(source.[DOC_N],0)
		OR COALESCE(dest.[ActualReturnDate],'1900-01-01') <> COALESCE(source.[ActualReturnDate],'1900-01-01')
		OR COALESCE(dest.[ExpectedReturnDate],'1900-01-01') <> COALESCE(source.[ExpectedReturnDate],'1900-01-01')
		)


	THEN
		UPDATE
		SET  dest.[SerialNumber] = source.[SerialNumber]
			,dest.[ManufacturerNumber] = source.[ManufacturerNumber]
			,dest.[DeviceModel] = source.[DeviceModel]
			,dest.[MbaReportNumber] = source.[MbaReportNumber]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[UpdateUserID] = source.[UpdateUserID]
			,dest.[ProductLocation] = source.[ProductLocation]
			,dest.[Doc] = source.[Doc]
			,dest.[NextCalibrationDate] = source.[NextCalibrationDate]
			,dest.[AdditionalDeviceNumber] = source.[AdditionalDeviceNumber]
			,dest.[ActualCalibrationDate] = source.[ActualCalibrationDate]
			--,dest.[CalibrationReportStatusId] = IIF(dest.[UpdateUserID] = 0,source.[CalibrationReportStatusId],dest.[CalibrationReportStatusId])
		   -- ,dest.[CalibrationStatusId] = IIF(dest.[UpdateUserID] = 0 and source.CalibrationStatusId > 0,source.CalibrationStatusId,dest.CalibrationStatusId) -- Calibration status can not be delivered, but on source report and calibration statuses same column 
		    ,dest.[CustomerReceivingDate] = source.[CustomerReceivingDate]
		    ,dest.[ShippingDoc] = source.[ShippingDoc]
		    ,dest.[ShippingAddress] = source.[ShippingAddress]
			,dest.[DOC_N] = source.[DOC_N]
			,dest.[ActualReturnDate] = source.[ActualReturnDate]
			,dest.[ExpectedReturnDate] = source.[ExpectedReturnDate]
			
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[OrderDetailId]
			,[SerialNumber]
			,[ManufacturerNumber]
			,[DeviceModel]
			,[MbaReportNumber]
			,[CreatedDate]
			,[UpdatedDate]
			,[CreatedByUserId]
			,[UpdateUserID]
			,[SERN]
			,[ProductLocation]
			,[Doc]
			,[NextCalibrationDate]
			,[AdditionalDeviceNumber]
			,[ActualCalibrationDate]
		--	,[CalibrationReportStatusId]
		--  ,[CalibrationStatusId]
		    ,[CustomerReceivingDate]
		    ,[ShippingDoc]
		    ,[ShippingAddress]
			,[DOC_N]
			,[ActualReturnDate]
			,[ExpectedReturnDate]
			,[OrdersDeviceManufacturer]
			)
		VALUES (
			 source.[OrderDetailId]
			,source.[SerialNumber]
			,source.[ManufacturerNumber]
			,source.[DeviceModel]
			,source.[MbaReportNumber]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[CreatedByUserId]
			,source.[UpdateUserID]
			,source.[SERN]
			,source.[ProductLocation]
			,source.[Doc]
			,source.[NextCalibrationDate]
			,source.[AdditionalDeviceNumber]
			,source.[ActualCalibrationDate]
		--	,source.[CalibrationReportStatusId]
		--  ,NULLIF(source.[CalibrationStatusId],-1)
		    ,source.[CustomerReceivingDate]
		    ,source.[ShippingDoc]
		    ,source.[ShippingAddress]
			,source.[DOC_N]
			,source.[ActualReturnDate]
			,source.[ExpectedReturnDate]
			,source.[OrdersDeviceManufacturer]
			);

			

	/* ---------------------------------------------------------------------------------------
	   Top up the Priority CRM cache (dbo.CrmCatalogText / CrmDeviceText / CrmPartInfo) for any
	   PART/SERN this sync just introduced. Hooked here on purpose: this sync is what creates new
	   keys, so the cache cannot drift and needs no SQL Agent job (the app login is db_owner on
	   Calibrator but has no server-level rights, so it cannot create one).
	   Incremental mode costs ~0.1s and issues NO linked-server traffic when nothing is new.
	   TRY/CATCH: a CRM top-up must never fail the order sync.
	   --------------------------------------------------------------------------------------- */
	BEGIN TRY
		EXEC dbo.RefreshCrmTextCache @IncrementalOnly = 1;
		/* Re-derive device categories from the Priority family. Must run AFTER the cache top-up
		   (it reads dbo.CrmPartInfo) and after the MERGEs above, which write MainCategoryId back
		   from staging for the rows in the rolling window and would otherwise undo the derivation
		   on exactly those rows. */
		EXEC dbo.ApplyPartFamilyCategories;
	END TRY
	BEGIN CATCH
		/* swallowed on purpose - see above */
	END CATCH
END
GO

GO
/* =====================================================================
   dbo.AssignProductIdentificationData  (MBA-577)
   Not in the original diff - PROD and STAGE matched when this package was
   generated. STAGE has since gained the three sensor fields, so PROD needs
   this too. Depends on the three OrderDetailsItems columns in tranche A.
   ===================================================================== */
/*
    dbo.AssignProductIdentificationData                                                MBA-577
    ---------------------------------------------------------------------------------------------
    Saves the Identification page. This copy adds the three fields the sensor calibration wizard
    needs, which the front end was already sending and the procedure was rejecting:

        Tolerance                  "סטייה מותרת"   DECIMAL(18,6)
        Resolution                 "רזולוציה"      DECIMAL(18,6)
        SpecificationReferenceIds  reference docs  NVARCHAR(MAX), a CSV of ids

    Why a CSV and not a link table
    ------------------------------
    Reference Document became multi-select. The column that held it, SpecificationReferenceId, is
    a single INT and stays exactly as it was so anything still sending it keeps working. The new
    column follows MeasurementValueList on the same table - a comma-separated list in one NVARCHAR
    - because that is the pattern this table already uses and the one the front end is coded to.
    A proper link table would be tidier and is a separate change.

    The NULL convention, and the one place it breaks
    ------------------------------------------------
    Every parameter here means "leave it alone" when NULL. That works for Tolerance and Resolution.
    It does not work for a multi-select: deselecting every reference document has to be storable,
    and under COALESCE the last selection would be impossible to remove. So an empty string clears
    the column and NULL leaves it - the same shape DiagramMapLink already uses on the line above.

    Round-tripped on STAGE against a live item: write, clear-the-list, restore.
*/
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 21/06/2025
-- Description:	Procedure enrich data for calibrated device in orders
-- JiraLink: 
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[AssignProductIdentificationData]
@UserEmail NVARCHAR(50),
@OrderDetailId INT,
@OrderDetailsItemId INT = NULL,
@ActualCalibrationDate DATETIME2(0)= NULL,	
@NextCalibrationDate DATETIME2(0)= NULL,	
@SerialNumber NVARCHAR(100)= NULL,
@ManufacturerNumber	NVARCHAR(100)= NULL,
@DeviceModel NVARCHAR(100)= NULL,	
@AdditionalDeviceNumber NVARCHAR(100)= NULL,
@OrdersMainCategoryId INT= NULL,
@OrdersSecondaryCategoryId INT= NULL,
@OrdersDeviceManufacturer NVARCHAR(100) = NULL,
@OrdersProductTypeId INT= NULL,
@CalibrationSpecificationId INT= NULL,
@SpecificationReferenceId INT= NULL,
@MeasurementUnitId INT= NULL,
@MeasurementPoints INT= NULL,
@MeasurementValueList NVARCHAR(MAX) = NULL,
@OrderLineCnt_new INT = NULL,
@Accuracy TINYINT = NULL,
@MbaReportNumber NVARCHAR(100) =NULL,
@StickerAmount TINYINT = NULL,
@StickerTypeId INT = NULL,
@SecondCalibratorId INT = NULL,
@MainCalibratorId INT = NULL,
@Volume DECIMAL(16,4) = NULL,
@VisualCheck NVARCHAR(200) = NULL,
@ShouldShowGraphV BIT = NULL, 
@ShouldShowCertificateIcon BIT = NULL,
@RequiredProbability TINYINT = NULL,
@ReportLanguage NVARCHAR(50) = NULL,
@SiteAddress NVARCHAR(100) = NULL,
@ProductLocation NVARCHAR(50) = NULL,
@ControllerType NVARCHAR(40) = NULL,
@DiagramMapLink NVARCHAR(200) = NULL,
	/* MBA-577: sensor identification. Tolerance and Resolution are scalar.
	   SpecificationReferenceIds is a CSV because Reference Document became multi-select;
	   the older singular SpecificationReferenceId is left in place so anything still
	   sending it keeps working. */
	@Tolerance DECIMAL(18,6) = NULL,
	@Resolution DECIMAL(18,6) = NULL,
	@SpecificationReferenceIds NVARCHAR(MAX) = NULL
AS
BEGIN 

	DECLARE @OrderDetailItemIdInserted INT
	DECLARE @UserId INT = (SELECT ID FROM [dbo].[Users] WHERE Email = @UserEmail) 

	/*In some cases there are no information in order details and we need to insert it*/
	IF NOT EXISTS (SELECT 1 FROM [dbo].[OrderDetailsItems] WHERE OrderDetailId = @OrderDetailId AND OrderDetailsItemId =@OrderDetailsItemId )
		BEGIN
			INSERT INTO [dbo].[OrderDetailsItems]
					   ([OrderDetailId]
					   ,[ActualCalibrationDate]
					   ,[NextCalibrationDate]
					   ,[SerialNumber]
					   ,[ManufacturerNumber]
					   ,[DeviceModel]
					   ,[AdditionalDeviceNumber]
					   ,[CalibrationSpecificationId]
					   ,[SpecificationReferenceId]
					   ,[MeasurementUnitId]
					   ,[MeasurementPoints]
					   ,[MeasurementValueList]
					   ,[CreatedDate]
					   ,[CreatedByUserId]
					   ,[Accuracy]
					   ,[IsManuallyAdded]
					   ,[MbaReportNumber]
					   ,[StickerAmount]
					   ,[StickerTypeId]
					   ,[SecondCalibratorId]
					   ,[MainCalibratorId]
					   ,[Volume]
					   ,[VisualCheck]
					   ,[ShouldShowGraphV]
					   ,[ShouldShowCertificateIcon]
					   ,[RequiredProbability]
					   ,[ReportLanguage]
					   ,[SiteAddress]
					   ,[ProductLocation]
					   ,[OrdersDeviceManufacturer] 
					   ,[ControllerType]
					   ,[DiagramMapLink]
					   ,[Tolerance]
					   ,[Resolution]
					   ,[SpecificationReferenceIds]
					)
				 SELECT
					@OrderDetailId,	
					@ActualCalibrationDate,	
					@NextCalibrationDate,	
					@SerialNumber,
					@ManufacturerNumber,
					@DeviceModel,	
					@AdditionalDeviceNumber,
					@CalibrationSpecificationId,
					@SpecificationReferenceId,
					@MeasurementUnitId,
					@MeasurementPoints,
					@MeasurementValueList,
					GETDATE(),
					@UserId,
					@Accuracy,
					1,
					@MbaReportNumber,
					@StickerAmount,
					@StickerTypeId,
					@SecondCalibratorId,
					@MainCalibratorId,
					@Volume,
					@VisualCheck,
					@ShouldShowGraphV,
					@ShouldShowCertificateIcon,
					@RequiredProbability,
					@ReportLanguage,
					@SiteAddress,
					@ProductLocation,
					@OrdersDeviceManufacturer,
					@ControllerType,
					@DiagramMapLink,
					@Tolerance,
					@Resolution,
					NULLIF(@SpecificationReferenceIds, '')
				SELECT @OrderDetailItemIdInserted = SCOPE_IDENTITY()

		END

	UPDATE [dbo].[OrderDetails] 
	SET [OrdersProductTypeId] = IIF(@OrdersProductTypeId IS NULL,[OrdersProductTypeId], @OrdersProductTypeId)
		,[MainCategoryId] = IIF(@OrdersMainCategoryId IS NULL,[MainCategoryId], @OrdersMainCategoryId)
		,[SecondaryCategoryId] =IIF(@OrdersSecondaryCategoryId IS NULL,[SecondaryCategoryId],@OrdersSecondaryCategoryId)
	WHERE OrderDetailId = @OrderDetailId-- AND [OrdersProductTypeId] <> @OrdersProductTypeId

	UPDATE [dbo].[OrderDetails] 
	SET [OrderLineCnt] = IIF(@OrderLineCnt_new IS NULL,[OrderLineCnt], @OrderLineCnt_new)
	WHERE OrderDetailId = @OrderDetailId AND [OrderLineCnt] <> COALESCE(@OrderLineCnt_new,[OrderLineCnt])

	UPDATE [dbo].[OrderDetailsItems]
			SET 
			 [ActualCalibrationDate] = IIF(@ActualCalibrationDate IS NULL,[ActualCalibrationDate],@ActualCalibrationDate)
			,[NextCalibrationDate] = IIF(@NextCalibrationDate IS NULL,[NextCalibrationDate],@NextCalibrationDate)
			,[SerialNumber] = IIF(@SerialNumber IS NULL,[SerialNumber],@SerialNumber)
			,[ManufacturerNumber] = IIF(@ManufacturerNumber IS NULL,[ManufacturerNumber],@ManufacturerNumber)
			,[DeviceModel] = IIF(@DeviceModel IS NULL,[DeviceModel],@DeviceModel)
			,[AdditionalDeviceNumber] = IIF(@AdditionalDeviceNumber IS NULL,[AdditionalDeviceNumber],@AdditionalDeviceNumber)
			,[CalibrationSpecificationId] = IIF(@CalibrationSpecificationId IS NULL,[CalibrationSpecificationId],@CalibrationSpecificationId)
			,[SpecificationReferenceId] = IIF(@SpecificationReferenceId IS NULL,[SpecificationReferenceId],@SpecificationReferenceId)
			,[MeasurementUnitId] = IIF(@MeasurementUnitId IS NULL,[MeasurementUnitId],@MeasurementUnitId)
			,[MeasurementPoints] = IIF(@MeasurementPoints IS NULL,[MeasurementPoints],@MeasurementPoints)
			,[MeasurementValueList] = IIF(@MeasurementValueList IS NULL,[MeasurementValueList],@MeasurementValueList)
			,[UpdatedDate] = GETDATE()
			,[UpdateUserID] = @UserId
			,[Accuracy] = IIF(@Accuracy IS NULL,[Accuracy],@Accuracy)
			,[MbaReportNumber] = IIF(@MbaReportNumber IS NULL,[MbaReportNumber],@MbaReportNumber)
			,[StickerAmount] = IIF(@StickerAmount IS NULL,[StickerAmount],@StickerAmount)
			,[StickerTypeId] = IIF(@StickerTypeId IS NULL,[StickerTypeId],@StickerTypeId)
			,[SecondCalibratorId] = COALESCE(@SecondCalibratorId,[SecondCalibratorId])
			,[MainCalibratorId] = COALESCE(@MainCalibratorId,[MainCalibratorId])
			,[Volume] = COALESCE(@Volume,[Volume])
			,[VisualCheck] = COALESCE(@VisualCheck,[VisualCheck])
			,[ShouldShowGraphV] = COALESCE(@ShouldShowGraphV,[ShouldShowGraphV])
			,[ShouldShowCertificateIcon] = COALESCE(@ShouldShowCertificateIcon,[ShouldShowCertificateIcon])
			,[RequiredProbability] = COALESCE(@RequiredProbability,[RequiredProbability])
			,[ReportLanguage] = COALESCE(@ReportLanguage,[ReportLanguage])
			,[SiteAddress] = COALESCE(@SiteAddress,[SiteAddress])
			,[ProductLocation] = COALESCE(@ProductLocation,[ProductLocation])
			,[OrdersDeviceManufacturer] = COALESCE(@OrdersDeviceManufacturer,[OrdersDeviceManufacturer])
			,[ControllerType] = COALESCE(@ControllerType,[ControllerType])
			,[DiagramMapLink] = IIF(@DiagramMapLink ='',NULL,COALESCE(@DiagramMapLink,[DiagramMapLink]))
			,[Tolerance] = COALESCE(@Tolerance,[Tolerance])
			,[Resolution] = COALESCE(@Resolution,[Resolution])
			/* '' clears the selection, NULL leaves it alone. Deselecting every reference
			   document has to be storable, and COALESCE on its own would make that
			   impossible. Same shape as DiagramMapLink above. */
			,[SpecificationReferenceIds] = IIF(@SpecificationReferenceIds = '',NULL,COALESCE(@SpecificationReferenceIds,[SpecificationReferenceIds]))
	WHERE [OrderDetailId] = @OrderDetailId AND OrderDetailsItemId = COALESCE(@OrderDetailsItemId,@OrderDetailItemIdInserted)

	SELECT COALESCE(@OrderDetailsItemId,@OrderDetailItemIdInserted) as OrderDetailsItemId
END

GO
