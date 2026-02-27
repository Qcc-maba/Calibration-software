-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 27/02/2026
-- Description:	Procedure to add new order detail
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE dbo.GetCalibrationValuesForOrderDetailItem
@OrderDetailId INT, 
@OrderDetailsItemId INT
AS
SELECT 
     itm.[MbaReportNumber]
    ,itm.[SerialNumber]
    ,itm.[MeasurementUnitId] --unit under test id
    ,mdu.[ShortNameHe] --unit under test
    ,CONCAT(N'P',mpo.[ChannelNumber]) as [ChannelNumber] --unit under test channel number
    ,mpo.[SensorMeasurementDeviceId] -- Master sensor ID
    ,md.[MabaID] -- Master sensor
    ,evnc.[Tolerance]
    ,evnc.[NominalValue]
  FROM [dbo].[OrderDetailsItems] as itm
  LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu ON itm.[MeasurementUnitId] = mdu.[MeasurementDeviceUnitId]
  LEFT JOIN [dbo].[MeasurmentPointsToOrderDetailsItems] as mpo ON itm.OrderDetailsItemId = mpo.OrderDetailsItemId AND mpo.IsDeleted = 0
  LEFT JOIN [dbo].[CalibrationEnvironmentalConditions] as evnc ON itm.OrderDetailsItemId = evnc.OrderDetailsItemId AND evnc.IsDeleted = 0
  LEFT JOIN [dbo].[MeasurementDevices] as md ON md.ID = mpo.[SensorMeasurementDeviceId]
  WHERE itm.OrderDetailId = @OrderDetailId AND 	itm.OrderDetailsItemId = @OrderDetailsItemId