-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 07/01/2026
-- Description:	Assign environmental conditions for calibrated device
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-478
--Json example
--'
--[
--  {"OrderDetailsItemId": 1254,"MeasurementDeviceUnitId": 12, "NominalValue": 30,"Tolerance": 12.54},
--  {"OrderDetailsItemId": 1255,"MeasurementDeviceUnitId": 10,"NominalValue": 33,"Tolerance": 1.54 }
--]'
-- =============================================
CREATE    PROCEDURE [dbo].[AssignCalibrationEnvironmentalConditions]
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
			Tolerance
		FROM OPENJSON (@ConditionsJson) WITH (
			OrderDetailsItemId INT '$.OrderDetailsItemId',
			MeasurementDeviceUnitId INT'$.MeasurementDeviceUnitId',
			NominalValue DECIMAL(18,6) '$.NominalValue',
			Tolerance DECIMAL(18,6) '$.Tolerance'
		)
		) AS source
		ON dest.[OrderDetailsItemId] = source.[OrderDetailsItemId]
			AND dest.[MeasurementDeviceUnitId] = source.[MeasurementDeviceUnitId]
	WHEN MATCHED
		THEN
			UPDATE
			SET  dest.[NominalValue] = source.[NominalValue]
				,dest.[Tolerance] = source.[Tolerance]
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
				,[CreateDate]
				,[UpdateUserID]
				)
			VALUES (
				source.[OrderDetailsItemId]
				,source.[MeasurementDeviceUnitId]
				,source.[NominalValue]
				,source.[Tolerance]
				,GETDATE()
				,@LoggedInUserId
				);

END