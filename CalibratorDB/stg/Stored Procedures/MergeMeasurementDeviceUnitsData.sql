-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 10/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE PROCEDURE [stg].[MergeMeasurementDeviceUnitsData]
AS
BEGIN

SET NOCOUNT ON;

	MERGE INTO [dbo].[MeasurementDeviceUnits] AS dest
	USING (
		SELECT 
			 mdu.[ShortNameEn]
			,mdu.[ShortNameEnAsc]
			,mdu.[LongNameEn]
			,mdu.[ShortNameHeAsc]
			,mdu.[ShortNameHe]
			,mdu.[LongNameHe]
			,mug.[MeasurementDeviceUnitGroupId]
			,mdu.[Note]
			,mdu.[MeasurementDeviceUnitSourceId]
			,GETDATE() as [UpdatedDate]
			,0 [UpdateUserID]
		FROM [stg].[stg_MeasurementDeviceUnits] as mdu
		JOIN [dbo].[MeasurementDeviceUnitGroups] as mug ON mdu.[MeasurementDeviceUnitGroupId] = mug.[MeasurementDevicesUnitGroupSourceId]
		) AS source
		ON dest.[MeasurementDeviceUnitSourceId] = source.[MeasurementDeviceUnitSourceId]
	WHEN MATCHED AND 
		(
			 dest.[ShortNameEn] <> source.[ShortNameEn]
			OR dest.[ShortNameEnAsc] <> source.[ShortNameEnAsc]
			OR dest.[LongNameEn] <> source.[LongNameEn]
			OR dest.[ShortNameHeAsc] <> source.[ShortNameHeAsc]
			OR dest.[ShortNameHe] <> source.[ShortNameHe]
			OR dest.[LongNameHe] <> source.[LongNameHe]
			OR dest.[MeasurementDeviceUnitGroupId] <> source.[MeasurementDeviceUnitGroupId]
			OR dest.[Note] <> source.[Note]
		)
		THEN
			UPDATE
			SET  dest.[ShortNameEn] = source.[ShortNameEn]
				,dest.[ShortNameEnAsc] = source.[ShortNameEnAsc]
				,dest.[LongNameEn] = source.[LongNameEn]
				,dest.[ShortNameHeAsc] = source.[ShortNameHeAsc]
				,dest.[ShortNameHe] = source.[ShortNameHe]
				,dest.[LongNameHe] = source.[LongNameHe]
				,dest.[MeasurementDeviceUnitGroupId] = source.[MeasurementDeviceUnitGroupId]
				,dest.[Note] = source.[Note]
				,dest.[UpdatedDate] = source.[UpdatedDate]
				,dest.[UpdateUserID] = source.[UpdateUserID]
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				[ShortNameEn]
				,[ShortNameEnAsc]
				,[LongNameEn]
				,[ShortNameHeAsc]
				,[ShortNameHe]
				,[LongNameHe]
				,[MeasurementDeviceUnitGroupId]
				,[Note]
				,[MeasurementDeviceUnitSourceId]
				,[UpdateUserID]
				)
			VALUES (
				 source.[ShortNameEn]
				,source.[ShortNameEnAsc]
				,source.[LongNameEn]
				,source.[ShortNameHeAsc]
				,source.[ShortNameHe]
				,source.[LongNameHe]
				,source.[MeasurementDeviceUnitGroupId]
				,source.[Note]
				,source.[MeasurementDeviceUnitSourceId]
				,source.[UpdateUserID]
				);
END