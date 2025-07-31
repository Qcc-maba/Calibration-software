CREATE   PROCEDURE dbo.GetMeasurmentPointsForOrderDetail
@OrderDetailsItemId INT
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 31/07/2025
-- Description:	
-- JiraLink: 
-- =============================================
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
  FROM [dbo].[MeasurmentPointsToOrderDetailsItems] as mp
  WHERE mp.[IsDeleted] = 0 AND mp.[OrderDetailsItemId] = @OrderDetailsItemId

END