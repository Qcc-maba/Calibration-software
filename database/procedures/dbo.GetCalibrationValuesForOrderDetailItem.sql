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

    MBA-802: also returns PairId, which marks the Temperature and RH rows of one measuring point on
    a humidity device (NULL on every other row). The app pairs rows by it instead of by channel.
    The compensation quantity falls back to the row's measured unit when it has no master unit, so
    an RH row is never compensated with a temperature curve (see the OUTER APPLY below).

    MBA-950: an RH row is compensated by dbo.fnHumidityAfterCorrection, which needs the master's
    COMPENSATED temperature (Nofar, 38472). That is taken from the other row of the row's
    Temperature/RH pair (same PairId): its own master, its own reading, through
    dbo.fnMasterValueAfterCorrection. The pair's two rows may use two different masters (Nofar,
    35012). With no pair, or a pair whose temperature row has no compensated value, the temperature
    is NULL: a certificate taken at one temperature still answers, anything else returns
    CompensationMethod 'needs-temperature' and a dash. The "temperature measured nearby" rule for
    that case is not defined yet.
    New columns: MasterHasCorrectionForQuantity, CompensationSource, CompensationMethod,
    HumidityTemperatureInput.
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
        /* The display value: the reading's own precision, but never fewer than 3 decimals.
           Rounding purely to the input erased the correction - 23 came back as 23. Full
           precision is still available as MasterValueAfterCorrectionExact. */
        ,cmp.Corrected      as [MasterValueAfterCorrection]
        ,cmp.CorrectedExact as [MasterValueAfterCorrectionExact]
        /* MBA-475: is the calibrator driving the master outside its own working range?
           This is a DIFFERENT question from mvc.OutOfRange, which asks whether the reading fell
           outside the CERTIFICATE and the deviation had to be clamped. A master can be well
           inside its working range and still beyond its last calibrated point, and the reverse.
           The threshold is the fixed 10 units the ticket specifies - range -80..200, reading 220,
           20 beyond, so highlighted. It is written once, here and in the Many variant. */
        ,md.WorkRangeMin as [SensorRangeMin]
        ,md.WorkRangeMax as [SensorRangeMax]
        ,CAST(CASE WHEN md.WorkRangeMin IS NULL OR md.WorkRangeMax IS NULL THEN NULL
                   WHEN combined.[MasterValue] IS NULL THEN NULL
                   WHEN combined.[MasterValue] > md.WorkRangeMax + 10 THEN 1
                   WHEN combined.[MasterValue] < md.WorkRangeMin - 10 THEN 1
                   ELSE 0 END AS BIT) as [OutOfSensorRange]
        ,CAST(CASE WHEN md.WorkRangeMin IS NULL OR md.WorkRangeMax IS NULL THEN NULL
                   WHEN combined.[MasterValue] > md.WorkRangeMax THEN combined.[MasterValue] - md.WorkRangeMax
                   WHEN combined.[MasterValue] < md.WorkRangeMin THEN md.WorkRangeMin - combined.[MasterValue]
                   ELSE 0 END AS DECIMAL(18,6)) as [BeyondSensorRangeBy]
        /* and whether the compensation itself had to extrapolate */
        ,cmp.OutOfRange   as [BeyondCertificateRange]
        ,cmp.Extrapolated as [DeviationExtrapolated]
        ,cmp.CertificateTop      as [CertificateTop]
        /*  MBA-950: a master with no certificate has not been calibrated itself and must not be
            used silently. 5 of the 19 masters in use on STAGE are in that state, covering 206
            measurement points, and all of them are temperature-and-humidity instruments.
            NULL means no master is assigned to the row at all - a different thing from an
            uncalibrated one, and the screen should say so differently. */
        ,CAST(CASE WHEN combined.[SensorMeasurementDeviceId] IS NULL THEN NULL
                   WHEN EXISTS (SELECT 1 FROM dbo.MeasurementDevicesCorrections AS mc
                                WHERE mc.MeasurementDevicesId = md.ID
                                  AND ISNULL(mc.IsDeleted, 0) = 0) THEN 1
                   /* MBA-950: a humidity certificate entered as points is a certificate too */
                   WHEN EXISTS (SELECT 1 FROM dbo.MeasurementDevicesHumidityCorrections AS hcc
                                WHERE hcc.MeasurementDevicesId = md.ID
                                  AND hcc.IsDeleted = 0) THEN 1
                   ELSE 0 END AS BIT) as [MasterHasCertificate]
        ,cmp.LastCalibratedPoint as [LastCalibratedPoint]
        /* MBA-475: whether this instrument is permitted to go out of range at all, from the
           kyulan registry. 328 instruments permit neither end; for those, any overshoot may
           deserve the highlight rather than only one past 10. */
        ,md.AllowMinOutOfRange as [AllowMinOutOfRange]
        ,md.AllowMaxOutOfRange as [AllowMaxOutOfRange]
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
        ,combined.[PairId]
        /*  MBA-950: does the master hold a correction for THIS ROW'S quantity, in its newest
            certificate? The screen allows an RH row without compensation only when this is 0 - the
            master really has nothing to compensate it with - instead of for any RH row with a master.
            NULL: no master on the row. For a row whose quantity is unknown (no unit), any curve counts. */
        ,CAST(CASE WHEN md.ID IS NULL THEN NULL
                   WHEN q.IsHumidity = 1 AND EXISTS (SELECT 1 FROM dbo.MeasurementDevicesHumidityCorrections AS hc
                                                     WHERE hc.MeasurementDevicesId = md.ID AND hc.IsDeleted = 0) THEN 1
                   WHEN EXISTS (SELECT 1 FROM dbo.MeasurementDevicesCorrections AS mc
                                WHERE mc.MeasurementDevicesId = md.ID
                                  AND ISNULL(mc.IsDeleted, 0) = 0
                                  AND mc.Equation IS NOT NULL
                                  AND (q.QuantityId IS NULL OR mc.MeasurementId = q.QuantityId)
                                  AND mc.CorVersion = (SELECT MAX(m2.CorVersion) FROM dbo.MeasurementDevicesCorrections AS m2
                                                       WHERE m2.MeasurementDevicesId = md.ID
                                                         AND ISNULL(m2.IsDeleted, 0) = 0
                                                         AND m2.Equation IS NOT NULL)) THEN 1
                   ELSE 0 END AS BIT) as [MasterHasCorrectionForQuantity]
        /* where the compensated value came from: 'curve' (a one-axis certificate), or for RH rows
           'points' | 'curve-humidity' | 'curve-temperature' (see dbo.fnHumidityAfterCorrection) */
        ,cmp.Source as [CompensationSource]
        ,cmp.Method as [CompensationMethod]
        /* the master temperature, after its own compensation, that an RH row was compensated at */
        ,cmp.TemperatureUsed as [HumidityTemperatureInput]
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
            mpo.PairId,
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
    /*  MBA-950: ask for THIS ROW'S quantity, not "whichever the master has most of".
        A probe measuring temperature and humidity produces two rows against one master. Passing
        NULL let the function pick the better-covered curve, so both rows got the temperature
        answer - and the humidity row displayed the temperature's compensated value labelled '%'.
        Seen on master 21-554: a TC-K field probe with four temperature certificates and no
        humidity certificate at all, showing 149.14 as a humidity reading.

        The quantity is resolved from the row's own unit BY NAME rather than by id, because
        dbo.Measurements is not numbered the same on the two servers - %RH is 3 on STAGE and 4 on
        PROD, °C is 4 and 5. Matching '°C' to '°C' is correct on both.

        Where the master holds no certificate for that quantity the function now returns nothing,
        which is the honest answer: MasterValueAfterCorrection is NULL and the screen shows a dash
        instead of the other quantity's number.

        MBA-802: when the row has no MasterValueUnitId, its own MeasuredValueUnitId says the
        quantity. The sensors table's Temperature/RH pairs set the measured unit and, until now,
        not the master one, so the RH row of a pair fell back to "whichever the master has most of"
        - a temperature curve on a humidity reading. Rows with neither unit (the older temperature
        rows) keep that fallback, as before.  */
    /*  the row's quantity, from its master unit or else its measured unit, resolved BY NAME */
    OUTER APPLY (SELECT QuantityId = qm.ID,
                        IsHumidity = CASE WHEN LTRIM(RTRIM(qm.NameEn)) = N'%RH' THEN 1 ELSE 0 END
                 FROM (SELECT TOP (1) m.ID, m.NameEn
                       FROM dbo.Measurements AS m
                       JOIN dbo.MeasurementDeviceUnits AS u
                         ON LTRIM(RTRIM(u.ShortNameEn)) = LTRIM(RTRIM(m.NameEn))
                        AND ISNULL(u.IsDeleted, 0) = 0
                       WHERE u.MeasurementDeviceUnitId = COALESCE(combined.[MasterValueUnitId], combined.[MeasuredValueUnitId])) AS qm) AS q
    OUTER APPLY dbo.fnMasterValueAfterCorrection(
        CASE WHEN ISNULL(q.IsHumidity, 0) = 0 THEN md.ID END,
        combined.[MasterValue],
        q.QuantityId) AS mvc
    /*  MBA-950: an RH row's temperature input - the other row of its pair, compensated against
        that row's own master. Only looked up for RH rows. */
    OUTER APPLY (SELECT TOP (1) p.SensorMeasurementDeviceId, p.MasterValue
                 FROM dbo.MeasurmentPointsToOrderDetailsItems AS p
                 WHERE q.IsHumidity = 1
                   AND combined.[PairId] IS NOT NULL
                   AND p.OrderDetailsItemId = combined.[OrderDetailsItemId]
                   AND p.PairId = combined.[PairId]
                   AND p.IsDeleted = 0
                   AND p.MeasurmentPointsToOrderDetailsItemId <> combined.[MeasurmentPointsToOrderDetailsItemId]
                   /* never an RH row: the same rule as dbo.GetMasterValuesAfterCorrection */
                   AND NOT EXISTS (SELECT 1
                                   FROM dbo.MeasurementDeviceUnits AS pu
                                   JOIN dbo.Measurements AS pm
                                     ON LTRIM(RTRIM(pm.NameEn)) = LTRIM(RTRIM(pu.ShortNameEn))
                                   WHERE pu.MeasurementDeviceUnitId = COALESCE(p.MasterValueUnitId, p.MeasuredValueUnitId)
                                     AND ISNULL(pu.IsDeleted, 0) = 0
                                     AND LTRIM(RTRIM(pm.NameEn)) = N'%RH')
                 ORDER BY p.MeasurmentPointsToOrderDetailsItemId) AS pr
    OUTER APPLY dbo.fnMasterValueAfterCorrection(
        pr.SensorMeasurementDeviceId,
        pr.MasterValue,
        (SELECT TOP (1) ID FROM dbo.Measurements WHERE LTRIM(RTRIM(NameEn)) = N'°C' ORDER BY ID)) AS prt
    OUTER APPLY dbo.fnHumidityAfterCorrection(
        CASE WHEN q.IsHumidity = 1 THEN md.ID END,
        prt.CorrectedExact,
        combined.[MasterValue]) AS hum
    /*  one set of compensation columns, from whichever function answers for the row's quantity */
    CROSS APPLY (SELECT Corrected           = IIF(q.IsHumidity = 1, hum.Corrected, mvc.Corrected),
                        CorrectedExact      = IIF(q.IsHumidity = 1, hum.CorrectedExact, mvc.CorrectedExact),
                        OutOfRange          = IIF(q.IsHumidity = 1, hum.OutOfRange, mvc.OutOfRange),
                        Extrapolated        = IIF(q.IsHumidity = 1, hum.Extrapolated, mvc.Extrapolated),
                        CertificateTop      = IIF(q.IsHumidity = 1, hum.CertificateTop, mvc.CertificateTop),
                        LastCalibratedPoint = IIF(q.IsHumidity = 1, hum.LastCalibratedPoint, mvc.LastCalibratedPoint),
                        Source              = IIF(q.IsHumidity = 1, hum.Source,
                                                  IIF(mvc.Deviation IS NOT NULL, N'curve', NULL)),
                        Method              = IIF(q.IsHumidity = 1, hum.Method,
                                                  IIF(mvc.Deviation IS NOT NULL, N'range', NULL)),
                        TemperatureUsed     = IIF(q.IsHumidity = 1, hum.TemperatureUsed, NULL)) AS cmp
    /* the third argument is passed explicitly: an inline table-valued function does not
       apply parameter defaults the way a stored procedure does, and omitting it fails the
       whole call with "an insufficient number of arguments". */
    WHERE itm.OrderDetailId = @OrderDetailId 
      AND itm.OrderDetailsItemId = @OrderDetailsItemId
    ORDER BY combined.[MeasurmentPointsToOrderDetailsItemId], combined.NominalValue
END