

CREATE    PROCEDURE [dbo].[GetAllMeasurementUnits]
@MainCategoryId INT = NULL
AS
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/06/2025
-- Description:	
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-44
-- =============================================

SELECT 
/*u.MeasurementDeviceUnitGroupId
,*/MeasurementDeviceUnitId
,u.ShortNameHe as UnitShortName	
,u.LongNameHe as UnitLongName
FROM [dbo].[MeasurementDeviceUnits] as u
WHERE (@MainCategoryId IS NULL OR u.MainCategoryId = @MainCategoryId)
AND u.IsDeleted = 0