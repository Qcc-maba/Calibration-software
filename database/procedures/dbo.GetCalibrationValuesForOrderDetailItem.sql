/*
    dbo.GetCalibrationValuesForOrderDetailItem                                     MBA-811
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
CREATE OR ALTER PROCEDURE [dbo].[GetCalibrationValuesForOrderDetailItem]
@OrderDetailId INT, 
@OrderDetailsItemId INT
AS
BEGIN
    SELECT 
         COALESCE(combined.[MbaReportNumber], itm.[MbaReportNumber]) as [MbaReportNumber]
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
        ,mvc.Corrected as [MasterValueAfterCorrection]
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
            WHERE IsDeleted = 0 AND OrderDetailsItemId = @OrderDetailsItemId
        ) mpo
        FULL OUTER JOIN (
            SELECT *, 
                   ROW_NUMBER() OVER(PARTITION BY OrderDetailsItemId ORDER BY NominalValue, CreateDate) as rn
            FROM [dbo].[CalibrationEnvironmentalConditions]
            WHERE IsDeleted = 0 AND OrderDetailsItemId = @OrderDetailsItemId
        ) evnc ON mpo.OrderDetailsItemId = evnc.OrderDetailsItemId AND mpo.rn = evnc.rn
    ) as combined ON itm.OrderDetailsItemId = combined.OrderDetailsItemId
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu ON combined.[MasterValueUnitId] = mdu.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu2 ON combined.[AdditionalValueUnitId] = mdu2.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu3 ON combined.MeasuredValueUnitId = mdu3.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu4 ON itm.MeasurementUnitId = mdu4.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDevices] as md ON md.ID = combined.[SensorMeasurementDeviceId]
    /* MBA-811: the master reading with its certificate deviation applied. Returns NULL for a
       master with no certificate, and for a temperature+humidity master - that one needs the
       2D interpolation in dbo.fnHumidityAfterCorrection, which our range-shaped correction
       data cannot feed yet. NULL is honest; the screen shows a dash. */
    OUTER APPLY dbo.fnMasterValueAfterCorrection(md.ID, combined.[MasterValue]) AS mvc
    WHERE itm.OrderDetailId = @OrderDetailId 
      AND itm.OrderDetailsItemId = @OrderDetailsItemId
    ORDER BY combined.[MeasurmentPointsToOrderDetailsItemId], combined.NominalValue
END