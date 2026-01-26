-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 23/01/2026
-- Description:	Get information about calibration cycles 
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-565
-- =============================================
CREATE   PROCEDURE [dbo].[GetCalibrationCycles]
@OrderDetailsItemId INT,
@ShowOnlyLatest BIT = 0 
/*
EXEC [dbo].[GetCalibrationCycles]
@OrderDetailsItemId = 1300,
@ShowOnlyLatest = 1
*/
AS
BEGIN
SET NOCOUNT ON;

WITH ds
AS
(
SELECT
	 cc.[OrderDetailsItemId]
	,cc.[CalibrationCycleStartDate]
	,cc.[CalibrationCycleEndDate]
	,cc.[CalibrationCycleStatusId]
	,cc.[CreatedUserID]
	,cc.[CalibrationCycleName]
	,ROW_NUMBER() OVER( PARTITION BY cc.[OrderDetailsItemId] ORDER BY [CalibrationCycleStartDate]) as CycleNumber
	,ROW_NUMBER() OVER( PARTITION BY cc.[OrderDetailsItemId] ORDER BY [CalibrationCycleStartDate] DESC) as LatestCycle
FROM [dbo].[CalibrationCycles] as cc
WHERE cc.[OrderDetailsItemId] = @OrderDetailsItemId AND cc.IsDeleted = 0
)
SELECT 
	 ds.[OrderDetailsItemId]
	,ds.[CalibrationCycleStartDate]
	,ds.[CalibrationCycleEndDate]
	,ds.[CalibrationCycleStatusId]
	,ds.[CreatedUserID]
	,ds.[CycleNumber]
	,ds.[CalibrationCycleName]
	,oi.CalibrationSpecificationId 
	,ms.Name as CalibrationSpecification
	,oi.MeasurementUnitId
	,mdu.ShortNameHe
FROM ds
JOIN [dbo].[OrderDetailsItems] as oi ON ds.[OrderDetailsItemId] = oi.[OrderDetailsItemId] 
LEFT JOIN [dbo].[MeasurementsSpecifications] as ms ON oi.CalibrationSpecificationId = ms.ID AND ms.IsDeleted = 0
LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu ON oi.MeasurementUnitId = mdu.MeasurementDeviceUnitId AND mdu.IsDeleted = 0
WHERE (@ShowOnlyLatest = 0 OR ds.LatestCycle = 1)


END