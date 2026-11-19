/*
    dbo.GetMeasurmentPointsForOrderDetail                                                  MBA-800
    ---------------------------------------------------------------------------------------------
    The live measurement points of one device (order line item): the chamber diagram's positions,
    each with the sensor and the logger channel that reads it.

    The procedure existed on both servers without a file in git; this file starts from the STAGE
    definition of 2026-11-19 (Eduard Kudlaiev, 31/07/2025), unchanged except for the two MBA-800
    columns at the end:

        PairId      the temperature and RH points of one Temperature + RH position share it
        ValueRole   1 = temperature, 2 = the chamber's second value (RH), NULL = not stated

    (database/schema/dbo.MeasurmentPointsToOrderDetailsItems.ValueRole.sql has the why.) Read by the
    app's masterDevices.getMeasurementPointsForOrderDetail, which maps the columns it knows by name,
    so the two extra columns change nothing for a caller that does not read them.
*/
CREATE OR ALTER PROCEDURE dbo.GetMeasurmentPointsForOrderDetail
@OrderDetailsItemId INT
/*
EXEC dbo.GetMeasurmentPointsForOrderDetail @OrderDetailsItemId = 3077
*/
AS
BEGIN
SET NOCOUNT ON;

SELECT
       mp.[MeasurmentPointsToOrderDetailsItemId]
      ,mp.[OrderDetailsItemId]
      ,mp.[SensorMeasurementDeviceId]
      ,mp.[MeasurmentPointName]
      ,mp.[MeasurmentPointCoordX]
      ,mp.[MeasurmentPointCoordY]
      ,mp.[ChannelNumber]
      ,mp.[PairId]      -- MBA-800
      ,mp.[ValueRole]   -- MBA-800
  FROM [dbo].[MeasurmentPointsToOrderDetailsItems] as mp
  WHERE mp.[IsDeleted] = 0 AND mp.[OrderDetailsItemId] = @OrderDetailsItemId

END
GO
