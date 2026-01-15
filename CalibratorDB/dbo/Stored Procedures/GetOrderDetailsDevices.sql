

-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 24/06/2025
-- Description:	Get all devices assosiated to orders details
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[GetOrderDetailsDevices] 
@OrderWorkPlanId INT,
@OrderDetailId INT = NULL,
@LoggedInUserEmail NVARCHAR(50) = NULL,
@OrderDetailsItems INT =NULL
AS

DECLARE @LoggedInUserId INT = 0
DECLARE @SourceId TINYINT
DECLARE @IsUserCalibrator BIT 

SELECT 
	@LoggedInUserId  = d.UserId 
   ,@SourceId = d.SourceId
   ,@IsUserCalibrator = IIF(ur.UserRoleName = N'Calibrator',1,0)
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d
JOIN dbo.Users as u ON d.UserId  = u.ID
JOIN dbo.UserRoles as ur ON u.UserRoleId = ur.UserRoleId


;WITH numbers
as
(
SELECT 1 as cnt, od.OrderLineCnt, od.OrderDetailId, od.OrdersProductTypeId, od.OrderWorkPlanId
FROM [dbo].[OrderDetails] as od 
WHERE od.OrderWorkPlanId = @OrderWorkPlanId
UNION ALL
SELECT n.cnt +1, od.OrderLineCnt, od.OrderDetailId, od.OrdersProductTypeId, od.OrderWorkPlanId
FROM numbers as n
JOIN [dbo].[OrderDetails] as od ON od.OrderDetailId = n.OrderDetailId AND od.OrderLineCnt = n.OrderLineCnt
WHERE od.OrderWorkPlanId = @OrderWorkPlanId
AND cnt < od.OrderLineCnt
)
,
result as
(
SELECT 
wp.[OrderWorkPlanId],
wp.[OrderNumber],
wp.[CustomerId],
cust.[CustomerName],
od.[OrderDetailId],
od.[OrderLineCnt],
od.[OrdersProductTypeId],
opt.[OrdersProductTypeName] as [OrdersProductType],
odi.[OrderDetailsItemId],
GETDATE() AS [ActualCalibrationDate],	
odi.[NextCalibrationDate],	
odi.[SerialNumber],
odi.[ManufacturerNumber],
odi.[DeviceModel],
odi.[AdditionalDeviceNumber],	
odi.[MbaReportNumber],
od.[MainCategoryId],	
omc.[MainCategoryName] as [OrdersMainCategory],
od.SecondaryCategoryId as [OrdersSecondaryCategoryId],
oc.[SecondaryCategoryName] as [OrdersSecondaryCategory],
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
scs.[StatusDescriptionENG] as [CalibrationStatus],
scs.[StatusDescriptionHEB] as [CalibrationStatusHEB],
odi.Accuracy,
odi.IsManuallyAdded,
odi.IsChecked,
odi.StickerAmount,
odi.StickerTypeId,
stit.StatusDescriptionHEB as StickerType,
ROW_NUMBER() OVER( PARTITION BY odi.OrderDetailId ORDER BY odi.OrderDetailId) as rn
 FROM [dbo].[OrderWorkPlans] as wp 
JOIN  [dbo].[OrderDetails] as od ON od.OrderWorkPlanId = wp.OrderWorkPlanId
LEFT JOIN [dbo].[Customers] as cust ON wp.CustomerId = cust.CustomerId
LEFT JOIN [dbo].[OrderDetailsItems] as odi ON od.OrderDetailId = odi.OrderDetailId
LEFT JOIN [dbo].[OrdersProductTypes] as opt ON od.[OrdersProductTypeId] = opt.[OrdersProductTypeId]
LEFT JOIN [dbo].[MainCategories] as omc ON od.[MainCategoryId] = omc.ID
LEFT JOIN [dbo].[SecondaryCategories] as oc ON od.[SecondaryCategoryId] = oc.ID
LEFT JOIN [dbo].[OrdersDeviceManufacturers] as odf ON odi.[OrdersDeviceManufacturerId] = odf.OrdersDeviceManufacturerId
LEFT JOIN [dbo].[MeasurementsSpecifications] mc ON odi.[CalibrationSpecificationId] = mc.ID
LEFT JOIN [dbo].[SpecificationReference] as sr ON odi.[SpecificationReferenceId] = sr.ID
LEFT JOIN [dbo].[MeasurementDeviceUnits] as mu ON odi.[MeasurementUnitId] = mu.MeasurementDeviceUnitId
LEFT JOIN [dbo].[Statuses] as scs ON odi.[CalibrationStatusId] = scs.StatusId
LEFT JOIN [dbo].[Statuses] as stit ON odi.StickerTypeId = stit.StatusId
LEFT JOIN [dbo].[CalibratorsToWorkPlan] as ctwp ON ctwp.[OrderWorkPlanId] = wp.[OrderWorkPlanId] AND ctwp.[CalibratorId] = @LoggedInUserId AND ctwp.IsDeleted = 0
LEFT JOIN
(
SELECT mdt.[OrderWorkPlanId], STRING_AGG(md.Description,', ') as EquipmentNames
FROM [dbo].[MeasurementDevicesToOrderHeaders] as mdt
JOIN [dbo].[MeasurementDevices] as md ON mdt.MeasurementDeviceId = md.ID
GROUP BY mdt.[OrderWorkPlanId]
) as e ON e.[OrderWorkPlanId] = wp.[OrderWorkPlanId]
WHERE wp.[OrderWorkPlanId] = @OrderWorkPlanId 
)
SELECT
FIRST_VALUE(r.[OrderWorkPlanId]) OVER(ORDER BY r.[OrderWorkPlanId] DESC) as [OrderWorkPlanId],
FIRST_VALUE(r.[OrderNumber]) OVER(ORDER BY r.[OrderWorkPlanId] DESC) as [OrderNumber],
FIRST_VALUE(r.[CustomerId]) OVER(ORDER BY r.[OrderWorkPlanId] DESC) as [CustomerId],
FIRST_VALUE(r.[CustomerName]) OVER(ORDER BY r.[OrderWorkPlanId] DESC) as [CustomerName],
FIRST_VALUE(COALESCE(r.[OrderDetailId],n.[OrderDetailId])) OVER(PARTITION BY r.[OrderDetailId] ORDER BY r.[OrderDetailId]) as [OrderDetailId],
FIRST_VALUE(COALESCE(r.[OrderLineCnt],n.[OrderLineCnt])) OVER(PARTITION BY r.[OrderDetailId] ORDER BY r.[OrderDetailId]) as [OrderLineCnt],
FIRST_VALUE(COALESCE(r.[OrdersProductTypeId],n.[OrdersProductTypeId])) OVER(PARTITION BY r.[OrderDetailId] ORDER BY r.[OrderDetailId]) as [OrdersProductTypeId],
COALESCE(opt1.[OrdersProductTypeName],opt2.[OrdersProductTypeName]) AS[OrdersProductType],
r.[OrderDetailsItemId],
r.[ActualCalibrationDate],	
r.[NextCalibrationDate],	
r.[SerialNumber],
r.[ManufacturerNumber],
r.[DeviceModel],
r.[AdditionalDeviceNumber],	
CASE 
	WHEN @IsUserCalibrator = 1 THEN IIF(CHARINDEX(ctwp.OrderDetailsMbaReportNumber,r.[MbaReportNumber] ) <> 0,r.[MbaReportNumber],CONCAT(ctwp.OrderDetailsMbaReportNumber,'\',ROW_NUMBER() OVER (PARTITION BY COALESCE(r.[OrderWorkPlanId],n.[OrderWorkPlanId]) ORDER BY r.[OrderWorkPlanId])  ))
ELSE r.[MbaReportNumber]
END as [MbaReportNumber],
r.[MainCategoryId] as [OrdersMainCategoryId],	
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
r.[EquipmentNames],
r.[CalibrationStatus],
r.[CalibrationStatusHEB],
r.[Accuracy],
r.[IsManuallyAdded],
r.IsChecked,
r.StickerAmount,
r.StickerTypeId,
r.StickerType,
ds.EnvironmentalConditions,
odi.SecondCalibratorId,
odi.MainCalibratorId,
odi.Volume,
odi.VisualCheck
FROM  numbers as n
LEFT JOIN result as r ON  r.OrderDetailId = n.OrderDetailId and r.rn = n.cnt 
LEFT JOIN [dbo].[OrdersProductTypes] as opt1 ON n.[OrdersProductTypeId] = opt1.[OrdersProductTypeId]
LEFT JOIN [dbo].[OrdersProductTypes] as opt2 ON r.[OrdersProductTypeId] = opt2.[OrdersProductTypeId]
LEFT JOIN [dbo].[CalibratorsToWorkPlan] as ctwp ON ctwp.[OrderWorkPlanId] = COALESCE(r.[OrderWorkPlanId],n.[OrderWorkPlanId]) AND ctwp.[CalibratorId] = @LoggedInUserId AND ctwp.IsDeleted = 0
LEFT JOIN [dbo].[OrderDetailsItems] as odi ON n.OrderDetailId = odi.OrderDetailId AND odi.[OrderDetailsItemId] = r.[OrderDetailsItemId]
OUTER APPLY
(
SELECT 
	ShortNameEn as MeasurementDeviceUnitEn,
	ShortNameHe as MeasurementDeviceUnitHeb,
	ic.NominalValue,
	ic.Tolerance
FROM [dbo].[CalibrationEnvironmentalConditions] as ic
JOIN [dbo].[MeasurementDeviceUnits] as mu ON ic.MeasurementDeviceUnitId = mu.MeasurementDeviceUnitId
WHERE ic.OrderDetailsItemId = r.[OrderDetailsItemId] and ic.IsDeleted = 0
FOR JSON PATH
) as ds(EnvironmentalConditions)
WHERE (@OrderDetailsItems IS NULL OR r.OrderDetailsItemId = @OrderDetailsItems)
ORDER BY [OrderDetailId]
option (maxrecursion 0)