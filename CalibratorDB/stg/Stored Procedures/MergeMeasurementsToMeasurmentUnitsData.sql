-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 12/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE PROCEDURE [stg].[MergeMeasurementsToMeasurmentUnitsData]
AS
BEGIN

SET NOCOUNT ON;

	MERGE INTO [dbo].[MeasurementsToMeasurmentUnits] AS dest
	USING (
		SELECT 
			 m.ID as [MeasurementId]
			,mdu.[MeasurementDeviceUnitId]
			,mmu.[IsDefaultUnit]
			,mmu.SourceId
			,GETDATE() as [UpdatedDate]
			,0 as [UpdateUserID]
		FROM [stg].[stg_MeasurementsToMeasurmentUnits] as mmu
		JOIN [dbo].[Measurements] as m ON mmu.MeasurementSourceId = m.MeasurementIdFromSource
		JOIN [dbo].[MeasurementDeviceUnits] as mdu ON mmu.UnitSourceId = mdu.MeasurementDeviceUnitSourceId
		) AS source
		ON dest.SourceId = source.SourceId
	WHEN MATCHED AND 
		(
		   dest.[MeasurementId] <> source.[MeasurementId]
		OR dest.[MeasurementDeviceUnitId] <> source.[MeasurementDeviceUnitId]
		OR dest.[IsDefaultUnit] <> source.[IsDefaultUnit]
		)
		THEN
			UPDATE
			SET  dest.[MeasurementId] = source.[MeasurementId]
				,dest.[MeasurementDeviceUnitId] = source.[MeasurementDeviceUnitId]
				,dest.[IsDefaultUnit] = source.[IsDefaultUnit]
				,dest.[UpdatedDate] = source.[UpdatedDate]
				,dest.[UpdateUserID] = source.[UpdateUserID]
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [MeasurementId]
				,[MeasurementDeviceUnitId]
				,[IsDefaultUnit]
				,[UpdateUserID]
				,[SourceId]
				)
			VALUES (
				source.[MeasurementId]
				,source.[MeasurementDeviceUnitId]
				,source.[IsDefaultUnit]
				,source.[UpdateUserID]
				,source.[SourceId]
				)
	WHEN NOT MATCHED BY SOURCE
		THEN
			UPDATE SET
			 dest.[UpdatedDate] = GETDATE()
			,dest.[UpdateUserID] = 0
			,dest.[IsDeleted] = 1;
END