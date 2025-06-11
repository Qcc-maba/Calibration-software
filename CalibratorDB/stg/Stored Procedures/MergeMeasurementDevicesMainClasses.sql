-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 11/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE PROCEDURE [stg].[MergeMeasurementDevicesMainClasses]
AS
BEGIN

SET NOCOUNT ON;

	MERGE INTO [dbo].[MeasurementDevicesMainClasses] AS dest
	USING (
		SELECT [MeasurementDevicesMainClassSourceId]
			,s.[NameHe] as [NameHebrew]
			,s.[NameEn] as [NameEnglish]
			,GETDATE() as [UpdatedTime]
			,0 as [UpdateUserID]
		FROM [stg].[stg_MeasurementDevicesMainClasses] as s
		) AS source
		ON dest.[MeasurementDevicesMainClassSourceId] = source.[MeasurementDevicesMainClassSourceId]
	WHEN MATCHED AND
		(
		dest.[NameHebrew] <> source.[NameHebrew]
		OR dest.[NameEnglish] <> source.[NameEnglish]
		)
		THEN
			UPDATE
			SET  dest.[NameHebrew] = source.[NameHebrew]
				,dest.[NameEnglish] = source.[NameEnglish]
				,dest.[UpdatedTime] = source.[UpdatedTime]
				,dest.[UpdateUserID] = source.[UpdateUserID]
			
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [NameHebrew]
				,[NameEnglish]
				,[UpdateUserID]
				,[MeasurementDevicesMainClassSourceId]
				)
			VALUES (
				 source.[NameHebrew]
				,source.[NameEnglish]
				,source.[UpdateUserID]
				,source.[MeasurementDevicesMainClassSourceId]
				);
END