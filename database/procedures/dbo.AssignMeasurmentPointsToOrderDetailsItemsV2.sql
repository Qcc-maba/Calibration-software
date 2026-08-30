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
        c.NominalValue
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
        NominalValue DECIMAL(18,6)
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
        SerialNumber, MbaReportNumber, Tolerance, NominalValue
    )
    SELECT 
        src.OrderDetailsItemId, src.SensorMeasurementDeviceId, src.MeasurmentPointName,
        src.MeasurmentPointCoordX, src.MeasurmentPointCoordY, src.ChannelNumber, @LoggedInUserId,
        src.MasterValue, src.MasterValueUnitId, src.AdditionalValue, src.AdditionalValueUnitId,
        src.StabilityValue, src.UncertancyValue, src.MeasuredValue, src.MeasuredValueUnitId,
        src.SerialNumber, src.MbaReportNumber, src.Tolerance, src.NominalValue
    FROM #parsedData src
    LEFT JOIN [dbo].[MeasurmentPointsToOrderDetailsItems] dest
        ON dest.MeasurmentPointsToOrderDetailsItemId = src.MeasurmentPointsToOrderDetailsItemId
        AND dest.IsDeleted = 0
    WHERE dest.MeasurmentPointsToOrderDetailsItemId IS NULL
      AND src.OrderDetailsItemId IS NOT NULL
      AND src.ChannelNumber IS NOT NULL;

    /* 3. UPDATE SerialNumber and MbaReportNumber in OrderDetailsItems -- NEW (as a backup fallback) */
    UPDATE odi
    SET odi.SerialNumber = COALESCE(pd.SerialNumber, odi.SerialNumber),
        odi.MbaReportNumber = COALESCE(pd.MbaReportNumber, odi.MbaReportNumber)
    FROM [dbo].[OrderDetailsItems] odi
    JOIN (
        SELECT DISTINCT OrderDetailsItemId, 
                        MIN(NULLIF(SerialNumber, '')) AS SerialNumber,
                        MIN(NULLIF(MbaReportNumber, '')) AS MbaReportNumber
        FROM #parsedData
        GROUP BY OrderDetailsItemId
    ) pd ON odi.OrderDetailsItemId = pd.OrderDetailsItemId;

END