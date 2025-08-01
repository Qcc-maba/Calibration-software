CREATE   PROCEDURE [dbo].[GetMeasurmentDevicesForOrderDetail]
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
       md.[MeasurmentDeviceToOrderDetailsItemId]
      ,md.[OrderDetailsItemId]
      ,md.[LoggerMeasurementDeviceId]
      ,md.[SensorMeasurementDeviceId]
      ,md.[PrimaryMeasurmentUnitId]
      ,md.[SecondaryMeasurmentUnitId]
  FROM [dbo].[MeasurmentDeviceToOrderDetailsItems] as md
  WHERE md.[IsDeleted] = 0 AND md.[OrderDetailsItemId] = @OrderDetailsItemId

END