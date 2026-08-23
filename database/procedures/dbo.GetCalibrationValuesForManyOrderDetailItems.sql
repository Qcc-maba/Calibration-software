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
        ,'0_mocked_val' as [MasterValueAfterCorrection]
        ,combined.MeasuredValue
        ,combined.MeasuredValueUnitId
        ,mdu3.[ShortNameHe] as MeasuredUUTDescription
        ,combined.[AdditionalValue]
        ,combined.[AdditionalValueUnitId]
        ,mdu2.[ShortNameHe] as AdditionalUUTDescription
        ,combined.[MasterValue] - combined.[NominalValue] as [Deviation]
        ,((combined.[MasterValue] - combined.[NominalValue])/COALESCE(NULLIF(combined.[Tolerance],0),1))*100 as AllowedDeviation
        ,combined.[UncertancyValue]
        ,'0_mocked_val' as DriftFromLastCalibration
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
    WHERE (NOT EXISTS (SELECT 1 FROM @details) OR itm.OrderDetailId IN (SELECT OrderDetailId FROM @details))
    ORDER BY itm.[OrderDetailsItemId], combined.[MeasurmentPointsToOrderDetailsItemId], combined.NominalValue;
END
GO
