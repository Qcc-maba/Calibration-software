/*
    dbo.GetCalibrationValuesForManyOrderDetailItems                                     MBA-811
    ---------------------------------------------------------------------------------------------
    Feeds the sensor calibration wizard.

    MasterValueAfterCorrection ("מד אב אחרי קיזוז") used to be the literal string '0_mocked_val',
    which is what was reaching the screen on STAGE as MOCKED_VAL_0. It now comes from
    dbo.fnMasterValueAfterCorrection - a port of CalcDeviationForTemperature from the Hydra/VCT C#,
    so the wizard and the logger cannot disagree.

    It returns NULL, and the screen a dash, in two cases that are both correct: the master has no
    certificate on file, or it is a temperature+humidity master, whose compensation is a 2D
    interpolation our range-shaped correction data cannot feed yet (see
    dbo.fnHumidityAfterCorrection).

    DriftFromLastCalibration was the same literal and is now a typed NULL. It is still
    unimplemented - working it out needs a decision about what "last calibration" means for a
    given device and measurement point - but a NULL is honest where a string was not.

    Checked on STAGE: master 31-77 reading 23.0 returns 23.001792, which is 23.0 minus the
    deviation interpolated between its points at 0.018 (-0.080) and 49.963 (+0.090005).
*/
-- =============================================
-- Proc:        dbo.GetCalibrationValuesForManyOrderDetailItems
-- Jira:        the calibration wizard's `sensors.getCalibrationValuesForManyOrderDetailItems`
--
-- WHY: the front-end deployed on 2026-08-13 calls a batch version of
-- dbo.GetCalibrationValuesForOrderDetailItem, but only the SINGULAR proc existed — on STAGE and on
-- PROD. Every call failed, which is the 400 that survived every other fix on stg.qcc.co.il.
--
-- This is the singular proc's query, unchanged, with three differences:
--   1. it takes a LIST of OrderDetailsItemIds instead of one (comma separated, the convention used
--      by @OrderWorkPlanIds / @EquipmentIds / @AssignedCalibratorsIds elsewhere in this database);
--   2. OrderDetailsItemId is RETURNED as the first column, so the caller can group the flat result
--      back per item — a batch endpoint is useless without it;
--   3. @OrderDetailIds is optional. The singular proc also filters on OrderDetailId, but that
--      column is not unique (OrderDetailId 58 exists on two different work plans), so the item id
--      is the only safe key. Pass the list only if you specifically want that extra restriction.
--
-- The per-item pairing of measurement points to environmental conditions is unchanged: both sides
-- are numbered with ROW_NUMBER() PARTITION BY OrderDetailsItemId and FULL OUTER JOINed on
-- (OrderDetailsItemId, rn), so batching cannot mix rows between items.
--
-- CONTRACT NOT CONFIRMED WITH THE FE. The parameter name and shape are inferred from this
-- database's conventions. If the router sends something else (a JSON array, a different name),
-- this still will not bind — tell me the exact signature and it is a one-line change.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCalibrationValuesForManyOrderDetailItems]
    @OrderDetailsItemIds NVARCHAR(MAX),
    @OrderDetailIds      NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @items TABLE(OrderDetailsItemId INT PRIMARY KEY);
    INSERT INTO @items(OrderDetailsItemId)
    SELECT DISTINCT TRY_CONVERT(INT, LTRIM(RTRIM(value)))
    FROM STRING_SPLIT(ISNULL(@OrderDetailsItemIds, N''), ',')
    WHERE LTRIM(RTRIM(value)) <> N''            -- TRY_CONVERT(INT, N'') returns 0, not NULL:
      AND TRY_CONVERT(INT, LTRIM(RTRIM(value))) IS NOT NULL;   -- without this an empty list becomes {0}

    DECLARE @details TABLE(OrderDetailId INT PRIMARY KEY);
    INSERT INTO @details(OrderDetailId)
    SELECT DISTINCT TRY_CONVERT(INT, LTRIM(RTRIM(value)))
    FROM STRING_SPLIT(ISNULL(@OrderDetailIds, N''), ',')
    WHERE LTRIM(RTRIM(value)) <> N''            -- TRY_CONVERT(INT, N'') returns 0, not NULL:
      AND TRY_CONVERT(INT, LTRIM(RTRIM(value))) IS NOT NULL;   -- without this an empty list becomes {0}

    SELECT
         itm.[OrderDetailsItemId]
        ,COALESCE(combined.[MbaReportNumber], itm.[MbaReportNumber]) as [MbaReportNumber]
        ,COALESCE(combined.[SerialNumber], itm.[SerialNumber]) as [SerialNumber]
        ,itm.[UnitUnderTestValue]
        ,itm.[MeasurementUnitId] as UUTId
        ,mdu4.[ShortNameHe] as UUTDescription
        ,N'P' + CAST(combined.[ChannelNumber] as NVARCHAR(30)) as [ChannelNumber]
        ,combined.[SensorMeasurementDeviceId]
        ,md.[MabaID] AS MasterSensorMabaID
        ,md.ID as [MeasurementDeviceId]
        ,combined.[Tolerance]
        ,combined.[NominalValue]
        ,wp.[OrderNumber]
        ,combined.[MasterValue]
        ,combined.[MasterValueUnitId]
        ,mdu.[ShortNameHe] as MasterValueUnitDescription
        /* CorrectedExact, not Corrected: rounding to the reading's own precision is what was
           asked for, but it erases the correction. A reading of 23 has deviation -0.001792,
           and at zero decimals the answer is 23 again. Both columns are available; this stays
           on the exact one until the display rule is settled. */
        ,mvc.CorrectedExact as [MasterValueAfterCorrection]
        ,combined.MeasuredValue
        ,combined.MeasuredValueUnitId
        ,mdu3.[ShortNameHe] as MeasuredUUTDescription
        ,combined.[AdditionalValue]
        ,combined.[AdditionalValueUnitId]
        ,mdu2.[ShortNameHe] as AdditionalUUTDescription
        ,combined.[MasterValue] - combined.[NominalValue] as [Deviation]
        ,((combined.[MasterValue] - combined.[NominalValue])/COALESCE(NULLIF(combined.[Tolerance],0),1))*100 as AllowedDeviation
        ,combined.[UncertancyValue]
        /* MBA-811: still unimplemented, but a typed NULL rather than a string that reaches the
           screen as text. Computing it needs a decision on what "last calibration" means for
           this device and point - raised separately. */
        ,CAST(NULL AS DECIMAL(18,6)) as DriftFromLastCalibration
        ,combined.StabilityValue
        ,combined.[MeasurmentPointsToOrderDetailsItemId]
    FROM [dbo].[OrderDetailsItems] as itm
    JOIN @items AS want ON want.OrderDetailsItemId = itm.OrderDetailsItemId
    JOIN [dbo].[OrderDetails] as od ON itm.OrderDetailId = od.OrderDetailId
    JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
    LEFT JOIN (
        SELECT
            COALESCE(mpo.OrderDetailsItemId, evnc.OrderDetailsItemId) as OrderDetailsItemId,
            mpo.ChannelNumber,
            mpo.SensorMeasurementDeviceId,
            mpo.MasterValue,
            mpo.MasterValueUnitId,
            mpo.MeasuredValue,
            mpo.MeasuredValueUnitId,
            mpo.AdditionalValue,
            mpo.AdditionalValueUnitId,
            mpo.UncertancyValue,
            mpo.StabilityValue,
            mpo.MeasurmentPointsToOrderDetailsItemId,
            mpo.SerialNumber,
            mpo.MbaReportNumber,
            COALESCE(mpo.Tolerance, evnc.Tolerance) as Tolerance,
            COALESCE(mpo.NominalValue, evnc.NominalValue) as NominalValue
        FROM (
            SELECT *,
                   ROW_NUMBER() OVER(PARTITION BY OrderDetailsItemId ORDER BY MeasurmentPointsToOrderDetailsItemId) as rn
            FROM [dbo].[MeasurmentPointsToOrderDetailsItems]
            WHERE IsDeleted = 0
              AND OrderDetailsItemId IN (SELECT OrderDetailsItemId FROM @items)
        ) mpo
        FULL OUTER JOIN (
            SELECT *,
                   ROW_NUMBER() OVER(PARTITION BY OrderDetailsItemId ORDER BY NominalValue, CreateDate) as rn
            FROM [dbo].[CalibrationEnvironmentalConditions]
            WHERE IsDeleted = 0
              AND OrderDetailsItemId IN (SELECT OrderDetailsItemId FROM @items)
        ) evnc ON mpo.OrderDetailsItemId = evnc.OrderDetailsItemId AND mpo.rn = evnc.rn
    ) as combined ON itm.OrderDetailsItemId = combined.OrderDetailsItemId
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu  ON combined.[MasterValueUnitId] = mdu.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu2 ON combined.[AdditionalValueUnitId] = mdu2.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu3 ON combined.MeasuredValueUnitId = mdu3.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu4 ON itm.MeasurementUnitId = mdu4.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDevices] as md ON md.ID = combined.[SensorMeasurementDeviceId]
    /* MBA-811: the master reading with its certificate deviation applied. Returns NULL for a
       master with no certificate, and for a temperature+humidity master - that one needs the
       2D interpolation in dbo.fnHumidityAfterCorrection, which our range-shaped correction
       data cannot feed yet. NULL is honest; the screen shows a dash. */
    OUTER APPLY dbo.fnMasterValueAfterCorrection(md.ID, combined.[MasterValue], NULL) AS mvc
    /* the third argument is passed explicitly: an inline table-valued function does not
       apply parameter defaults the way a stored procedure does, and omitting it fails the
       whole call with "an insufficient number of arguments". */
    WHERE (NOT EXISTS (SELECT 1 FROM @details) OR itm.OrderDetailId IN (SELECT OrderDetailId FROM @details))
    ORDER BY itm.[OrderDetailsItemId], combined.[MeasurmentPointsToOrderDetailsItemId], combined.NominalValue;
END
