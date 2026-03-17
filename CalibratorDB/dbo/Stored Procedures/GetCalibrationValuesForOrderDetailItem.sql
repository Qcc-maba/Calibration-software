-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 27/02/2026
-- Description:	Procedure to add new order detail
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[GetCalibrationValuesForOrderDetailItem]
@OrderDetailId INT, 
@OrderDetailsItemId INT
AS

SELECT 
     itm.[MbaReportNumber]
    ,itm.[SerialNumber]
    ,itm.[UnitUnderTestValue]
    ,itm.[MeasurementUnitId] as UUTId--unit under test id
    ,mdu4.[ShortNameHe] as UUTDescription--unit under test
    ,N'P' + CAST(mpo.[ChannelNumber] as NVARCHAR(30)) as [ChannelNumber] --unit under test channel number
    ,mpo.[SensorMeasurementDeviceId] -- Master sensor ID
    ,md.[MabaID] AS MasterSensorMabaID
    ,md.ID as [MeasurementDeviceId] 
    ,evnc.[Tolerance]
    ,evnc.[NominalValue]
    ,wp.[OrderNumber]
    ,mpo.[MasterValue]
    ,mpo.[MasterValueUnitId] 
    ,mdu.[ShortNameHe] as MasterValueUnitDescription
    ,'0_mocked_val' as [MasterValueAfterCorrection]
    ,mpo.MeasuredValue
    ,mpo.MeasuredValueUnitId
    ,mdu3.[ShortNameHe] as MeasuredUUTDescription
    ,mpo.[AdditionalValue]
    ,mpo.[AdditionalValueUnitId]
    ,mdu2.[ShortNameHe] as AdditionalUUTDescription
    ,mpo.[MasterValue] - evnc.[NominalValue] as [Deviation]
    ,((mpo.[MasterValue] - evnc.[NominalValue])/evnc.[Tolerance])*100 as AllowedDeviation
    ,mpo.[UncertancyValue]
    ,'0_mocked_val' as DriftFromLastCalibration
    ,mpo.StabilityValue
  FROM [dbo].[OrderDetailsItems] as itm
  JOIN [dbo].[OrderDetails] as od ON itm.OrderDetailId = od.OrderDetailId
  JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
  LEFT JOIN [dbo].[MeasurmentPointsToOrderDetailsItems] as mpo ON itm.OrderDetailsItemId = mpo.OrderDetailsItemId AND mpo.IsDeleted = 0
  LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu ON mpo.[MasterValueUnitId] = mdu.[MeasurementDeviceUnitId]
  LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu2 ON mpo.[AdditionalValueUnitId] = mdu2.[MeasurementDeviceUnitId]
  LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu3 ON mpo.MeasuredValueUnitId = mdu3.[MeasurementDeviceUnitId]
  LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu4 ON itm.MeasurementUnitId  = mdu4.[MeasurementDeviceUnitId]
  LEFT JOIN [dbo].[CalibrationEnvironmentalConditions] as evnc ON itm.OrderDetailsItemId = evnc.OrderDetailsItemId AND evnc.IsDeleted = 0
  LEFT JOIN [dbo].[MeasurementDevices] as md ON md.ID = mpo.[SensorMeasurementDeviceId]
  WHERE itm.OrderDetailId = @OrderDetailId AND 	itm.OrderDetailsItemId = @OrderDetailsItemId



  /*

    SELECT SerialNumber, 
  itm.[UnitUnderTestValue],
  LEAD(itm.[UnitUnderTestValue]) OVER( PARTITION BY itm.[SerialNumber] ORDER BY itm.[NextCalibrationDate] DESC) as PrevUnitUnderTestValue,
  LEAD(itm.[OrderDetailsItemId]) OVER( PARTITION BY itm.[SerialNumber] ORDER BY itm.[NextCalibrationDate] DESC) as PrevOrderDetailsItemId,
  *
  FROM [dbo].[OrderDetailsItems] as itm
  WHERE itm.[SerialNumber] = '9348-E-1068'
  ORDER BY 7 DESC
  */