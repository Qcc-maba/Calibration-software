/*
    dbo.GetCalibrationCycles                                                            MBA-623
    ---------------------------------------------------------------------------------------------
    The calibration cycles of one device (order line item), oldest first, or only the latest.

    MBA-623: the app used to recover a cycle's reference documents by searching this procedure's
    comma-joined names for each document's name - which broke on any rename, and on names that
    themselves contain a comma ("ASTM D1238, ISO 1133"). It now gets the ids
    (SpecificationReferenceIds) and resolves them itself. The names are still returned, in the
    order the documents were chosen and joined with ' + ' as the report prints them, Hebrew in
    SpecificationReferences and English in SpecificationReferencesEn, for documents the picker no
    longer offers (soft-deleted ones are not in dbo.GetAllSpecificationReferences).
*/
CREATE OR ALTER PROCEDURE [dbo].[GetCalibrationCycles]
@OrderDetailsItemId INT,
@ShowOnlyLatest BIT = 0
/*
EXEC [dbo].[GetCalibrationCycles]
@OrderDetailsItemId = 3077,
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
	,cc.[UnitId]
	,mu.[LongNameHe] as UnitName
	,cc.[TestedValue]
	,cc.[SpecificationReferenceIds]
	,sr.[SpecificationReferences]
	,sr.[SpecificationReferencesEn]
	,cc.[CalibrationCycleNameStatusId]
	,ROW_NUMBER() OVER( PARTITION BY cc.[OrderDetailsItemId] ORDER BY [CalibrationCycleStartDate]) as CycleNumber
	,ROW_NUMBER() OVER( PARTITION BY cc.[OrderDetailsItemId] ORDER BY [CalibrationCycleStartDate] DESC) as LatestCycle
FROM [dbo].[CalibrationCycles] as cc
LEFT JOIN [dbo].[MeasurementDeviceUnits] as mu ON cc.[UnitId] = mu.MeasurementDeviceUnitId
OUTER APPLY
(
SELECT STRING_AGG(r.[Name], ' + ') WITHIN GROUP (ORDER BY s.[ordinal]) as SpecificationReferences
      ,STRING_AGG(COALESCE(r.[NameEn], r.[Name]), ' + ') WITHIN GROUP (ORDER BY s.[ordinal]) as SpecificationReferencesEn
FROM STRING_SPLIT(cc.SpecificationReferenceIds, ',', 1) as s
JOIN [dbo].[SpecificationReference] as r ON r.[ID] = TRY_CAST(s.[value] AS INT)
) as sr
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
	,ds.[UnitId]
	,ds.[UnitName]
	,ds.[TestedValue]
	,ds.[SpecificationReferenceIds]
	,ds.[SpecificationReferences]
	,ds.[SpecificationReferencesEn]
	,ds.[CalibrationCycleNameStatusId]
FROM ds
JOIN [dbo].[OrderDetailsItems] as oi ON ds.[OrderDetailsItemId] = oi.[OrderDetailsItemId]
WHERE (@ShowOnlyLatest = 0 OR ds.LatestCycle = 1)
ORDER BY ds.[CycleNumber] ASC  -- Bug #2 fix: ensure cycles are always returned in creation order

END
GO
