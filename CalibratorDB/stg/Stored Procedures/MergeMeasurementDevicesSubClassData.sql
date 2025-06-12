-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 11/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE stg.MergeMeasurementDevicesSubClassData
AS
BEGIN

SET NOCOUNT ON;

	MERGE INTO [dbo].[MeasurementDevicesSubClass] AS dest
	USING (
		SELECT 
			 ss.[Name]
			,ss.[Description]
			,GETDATE() as [UpdatedDate]
			,0 as [UpdateUserID]
			,ss.[MeasurementDevicesSubClassSourceId]
		FROM [stg].[stg_MeasurementDevicesSubClass] as ss
		) AS source
		ON dest.[MeasurementDevicesSubClassSourceId] = source.[MeasurementDevicesSubClassSourceId]
	WHEN MATCHED AND
		(
		dest.[Name] = source.[Name]
		OR dest.[Description] = source.[Description]
		)
		THEN
			UPDATE
			SET  dest.[Name] = source.[Name]
				,dest.[Description] = source.[Description]
				,dest.[UpdatedDate] = source.[UpdatedDate]
				,dest.[UpdateUserID] = source.[UpdateUserID]
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [Name]
				,[Description]
				,[UpdateUserID]
				,[MeasurementDevicesSubClassSourceId]
				)
			VALUES (
				 source.[Name]
				,source.[Description]
				,source.[UpdateUserID]
				,source.[MeasurementDevicesSubClassSourceId]
				);
END