
CREATE    PROCEDURE [dbo].[GetAllMeasurementUnits]
@MeasurementDeviceUnitGroupId INT = NULL
AS
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/06/2025
-- Description:	
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-44
-- =============================================

SELECT 
u.MeasurementDeviceUnitGroupId
,MeasurementDeviceUnitId
,u.ShortNameHe as UnitShortName	
,u.LongNameHe as UnitLongName
,ug.NameHe as UnitGroupName
,ug.Symbol
FROM [dbo].[MeasurementDeviceUnits] as u
JOIN [dbo].[MeasurementDeviceUnitGroups] as ug ON u.MeasurementDeviceUnitGroupId = ug.MeasurementDeviceUnitGroupId
WHERE @MeasurementDeviceUnitGroupId IS NULL OR u.MeasurementDeviceUnitGroupId = @MeasurementDeviceUnitGroupId