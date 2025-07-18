CREATE   PROCEDURE [dbo].[GetSensorDetailsToOrderDetailsItems]
@OrderDetailsItemId INT
AS
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 16/07/2025
-- Description:	Get information from table SensorToOrderDetailsItems regarding calibration process setup
-- JiraLink: 
-- =============================================
BEGIN

SELECT st.[SensorToOrderDetailsItemsId]
      ,st.[OrderDetailsItemId]
      ,st.[LoggerMeasurementDeviceId]
      ,st.[SensorMeasurementDeviceId]
      ,st.[MeasurmentPointName]
      ,st.[MeasurmentPointCoordX]
      ,st.[MeasurmentPointCoordY]
      ,st.[ChannelNumber]
      ,st.[PrimaryMeasurmentUnitId]
      ,st.[SecondaryMeasurmentUnitId]
FROM [dbo].[SensorToOrderDetailsItems] as st
WHERE st.[OrderDetailsItemId] = @OrderDetailsItemId
AND st.[IsDeleted] = 0


END