-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 11/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE PROCEDURE stg.MergeMeasurementDevicesManufacturersData
AS
BEGIN

	SET NOCOUNT ON;

	MERGE INTO [dbo].[MeasurementDevicesManufacturers] AS dest
	USING (
		SELECT 
			 [Name]
			,[Description]
			,[MeasurementDevicesManufacturerSourceId]
			,GETDATE() as [UpdatedDate]
			,0 as [UpdateUserID]
		FROM stg.[stg_MeasurementDevicesManufacturers]
		) AS source
		ON dest.[MeasurementDevicesManufacturerSourceId] = source.[MeasurementDevicesManufacturerSourceId]
	WHEN MATCHED AND
		(
		dest.[Name] <> source.[Name]
		OR COALESCE(dest.[Description],'') <> COALESCE(source.[Description],'')
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
				,[MeasurementDevicesManufacturerSourceId]
				,[UpdateUserID]
				)
			VALUES (
				 source.[Name]
				,source.[Description]
				,source.[MeasurementDevicesManufacturerSourceId]
				,source.[UpdateUserID]
				);
END