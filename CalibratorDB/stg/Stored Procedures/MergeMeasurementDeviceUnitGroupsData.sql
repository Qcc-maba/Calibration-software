-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 10/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [stg].[MergeMeasurementDeviceUnitGroupsData]
AS
BEGIN

SET NOCOUNT ON;

	MERGE INTO [dbo].[MeasurementDeviceUnitGroups] AS dest
	USING (
		SELECT
			ug.[NameEn],
			ug.[NameHe],
			ug.[Description],
			ug.[Symbol],
			ug.[HelpLink],
			ug.[MeasurementDevicesUnitGroupSourceId],
			GETDATE() as [UpdatedDate],
			0 as [UpdateUserID]
		FROM [stg].[stg_MeasurementDeviceUnitGroups] as ug
		) AS source
		ON dest.[MeasurementDevicesUnitGroupSourceId] = source.[MeasurementDevicesUnitGroupSourceId]
	WHEN MATCHED AND
			 (dest.[NameEn] <> source.[NameEn]
			 OR dest.[NameHe] <> source.[NameHe]
			 OR dest.[Description] <> source.[Description]
			 OR dest.[Symbol] <> source.[Symbol]
			 OR dest.[HelpLink] <> source.[HelpLink])
		THEN
			UPDATE
			SET  dest.[NameEn] = source.[NameEn]
				,dest.[NameHe] = source.[NameHe]
				,dest.[Description] = source.[Description]
				,dest.[Symbol] = source.[Symbol]
				,dest.[HelpLink] = source.[HelpLink]
				,dest.[UpdatedDate] = source.[UpdatedDate]
				,dest.[UpdateUserID] = source.[UpdateUserID]

	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [NameEn]
				,[NameHe]
				,[Description]
				,[Symbol]
				,[HelpLink]
				,[UpdateUserID]
				,[MeasurementDevicesUnitGroupSourceId]
				)
			VALUES (
				 source.[NameEn]
				,source.[NameHe]
				,source.[Description]
				,source.[Symbol]
				,source.[HelpLink]
				,source.[UpdateUserID]
				,source.[MeasurementDevicesUnitGroupSourceId]
				);
END