-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 12/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [stg].[MergeMeasurementDevicesData]
AS
BEGIN

SET NOCOUNT ON;

	
	MERGE INTO [dbo].[MeasurementDevices] AS dest
	USING (
		SELECT 
			 md.[MabaID]
			,md.[Description]
			,mdm.ID as [ManufacturerId]
			,md.[Model]
			,md.[SerialNumber]
			,md.[NextCalibration]
			,md.[Note]
			,md.[CalibrationDate]
			,m.[ID] as [MeasurementId]
			,mcm.Id as [MainClassId]
			,mds.ID as [SubClassId]
			,md.[ExtraCalTools]
			,d.[ID] as [MainCategoryId]
			,mdu1.[MeasurementDeviceUnitId] as [UnitId]
			,u.[ID] as [CalibratorId]
			,md.[ReportNumber]
			,mdu2.[MeasurementDeviceUnitId] as [WorkRangeUnitId]
			,md.[WorkRangeMin]
			,md.[WorkRangeMax]
			,md.[DefaultPrecision]
			,md.[HighestPrecision]
			,md.[CreateDate]
			,md.[RemoveDate]
			,GETDATE() as [UpdateDate]
			,0 as [UpdateUserID]
			,md.[AllowMinOOR]
			,md.[AllowMaxOOR]
			,IIF(md.[RemoveDate] IS NULL,0,1) as [IsDeleted]
			,md.[MeasurementDeviceSourceId]
		FROM [stg].[stg_MeasurementDevices] as md
		LEFT JOIN [dbo].[MeasurementDevicesManufacturers] as mdm ON md.ManufacturerId = mdm.MeasurementDevicesManufacturerSourceId
		LEFT JOIN [dbo].[Measurements] as m ON md.[MeasurementId] = m.[MeasurementIdFromSource]
		LEFT JOIN [dbo].[MeasurementDevicesMainClasses] as mcm ON md.[MainClassId] = mcm.[MeasurementDevicesMainClassSourceId]
		LEFT JOIN [dbo].[MeasurementDevicesSubClass] as mds ON md.[SubClassId] = mds.[MeasurementDevicesSubClassSourceId]
		LEFT JOIN [dbo].[MainCategories] as d ON md.[Department] = d.[MainCategoryName]
		LEFT JOIN [dbo].[MeasurementDeviceUnits] mdu1 ON md.[UnitId] = mdu1.[MeasurementDeviceUnitSourceId]
		LEFT JOIN [dbo].[MeasurementDeviceUnits] mdu2 ON md.[WorkRangeUnitId] = mdu2.[MeasurementDeviceUnitSourceId]
		LEFT JOIN [dbo].[Users] as u ON md.[CalibratorId] = u.[UserSourceId]
		) AS source
		ON dest.[MeasurementDeviceSourceId] = source.[MeasurementDeviceSourceId]
	WHEN MATCHED AND 
		(
				   dest.[MabaID] <> source.[MabaID]
				OR dest.[Description] <> source.[Description]
				OR dest.[ManufacturerId] <> source.[ManufacturerId]
				OR dest.[Model] <> source.[Model]
				OR dest.[SerialNumber] <> source.[SerialNumber]
				OR dest.[NextCalibration] <> source.[NextCalibration]
				OR dest.[Note] <> source.[Note]
				OR dest.[CalibrationDate] <> source.[CalibrationDate]
				OR dest.[MeasurementId] <> source.[MeasurementId]
				OR dest.[MainClassId] <> source.[MainClassId]
				OR dest.[SubClassId] <> source.[SubClassId]
				OR dest.[ExtraCalTools] <> source.[ExtraCalTools]
				OR dest.[MainCategoryId] <> source.[MainCategoryId]
				OR dest.[UnitId] <> source.[UnitId]
				OR dest.[CalibratorId] <> source.[CalibratorId]
				OR dest.[ReportNumber] <> source.[ReportNumber]
				OR dest.[WorkRangeUnitId] <> source.[WorkRangeUnitId]
				OR dest.[WorkRangeMin] <> source.[WorkRangeMin]
				OR dest.[WorkRangeMax] <> source.[WorkRangeMax]
				OR dest.[DefaultPrecision] <> source.[DefaultPrecision]
				OR dest.[HighestPrecision] <> source.[HighestPrecision]
				OR dest.[CreateDate] <> source.[CreateDate]
				OR dest.[RemoveDate] <> source.[RemoveDate]
				OR dest.[UpdateDate] <> source.[UpdateDate]
				OR dest.[UpdateUserID] <> source.[UpdateUserID]
				OR dest.[AllowMinOOR] <> source.[AllowMinOOR]
				OR dest.[AllowMaxOOR] <> source.[AllowMaxOOR]
				OR dest.[IsDeleted] <> source.[IsDeleted]
		)
		THEN
			UPDATE
			SET  dest.[MabaID] = source.[MabaID]
				,dest.[Description] = source.[Description]
				,dest.[ManufacturerId] = source.[ManufacturerId]
				,dest.[Model] = source.[Model]
				,dest.[SerialNumber] = source.[SerialNumber]
				,dest.[NextCalibration] = source.[NextCalibration]
				,dest.[Note] = source.[Note]
				,dest.[CalibrationDate] = source.[CalibrationDate]
				,dest.[MeasurementId] = source.[MeasurementId]
				,dest.[MainClassId] = source.[MainClassId]
				,dest.[SubClassId] = source.[SubClassId]
				,dest.[ExtraCalTools] = source.[ExtraCalTools]
				,dest.[MainCategoryId] = source.[MainCategoryId]
				,dest.[UnitId] = source.[UnitId]
				,dest.[CalibratorId] = source.[CalibratorId]
				,dest.[ReportNumber] = source.[ReportNumber]
				,dest.[WorkRangeUnitId] = source.[WorkRangeUnitId]
				,dest.[WorkRangeMin] = source.[WorkRangeMin]
				,dest.[WorkRangeMax] = source.[WorkRangeMax]
				,dest.[DefaultPrecision] = source.[DefaultPrecision]
				,dest.[HighestPrecision] = source.[HighestPrecision]
				,dest.[CreateDate] = source.[CreateDate]
				,dest.[RemoveDate] = source.[RemoveDate]
				,dest.[UpdateDate] = source.[UpdateDate]
				,dest.[UpdateUserID] = source.[UpdateUserID]
				,dest.[AllowMinOOR] = source.[AllowMinOOR]
				,dest.[AllowMaxOOR] = source.[AllowMaxOOR]
				,dest.[IsDeleted] = source.[IsDeleted]
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [MabaID]
				,[Description]
				,[ManufacturerId]
				,[Model]
				,[SerialNumber]
				,[NextCalibration]
				,[Note]
				,[CalibrationDate]
				,[MeasurementId]
				,[MainClassId]
				,[SubClassId]
				,[ExtraCalTools]
				,[MainCategoryId]
				,[UnitId]
				,[CalibratorId]
				,[ReportNumber]
				,[WorkRangeUnitId]
				,[WorkRangeMin]
				,[WorkRangeMax]
				,[DefaultPrecision]
				,[HighestPrecision]
				,[CreateDate]
				,[RemoveDate]
				,[UpdateUserID]
				,[AllowMinOOR]
				,[AllowMaxOOR]
				,[IsDeleted]
				,[MeasurementDeviceSourceId]
				)
			VALUES (
				 source.[MabaID]
				,source.[Description]
				,source.[ManufacturerId]
				,source.[Model]
				,source.[SerialNumber]
				,source.[NextCalibration]
				,source.[Note]
				,source.[CalibrationDate]
				,source.[MeasurementId]
				,source.[MainClassId]
				,source.[SubClassId]
				,source.[ExtraCalTools]
				,source.[MainCategoryId]
				,source.[UnitId]
				,source.[CalibratorId]
				,source.[ReportNumber]
				,source.[WorkRangeUnitId]
				,source.[WorkRangeMin]
				,source.[WorkRangeMax]
				,source.[DefaultPrecision]
				,source.[HighestPrecision]
				,COALESCE(source.[CreateDate],GETDATE())
				,source.[RemoveDate]
				,source.[UpdateUserID]
				,source.[AllowMinOOR]
				,source.[AllowMaxOOR]
				,source.[IsDeleted]
				,source.[MeasurementDeviceSourceId]
				);

	IF (SELECT COUNT(*) FROM [stg].[stg_DataLoggerIP] ) > 0

	UPDATE md
		SET md.[IP] = dip.[IP],
		    md.[UpdateUserID] = 0,
		    md.UpdateDate = GETDATE()
	FROM [dbo].[MeasurementDevices] as md
	JOIN [stg].[stg_DataLoggerIP] as dip ON md.MabaID = dip.MABAId
	WHERE COALESCE(md.[IP],'') <> COALESCE(dip.[IP],'')
END