CREATE   PROCEDURE [dbo].[GetAllCalibrationDevices]
@MeasurementDevicesMainClassId INT = NULL,
@CalibrationDeviceId INT = NULL,
@ApplyFilterByDevicesParents BIT = 0
AS
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 28/05/2025
-- Description:	
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-43
-- =============================================
BEGIN

IF @ApplyFilterByDevicesParents = 1 AND @CalibrationDeviceId IS NULL
THROW 51000, 'Provide @CalibrationDeviceId to get child devices.', 1;

	DECLARE @sql NVARCHAR(MAX) =
	CONCAT(
	'
	SELECT md.[ID]
		  ,md.[MabaID]
		  ,md.[Model]
		  ,md.[SerialNumber]
		  ,md.[CalibrationDate] AS [LastCalibrationDate]
		  ,md.[NextCalibration]
		  ,NULL AS [CommunicationType] 
		  ,NULL AS [CommunicationDetails]
		  ,NULL AS [Rate]
		  ,NULL AS [Intervals] 
		  ,NULL AS [Status]
		  ,mc.NameHebrew
		  ,mc.NameEnglish
		  ,u.ShortNameHe AS UnitName
		  ,md.WorkRangeMin	as LowerDomainBorder
		  ,md.WorkRangeMax as UpperDomainBorder 
		  ,m.NameHe as MeasurmentName
		  ,d.DepartmentName
		  ,COALESCE(md.[IP],''0.0.0.0:0000'') as [IP]
		  ,COALESCE(md.Resolution,60) as Resolution
		  ,CASE WHEN mc.NameEnglish = ''Sensor'' THEN 60 ELSE 30 END as ChannelsNumber
		  ,CASE WHEN mc.NameEnglish = ''Sensor'' AND Description LIKE ''%TC-K%'' THEN ''2W''
				WHEN mc.NameEnglish = ''Sensor'' THEN ''4W'' 
			ELSE NULL END as Connection
		  ,md.MeasurementId	
		  ,md.MainClassId	
		  ,md.SubClassId
	  FROM [dbo].[MeasurementDevices] as md
	  '
	  ,CASE WHEN @ApplyFilterByDevicesParents = 1 THEN ' JOIN [dbo].[MeasurementDeviceParents] as pf ON md.[ID] = pf.[MeasurementDeviceId] AND pf.[MeasurementDeviceParentId] ='+CAST(@CalibrationDeviceId as NVARCHAR(50))+'' ELSE ' ' END
	  ,'
	  JOIN [dbo].[MeasurementDevicesMainClasses] as mc ON md.MainClassId = mc.Id
	  LEFT JOIN [dbo].[MeasurementDeviceUnits] as u ON md.UnitId = u.MeasurementDeviceUnitId
	  LEFT JOIN [dbo].[Measurements] as m ON md.MeasurementId = m.ID
	  LEFT JOIN [dbo].[Departments] as d ON md.DepartmentId = d.ID
	  WHERE md.RemoveDate IS NULL AND md.IsDeleted = 0
	  '
	  ,CASE WHEN @MeasurementDevicesMainClassId IS NOT NULL AND @ApplyFilterByDevicesParents = 0 THEN' AND md.MainClassId = '+ +CAST(@MeasurementDevicesMainClassId as NVARCHAR(50))+' 'ELSE ' ' END
	  ,CASE WHEN @CalibrationDeviceId IS NOT NULL AND @ApplyFilterByDevicesParents = 0 THEN' AND md.[ID] = '+ +CAST(@CalibrationDeviceId as NVARCHAR(50))+' 'ELSE ' ' END 
	  )

	PRINT @sql
	EXEC sp_executesql @sql

END