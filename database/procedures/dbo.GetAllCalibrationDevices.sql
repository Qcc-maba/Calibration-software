/*
    dbo.GetAllCalibrationDevices
    ---------------------------------------------------------------------------------------------
    Original author: Eduard Kudlaiev, 28/05/2025 (MABA-43)
    Backs the logger and sensor pickers in the calibration wizard, and the logger-connection popup.

    2026-08-24 (MBA-902): three fixes, all visible in that popup.

    1. מס' נקודות always showed 0. ChannelsNumber was sourced from md.Channels, which is NULL on
       every one of the loggers - Channels is populated on 152 rows and all of them are sensors.
       The logger's channel count lives in md.ConnectionPoints (21-142 = 21, 31-80 = 61,
       21-702 = 82), which no procedure returned. Now COALESCE(ConnectionPoints, Channels), so
       loggers report their real count and nothing that relied on Channels loses it.

    2. No ORDER BY at all, so the picker listed devices in whatever order the join produced and the
       order changed between calls. Sorted on MabaID's two numeric segments rather than as text,
       so 21-17 precedes 21-131; a plain text sort puts 21-131 first because '1' sorts before '7'.

    3. Classifying the previously unclassified devices took the logger class from 35 rows to 454,
       and the picker filled up with registry entries the system cannot actually talk to - a
       calibrator selecting 30-1100 would be selecting a device with no connection at all. A logger
       is now offered only if its Connection mentions USB, LAN or IP.

       That rule is not new: the WHERE clause already carried it, commented out, as
       "AND md.Connection IS NOT NULL AND md.Connection <> N'אוגר אלחוטי'". This turns the same
       intent back on.

       The test is "has a connection at all", not "USB or LAN". Of the 35 loggers that carry a
       connection value, 26 are USB / LAN / IP and 9 are plain RS-232 - and those 9 are real
       working loggers, the ones showing 1 and 2 connection points. Filtering on USB/LAN alone
       would silently drop them. Wireless loggers stay excluded, as the original comment intended.

       Pass @ConnectableLoggersOnly = 0 to get the unfiltered list, including the 396 registry
       entries that have no connection value at all.

    The filter applies to loggers only. Sensors carry connection values like 2W and 4W, which
    describe wiring rather than a link to this system, and must not be filtered by it.
*/
CREATE OR ALTER PROCEDURE [dbo].[GetAllCalibrationDevices]
@MeasurementDevicesMainClassId INT = NULL,
@CalibrationDeviceId INT = NULL,
@ApplyFilterByDevicesParents BIT = 0,
@ConnectableLoggersOnly BIT = 1
AS
BEGIN

	DECLARE @DataLoggerClassId INT = 7;

	DECLARE @sql NVARCHAR(MAX) =
	CONCAT(
	'
	SELECT md.[ID]
		  ,md.[MabaID]
		  ,md.[Model]
		  ,md.[SerialNumber]
		  ,md.[CalibrationDate] AS [LastCalibrationDate]
		  ,md.[NextCalibration]
		  ,NULL AS [Status]
		  ,mc.NameHebrew
		  ,mc.NameEnglish
		  ,md.UnitId
		  ,u.ShortNameHe AS UnitName
		  ,md.WorkRangeUnitId
		  ,u2.ShortNameHe as WorkRangeUnitName
		  ,md.WorkRangeMin	as LowerDomainBorder
		  ,md.WorkRangeMax as UpperDomainBorder 
		  /* MBA-902: the second range, for sensors that measure temperature and humidity at once */
		  ,md.WorkRangeMin2 as LowerDomainBorder2
		  ,md.WorkRangeMax2 as UpperDomainBorder2
		  ,u3.ShortNameHe as WorkRangeUnitName2
		  ,m.NameHe as MeasurmentName
		  ,d.[MainCategoryName] as DepartmentName
		  ,md.[IP]
		  ,COALESCE(md.Resolution,60) as Resolution
		  /* MBA-902: a logger''s channel count is ConnectionPoints; Channels is a sensor column */
		  ,COALESCE(md.ConnectionPoints, md.Channels) as ChannelsNumber
		  ,md.ConnectionPoints
		  ,md.Connection
		  ,md.MeasurementId	
		  ,md.MainClassId	
		  ,md.SubClassId
		  ,u.MeasurementDeviceUnitGroupId
	  FROM [dbo].[MeasurementDevices] as md
	  JOIN [dbo].[MeasurementDevicesMainClasses] as mc ON md.MainClassId = mc.Id
	  LEFT JOIN [dbo].[MeasurementDeviceUnits] as u ON md.UnitId = u.MeasurementDeviceUnitId
	  LEFT JOIN [dbo].[MeasurementDeviceUnits] as u2 ON md.WorkRangeUnitId = u2.MeasurementDeviceUnitId
	  LEFT JOIN [dbo].[MeasurementDeviceUnits] as u3 ON md.WorkRangeUnitId2 = u3.MeasurementDeviceUnitId
	  LEFT JOIN [dbo].[Measurements] as m ON md.MeasurementId = m.ID
	  LEFT JOIN [dbo].[MainCategories] as d ON md.MainCategoryId = d.ID
	  WHERE md.RemoveDate IS NULL AND md.IsDeleted = 0
	  '
	  ,CASE WHEN @MeasurementDevicesMainClassId IS NOT NULL THEN' AND md.MainClassId = '+CAST(@MeasurementDevicesMainClassId as NVARCHAR(50))+' ' ELSE ' ' END
	  ,CASE WHEN @CalibrationDeviceId IS NOT NULL THEN' AND md.[ID] = '+CAST(@CalibrationDeviceId as NVARCHAR(50))+' ' ELSE ' ' END
	  /* MBA-902: only loggers this system can actually connect to. Never applied to sensors. */
	  ,CASE WHEN @ConnectableLoggersOnly = 1 AND @CalibrationDeviceId IS NULL
	         THEN ' AND (md.MainClassId <> '+CAST(@DataLoggerClassId as NVARCHAR(50))+
	              ' OR (md.Connection IS NOT NULL AND LEN(LTRIM(RTRIM(md.Connection))) > 0'+
	              '     AND md.Connection <> N''אוגר אלחוטי'')) '
	         ELSE ' ' END
	  /* MBA-902: numeric order on MabaID; anything not shaped nn-nnn sorts last */
	  ,'
	  ORDER BY IIF(TRY_CAST(LEFT(md.MabaID, CHARINDEX(''-'', md.MabaID + ''-'') - 1) AS INT) IS NULL, 1, 0),
	           TRY_CAST(LEFT(md.MabaID, CHARINDEX(''-'', md.MabaID + ''-'') - 1) AS INT),
	           TRY_CAST(LEFT(STUFF(md.MabaID, 1, CHARINDEX(''-'', md.MabaID + ''-''), ''''),
	                         CHARINDEX(''/'', STUFF(md.MabaID, 1, CHARINDEX(''-'', md.MabaID + ''-''), '''') + ''/'') - 1) AS INT),
	           md.MabaID
	  '
	  )

	EXEC sp_executesql @sql

END
