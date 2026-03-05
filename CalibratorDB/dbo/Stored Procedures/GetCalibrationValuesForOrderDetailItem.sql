-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 27/02/2026
-- Description:	Returns 2 mock rows + real data from DB.
-- Column mapping → TSensorTableRow (SensorsTable):
--   Id, MbaReportNumber→orderNumber, SerialNumber→uutSerialNumber, ShortNameHe→unit,
--   ChannelNumber→channel, MabaID→masterSensorId, NominalValue→masterValue, Tolerance→tolerance,
--   MasterAfterOffset_mock→masterAfterOffset, MeasuredValue_mock→measuredValue,
--   AdditionalMeasuredValue_mock→additionalMeasuredValue, Deviation_mock→deviation,
--   PercentTolerance_mock→percentTolerance, Uncertainty_mock→uncertainty,
--   Drift_mock→drift, Stability_mock→stability, OffsetBefore_mock→offsetBefore, OffsetAfter_mock→offsetAfter.
-- JiraLink:
-- =============================================
CREATE OR ALTER PROCEDURE dbo.GetCalibrationValuesForOrderDetailItem
    @OrderDetailId      INT,
    @OrderDetailsItemId INT
AS

SELECT 1 AS [Id], N'24103693/008' AS [MbaReportNumber], N'8NCIU48N' AS [SerialNumber], 1 AS [MeasurementUnitId], N'C°' AS [ShortNameHe], N'P1' AS [ChannelNumber], 1 AS [SensorMeasurementDeviceId], N'00-000' AS [MabaID], CAST(0.3 AS DECIMAL(10,4)) AS [Tolerance], CAST(149.169 AS DECIMAL(18,6)) AS [NominalValue], CAST(149.14 AS DECIMAL(18,6)) AS [MasterAfterOffset_mock], CAST(149.268 AS DECIMAL(18,6)) AS [MeasuredValue_mock], CAST(138.673 AS DECIMAL(18,6)) AS [AdditionalMeasuredValue_mock], CAST(0.089 AS DECIMAL(18,6)) AS [Deviation_mock], CAST(0.05 AS DECIMAL(10,4)) AS [PercentTolerance_mock], CAST(0.04 AS DECIMAL(10,4)) AS [Uncertainty_mock], CAST(44.5 AS DECIMAL(10,2)) AS [Drift_mock], CAST(0 AS DECIMAL(10,2)) AS [Stability_mock], CAST(0.01 AS DECIMAL(18,6)) AS [OffsetBefore_mock], CAST(0.02 AS DECIMAL(18,6)) AS [OffsetAfter_mock]
UNION ALL
SELECT 2 AS [Id], N'24103693/009' AS [MbaReportNumber], N'8NCIU48N' AS [SerialNumber], 1 AS [MeasurementUnitId], N'C°' AS [ShortNameHe], N'P2' AS [ChannelNumber], 1 AS [SensorMeasurementDeviceId], N'00-000' AS [MabaID], CAST(0.3 AS DECIMAL(10,4)) AS [Tolerance], CAST(149.200 AS DECIMAL(18,6)) AS [NominalValue], CAST(149.17 AS DECIMAL(18,6)) AS [MasterAfterOffset_mock], CAST(149.310 AS DECIMAL(18,6)) AS [MeasuredValue_mock], CAST(139.100 AS DECIMAL(18,6)) AS [AdditionalMeasuredValue_mock], CAST(0.092 AS DECIMAL(18,6)) AS [Deviation_mock], CAST(0.05 AS DECIMAL(10,4)) AS [PercentTolerance_mock], CAST(0.04 AS DECIMAL(10,4)) AS [Uncertainty_mock], CAST(44.5 AS DECIMAL(10,2)) AS [Drift_mock], CAST(0 AS DECIMAL(10,2)) AS [Stability_mock], CAST(0.01 AS DECIMAL(18,6)) AS [OffsetBefore_mock], CAST(0.02 AS DECIMAL(18,6)) AS [OffsetAfter_mock]
UNION ALL
SELECT
     itm.[OrderDetailsItemId] AS [Id]
    ,itm.[MbaReportNumber]
    ,itm.[SerialNumber]
    ,itm.[MeasurementUnitId]
    ,mdu.[ShortNameHe]
    ,CONCAT(N'P', mpo.[ChannelNumber]) AS [ChannelNumber]
    ,mpo.[SensorMeasurementDeviceId]
    ,md.[MabaID]
    ,evnc.[Tolerance]
    ,evnc.[NominalValue]
    ,CAST(NULL AS DECIMAL(18,6)) AS [MasterAfterOffset_mock]
    ,CAST(NULL AS DECIMAL(18,6)) AS [MeasuredValue_mock]
    ,CAST(NULL AS DECIMAL(18,6)) AS [AdditionalMeasuredValue_mock]
    ,CAST(NULL AS DECIMAL(18,6)) AS [Deviation_mock]
    ,CAST(NULL AS DECIMAL(10,4)) AS [PercentTolerance_mock]
    ,CAST(NULL AS DECIMAL(10,4)) AS [Uncertainty_mock]
    ,CAST(NULL AS DECIMAL(10,2)) AS [Drift_mock]
    ,CAST(NULL AS DECIMAL(10,2)) AS [Stability_mock]
    ,CAST(NULL AS DECIMAL(18,6)) AS [OffsetBefore_mock]
    ,CAST(NULL AS DECIMAL(18,6)) AS [OffsetAfter_mock]
FROM [dbo].[OrderDetailsItems] AS itm
LEFT JOIN [dbo].[MeasurementDeviceUnits] AS mdu ON itm.[MeasurementUnitId] = mdu.[MeasurementDeviceUnitId]
LEFT JOIN [dbo].[MeasurmentPointsToOrderDetailsItems] AS mpo ON itm.OrderDetailsItemId = mpo.OrderDetailsItemId AND mpo.IsDeleted = 0
LEFT JOIN [dbo].[CalibrationEnvironmentalConditions] AS evnc ON itm.OrderDetailsItemId = evnc.OrderDetailsItemId AND evnc.IsDeleted = 0
LEFT JOIN [dbo].[MeasurementDevices] AS md ON md.ID = mpo.[SensorMeasurementDeviceId]
WHERE itm.OrderDetailId = @OrderDetailId
  AND itm.OrderDetailsItemId = @OrderDetailsItemId;
GO

-- Example call:
-- EXEC dbo.GetCalibrationValuesForOrderDetailItem @OrderDetailId = 999, @OrderDetailsItemId = 1;
