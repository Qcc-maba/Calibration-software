-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 24/06/2025
-- Description:	Get all devices assosiated to orders details
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE dbo.GetOrderDetailsDevices
@OrderDetailId INT
AS

DECLARE @rows INT = 500
SELECT @rows=[OrderLineCnt] FROM [dbo].[OrderDetails] as od  WHERE OrderDetailId = @OrderDetailId

;WITH numbers
as
(
SELECT 1 as cnt
UNION ALL
SELECT cnt +1 FROM numbers
WHERE cnt <@rows
)
,
result as
(
SELECT 
wp.[OrderWorkPlanId],
wp.[CustomerId],
od.[OrderDetailId],
od.[OrderLineCnt],
od.[OrdersProductTypeId],
odi.[OrderDetailsItemId],
odi.[ActualCalibrationDate],	
odi.[NextCalibrationDate],	
odi.[SerialNumber],
odi.[ManufacturerNumber],
odi.[DeviceModel],
odi.[AdditionalDeviceNumber],	
odi.[MbaReportNumber],
odi.[OrdersMainCategoryId],	
odi.[OrdersSecondaryCategoryId],	
odi.[OrdersDeviceManufacturerId],	
odi.[CalibrationSpecificationId],	
odi.[SpecificationReferenceId],	
odi.[MeasurementUnitId],
odi.[MeasurementPoints],	
odi.[MeasurementValueList],	
odi.[ProductLocation],
e.[EquipmentNames],
ROW_NUMBER() OVER( PARTITION BY wp.[OrderWorkPlanId] ORDER BY wp.[OrderWorkPlanId]) as rn
 FROM [dbo].[OrderWorkPlans] as wp 
JOIN  [dbo].[OrderDetails] as od ON od.OrderWorkPlanId = wp.OrderWorkPlanId
LEFT JOIN [dbo].[OrderDetailsItems] as odi ON od.OrderDetailId = odi.OrderDetailId
LEFT JOIN
(
SELECT mdt.[OrderWorkPlanId], STRING_AGG(md.Description,', ') as EquipmentNames
FROM [dbo].[MeasurementDevicesToOrderHeaders] as mdt
JOIN [dbo].[MeasurementDevices] as md ON mdt.MeasurementDeviceId = md.ID
GROUP BY mdt.[OrderWorkPlanId]
) as e ON e.[OrderWorkPlanId] = wp.[OrderWorkPlanId]
WHERE od.[OrderDetailId] = @OrderDetailId
)
SELECT
r.[OrderWorkPlanId],
r.[CustomerId],
r.[OrderDetailId],
r.[OrderLineCnt],
r.[OrdersProductTypeId],
r.[OrderDetailsItemId],
r.[ActualCalibrationDate],	
r.[NextCalibrationDate],	
r.[SerialNumber],
r.[ManufacturerNumber],
r.[DeviceModel],
r.[AdditionalDeviceNumber],	
r.[MbaReportNumber],
r.[OrdersMainCategoryId],	
r.[OrdersSecondaryCategoryId],	
r.[OrdersDeviceManufacturerId],	
r.[CalibrationSpecificationId],	
r.[SpecificationReferenceId],	
r.[MeasurementUnitId],
r.[MeasurementPoints],	
r.[MeasurementValueList],	
r.[ProductLocation],
r.[EquipmentNames]
FROM numbers as n
JOIN result as r ON n.cnt >= r.rn 
option (maxrecursion 0)