-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 13/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE stg.MergeMeasurementDevicesCorrectionsData
AS
BEGIN

SET NOCOUNT ON;

	
	MERGE INTO [dbo].[MeasurementDevicesCorrections] AS dest
	USING (
		SELECT
			 c.[Value1]
			,c.[Value2]
			,c.[Note]
			,md.[ID] as[MeasurementDevicesId]
			,m.[ID] as [MeasurementId]
			,mu.MeasurementDeviceUnitId AS [UnitID]
			,c.[CorVersion]
			,d.[ID] as [DepartmentId]
			,c.[Equation]
			,GETDATE () as [UpdatedDate]
			,0 as [UpdateUserID]
			,c.[MeasurementDevicesCorrectionsSourceId]
		FROM [stg].[stg_MeasurementDevicesCorrections] as c
		LEFT JOIN [dbo].[Measurements] as m ON c.[MeasurementId] = m.MeasurementIdFromSource
		LEFT JOIN [dbo].[MeasurementDevices] as md ON c.[MeasurementDevicesId] = md.[MeasurementDeviceSourceId]
		LEFT JOIN [dbo].[MeasurementDeviceUnits] as mu ON c.[UnitID] = mu.MeasurementDeviceUnitSourceId
		LEFT JOIN [dbo].[Departments] as d ON c.[Department] = d.[DepartmentName]
		) AS source
		ON dest.[MeasurementDevicesCorrectionsSourceId] = source.[MeasurementDevicesCorrectionsSourceId]
	WHEN MATCHED AND
		(
			   dest.[Value1] <> source.[Value1]
			OR dest.[Value2] <> source.[Value2]
			OR dest.[Note] <> source.[Note]
			OR dest.[MeasurementDevicesId] <> source.[MeasurementDevicesId]
			OR dest.[MeasurementId] <> source.[MeasurementId]
			OR dest.[UnitID] <> source.[UnitID]
			OR dest.[CorVersion] <> source.[CorVersion]
			OR dest.[DepartmentId] <> source.[DepartmentId]
			OR dest.[Equation] <> source.[Equation]
		)
		THEN
			UPDATE
			SET  dest.[Value1] = source.[Value1]
				,dest.[Value2] = source.[Value2]
				,dest.[Note] = source.[Note]
				,dest.[MeasurementDevicesId] = source.[MeasurementDevicesId]
				,dest.[MeasurementId] = source.[MeasurementId]
				,dest.[UnitID] = source.[UnitID]
				,dest.[CorVersion] = source.[CorVersion]
				,dest.[DepartmentId] = source.[DepartmentId]
				,dest.[Equation] = source.[Equation]
				,dest.[UpdatedDate] = source.[UpdatedDate]
				,dest.[UpdateUserID] = source.[UpdateUserID]
			
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [Value1]
				,[Value2]
				,[Note]
				,[MeasurementDevicesId]
				,[MeasurementId]
				,[UnitID]
				,[CorVersion]
				,[DepartmentId]
				,[Equation]
				,[UpdateUserID]
				,[MeasurementDevicesCorrectionsSourceId]
				)
			VALUES (
				 source.[Value1]
				,source.[Value2]
				,source.[Note]
				,source.[MeasurementDevicesId]
				,source.[MeasurementId]
				,source.[UnitID]
				,source.[CorVersion]
				,source.[DepartmentId]
				,source.[Equation]
				,source.[UpdateUserID]
				,source.[MeasurementDevicesCorrectionsSourceId]
				);


END