-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 24/06/2025
-- Description:	Get all devices assosiated to orders details
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[GetOrderDetailsDevices]
@OrderDetailId INT
AS

DECLARE @OrderWorkPlanId INT = 0 
DECLARE @rows INT = 0
SELECT @rows=[OrderLineCnt],
	   @OrderWorkPlanId = [OrderWorkPlanId]
FROM [dbo].[OrderDetails] as od  WHERE OrderDetailId = @OrderDetailId

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
opt.[OrdersProductTypeName] as [OrdersProductType],
odi.[OrderDetailsItemId],
odi.[ActualCalibrationDate],	
odi.[NextCalibrationDate],	
odi.[SerialNumber],
odi.[ManufacturerNumber],
odi.[DeviceModel],
odi.[AdditionalDeviceNumber],	
odi.[MbaReportNumber],
odi.[OrdersMainCategoryId],	
omc.[OrdersMainCategoryName] as [OrdersMainCategory],
odi.[OrdersSecondaryCategoryId],
oc.[OrdersSecondaryCategoryName] as [OrdersSecondaryCategory],
odi.[OrdersDeviceManufacturerId],	
odf.[OrdersDeviceManufacturerDescription] as [OrdersDeviceManufacturer],
odi.[CalibrationSpecificationId],
mc.Name as [CalibrationSpecification],
odi.[SpecificationReferenceId],	
sr.[Name] as [SpecificationReference],
odi.[MeasurementUnitId],
mu.ShortNameHe as [MeasurementUnit],
odi.[MeasurementPoints],	
odi.[MeasurementValueList],	
odi.[ProductLocation],
e.[EquipmentNames],
ROW_NUMBER() OVER( PARTITION BY wp.[OrderWorkPlanId] ORDER BY wp.[OrderWorkPlanId]) as rn
 FROM [dbo].[OrderWorkPlans] as wp 
JOIN  [dbo].[OrderDetails] as od ON od.OrderWorkPlanId = wp.OrderWorkPlanId
LEFT JOIN [dbo].[OrderDetailsItems] as odi ON od.OrderDetailId = odi.OrderDetailId
LEFT JOIN [dbo].[OrdersProductTypes] as opt ON od.[OrdersProductTypeId] = opt.[OrdersProductTypeId]
LEFT JOIN [dbo].[OrdersMainCategories] as omc ON odi.[OrdersMainCategoryId] = omc.OrdersMainCategoryId
LEFT JOIN [dbo].[OrdersSecondaryCategories] as oc ON odi.[OrdersSecondaryCategoryId] = oc.OrdersSecondaryCategoryId
LEFT JOIN [dbo].[OrdersDeviceManufacturers] as odf ON odi.[OrdersDeviceManufacturerId] = odf.OrdersDeviceManufacturerId
LEFT JOIN [dbo].[MeasurementsSpecifications] mc ON odi.[CalibrationSpecificationId] = mc.ID
LEFT JOIN [dbo].[SpecificationReference] as sr ON odi.[SpecificationReferenceId] = sr.ID
LEFT JOIN [dbo].[MeasurementDeviceUnits] as mu ON odi.[MeasurementUnitId] = mu.MeasurementDeviceUnitId
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
COALESCE(r.[OrderWorkPlanId],@OrderWorkPlanId) as [OrderWorkPlanId],
r.[CustomerId],
COALESCE(r.[OrderDetailId],@OrderDetailId) as [OrderDetailId],
r.[OrderLineCnt],
r.[OrdersProductTypeId],
r.[OrdersProductType],
r.[OrderDetailsItemId],
r.[ActualCalibrationDate],	
r.[NextCalibrationDate],	
r.[SerialNumber],
r.[ManufacturerNumber],
r.[DeviceModel],
r.[AdditionalDeviceNumber],	
r.[MbaReportNumber],
r.[OrdersMainCategoryId],	
r.[OrdersMainCategory],
r.[OrdersSecondaryCategoryId],	
r.[OrdersSecondaryCategory],
r.[OrdersDeviceManufacturerId],	
r.[OrdersDeviceManufacturer],
r.[CalibrationSpecificationId],	
r.[CalibrationSpecification],
r.[SpecificationReferenceId],	
r.[SpecificationReference],
r.[MeasurementUnitId],
r.[MeasurementUnit],
r.[MeasurementPoints],	
r.[MeasurementValueList],	
r.[ProductLocation],
r.[EquipmentNames]
FROM numbers as n
FULL JOIN result as r ON n.cnt = r.rn 
option (maxrecursion 0)