/*
    MBA-802: PairId marks the two rows (Temperature, RH) that are one measuring point of a humidity
    device; see database/schema/dbo.MeasurmentPointsToOrderDetailsItems.PairId.sql.

    On UPDATE a missing PairId keeps the stored one, unlike the other columns here. An app build
    without pairs sends none, and a save from it must not unpair a humidity device's rows. The app
    never unpairs rows, so nothing needs to clear it.
*/
CREATE OR ALTER PROCEDURE [dbo].[AssignMeasurmentPointsToOrderDetailsItemsV2]
@LoggedInUserEmail NVARCHAR(255),
@Data NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LoggedInUserId INT;
    SELECT @LoggedInUserId = ID FROM [dbo].[Users] WHERE Email = @LoggedInUserEmail;

    IF OBJECT_ID('tempdb..#parsedData') IS NOT NULL DROP TABLE #parsedData;

    SELECT 
        d.OrderDetailsItemId,
        c.MeasurmentPointsToOrderDetailsItemId,
        c.MeasurmentPointName,
        c.MeasurmentPointCoordX,
        c.MeasurmentPointCoordY,
        ISNULL(c.SensorMeasurementDeviceId, 843) AS SensorMeasurementDeviceId,
        c.ChannelNumber,
        c.MasterValue,
        c.MasterValueUnitId,
        c.AdditionalValue,
        c.AdditionalValueUnitId,
        c.StabilityValue,
        c.UncertancyValue,
        c.MeasuredValue,
        c.MeasuredValueUnitId,
        c.SerialNumber,  -- UUT Serial Number
        c.MbaReportNumber,
        c.Tolerance,
        c.NominalValue,
        c.PairId
    INTO #parsedData
    FROM OPENJSON(@Data) 
    WITH (
        OrderDetailsItemId INT,
        Points NVARCHAR(MAX) AS JSON
    ) AS d
    OUTER APPLY OPENJSON(d.Points)
    WITH (
        MeasurmentPointsToOrderDetailsItemId INT,
        MeasurmentPointName NVARCHAR(100),
        MeasurmentPointCoordX DECIMAL(10,4),
        MeasurmentPointCoordY DECIMAL(10,4),
        SensorMeasurementDeviceId INT,
        ChannelNumber INT,
        /* MBA-811: was DECIMAL(10,4) here while the column itself was DECIMAL(10,8).
           Both are now (18,6), matching NominalValue - the value this is compared against. */
        MasterValue DECIMAL(18,6),
        MasterValueUnitId INT,
        AdditionalValue DECIMAL(10,4),
        AdditionalValueUnitId INT,
        StabilityValue DECIMAL(10,4),
        UncertancyValue DECIMAL(10,4),
        MeasuredValue DECIMAL(10,4),
        MeasuredValueUnitId INT,
        SerialNumber NVARCHAR(100),
        MbaReportNumber NVARCHAR(100),
        Tolerance DECIMAL(18,6),
        NominalValue DECIMAL(18,6),
        PairId UNIQUEIDENTIFIER
    ) AS c;

    /* 1. UPDATE existing measurement points */
    UPDATE dest
    SET  dest.ChannelNumber             = src.ChannelNumber
        ,dest.SensorMeasurementDeviceId = src.SensorMeasurementDeviceId
        ,dest.MasterValue               = src.MasterValue
        ,dest.MasterValueUnitId         = src.MasterValueUnitId
        ,dest.AdditionalValue           = src.AdditionalValue
        ,dest.AdditionalValueUnitId     = src.AdditionalValueUnitId
        ,dest.StabilityValue            = src.StabilityValue
        ,dest.UncertancyValue           = src.UncertancyValue
        ,dest.MeasuredValue             = src.MeasuredValue
        ,dest.MeasuredValueUnitId       = src.MeasuredValueUnitId
        ,dest.SerialNumber              = src.SerialNumber
        ,dest.MbaReportNumber           = src.MbaReportNumber
        ,dest.Tolerance                 = src.Tolerance
        ,dest.NominalValue              = src.NominalValue
        ,dest.PairId                    = COALESCE(src.PairId, dest.PairId)
        ,dest.UpdatedDate               = GETDATE()
        ,dest.UpdateUserID              = @LoggedInUserId
    FROM [dbo].[MeasurmentPointsToOrderDetailsItems] dest
    JOIN #parsedData src
        ON dest.MeasurmentPointsToOrderDetailsItemId = src.MeasurmentPointsToOrderDetailsItemId
    WHERE dest.IsDeleted = 0
      AND src.MeasurmentPointsToOrderDetailsItemId IS NOT NULL;

    /* 2. INSERT new rows */
    INSERT INTO [dbo].[MeasurmentPointsToOrderDetailsItems] (
        OrderDetailsItemId, SensorMeasurementDeviceId, MeasurmentPointName,
        MeasurmentPointCoordX, MeasurmentPointCoordY, ChannelNumber, UpdateUserID,
        MasterValue, MasterValueUnitId, AdditionalValue, AdditionalValueUnitId,
        StabilityValue, UncertancyValue, MeasuredValue, MeasuredValueUnitId,
        SerialNumber, MbaReportNumber, Tolerance, NominalValue, PairId
    )
    SELECT
        src.OrderDetailsItemId, src.SensorMeasurementDeviceId, src.MeasurmentPointName,
        src.MeasurmentPointCoordX, src.MeasurmentPointCoordY, src.ChannelNumber, @LoggedInUserId,
        src.MasterValue, src.MasterValueUnitId, src.AdditionalValue, src.AdditionalValueUnitId,
        src.StabilityValue, src.UncertancyValue, src.MeasuredValue, src.MeasuredValueUnitId,
        src.SerialNumber, src.MbaReportNumber, src.Tolerance, src.NominalValue, src.PairId
    FROM #parsedData src
    LEFT JOIN [dbo].[MeasurmentPointsToOrderDetailsItems] dest
        ON dest.MeasurmentPointsToOrderDetailsItemId = src.MeasurmentPointsToOrderDetailsItemId
        AND dest.IsDeleted = 0
    WHERE dest.MeasurmentPointsToOrderDetailsItemId IS NULL
      AND src.OrderDetailsItemId IS NOT NULL
      AND src.ChannelNumber IS NOT NULL;

    /* 3. Write the device's own UUT serial back to OrderDetailsItems (and its MABA No, only when it has none).

       MBA-855: a device's table rows may carry another MABA No, and a different MABA No may have a
       different UUT serial. This step used to take MIN() over ALL rows, so one such row replaced the
       device's own MABA No and serial with the other device's. Measured on STAGE 2026-10-26 in a
       rolled-back transaction: item 4146 went from 2628023/11 / mynew567 to 2628023/10 / AAA-OTHER-SN.
       Now only rows that carry the device's MABA No, or none, count. The device's MABA No comes from
       Priority, so it is only filled from the rows when the device has none. */
    UPDATE odi
    SET odi.SerialNumber = COALESCE(pd.SerialNumber, odi.SerialNumber),
        odi.MbaReportNumber = COALESCE(NULLIF(LTRIM(RTRIM(odi.MbaReportNumber)), ''), pd.MbaReportNumber)
    FROM [dbo].[OrderDetailsItems] odi
    JOIN (
        SELECT src.OrderDetailsItemId,
               MIN(NULLIF(LTRIM(RTRIM(src.SerialNumber)), '')) AS SerialNumber,
               MIN(NULLIF(LTRIM(RTRIM(src.MbaReportNumber)), '')) AS MbaReportNumber
        FROM #parsedData src
        JOIN [dbo].[OrderDetailsItems] own ON own.OrderDetailsItemId = src.OrderDetailsItemId
        WHERE NULLIF(LTRIM(RTRIM(own.MbaReportNumber)), '') IS NULL
           OR NULLIF(LTRIM(RTRIM(src.MbaReportNumber)), '') IS NULL
           OR LTRIM(RTRIM(src.MbaReportNumber)) = LTRIM(RTRIM(own.MbaReportNumber))
        GROUP BY src.OrderDetailsItemId
    ) pd ON odi.OrderDetailsItemId = pd.OrderDetailsItemId;

END