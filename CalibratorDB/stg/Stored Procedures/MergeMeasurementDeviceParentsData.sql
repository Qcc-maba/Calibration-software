-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 12/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE PROCEDURE [stg].[MergeMeasurementDeviceParentsData]
AS
BEGIN

SET NOCOUNT ON;

UPDATE pd
SET UpdatedDate = GETDATE(),
	UpdateUserID = 0,
	IsDeleted = 0
FROM [stg].[stg_MeasurementDeviceParents] as mdp
LEFT JOIN  [dbo].[MeasurementDeviceParents] as pd ON mdp.[ID] = pd.[MeasurementDeviceParentsSourceId]
WHERE mdp.[ID] IS NULL

	MERGE INTO [dbo].[MeasurementDeviceParents] AS dest
	USING (
		SELECT 
		     dev.ID as [MeasurementDeviceId]
			,par.ID as [MeasurementDeviceParentId]
			,mdp.ID as [MeasurementDeviceParentsSourceId]
			,GETDATE() as [UpdatedDate]
			,0 as [UpdateUserID]
		FROM [stg].[stg_MeasurementDeviceParents] as mdp
		JOIN [dbo].[MeasurementDevices] as dev ON mdp.Instrument = dev.MeasurementDeviceSourceId	
		JOIN [dbo].[MeasurementDevices] as par ON mdp.Parent = par.MeasurementDeviceSourceId
		) AS source
		ON dest.[MeasurementDeviceParentsSourceId] = source.[MeasurementDeviceParentsSourceId]
	WHEN MATCHED AND
	(
		   dest.[MeasurementDeviceId] <> source.[MeasurementDeviceId]
		OR dest.[MeasurementDeviceParentId] <> source.[MeasurementDeviceParentId]
	)
		THEN
			UPDATE
			SET  dest.[MeasurementDeviceId] = source.[MeasurementDeviceId]
				,dest.[MeasurementDeviceParentId] = source.[MeasurementDeviceParentId]
				,dest.[UpdatedDate] = source.[UpdatedDate]
				,dest.[UpdateUserID] = source.[UpdateUserID]
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [MeasurementDeviceId]
				,[MeasurementDeviceParentId]
				,[MeasurementDeviceParentsSourceId]
				,[UpdateUserID]
				)
			VALUES (
				 source.[MeasurementDeviceId]
				,source.[MeasurementDeviceParentId]
				,source.[MeasurementDeviceParentsSourceId]
				,source.[UpdateUserID]
				);


END