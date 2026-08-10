-- =============================================
-- Proc:        dbo.GetOrderDetailsDevices   (live author: Kate Zashalovska, 18/06/2026)
-- Jira:        MBA-666 "Calibration Item List from Priority"  (earlier: MBA-153 / MBA-41)
--
-- NOTE: the previous version of this file in the repo was STALE - it mirrored an older
-- definition (recursive CTE + 53 columns, authored for MBA-153). The live SP had since been
-- rewritten. This file now mirrors the CURRENTLY DEPLOYED definition on STAGE.
--
-- MBA-666 change (2026-08-10, STAGE only): 5 columns added, 55 -> 60. Requested by Sviatoslav
-- so the Calibration Wizard can show the Calibration Item / device text from Priority:
--     PartDescription      amaba.dbo.PART.PARTDES        (תיאור מכשיר)
--     DeviceFamilyId       amaba.dbo.PART.FAMILY
--     DeviceFamily         amaba.dbo.FAMILY.FAMILYDES    (מאזניים / מד לחץ / תנור ...)
--     TextToCatalogNumber  amaba.dbo.PARTTEXT            (טקסט למק"ט)
--     TextToDevice         amaba.dbo.SERNUMBERSTEXT      (טקסט למכשיר)
-- All five are served from the LOCAL cache (dbo.CrmPartInfo / CrmCatalogText / CrmDeviceText,
-- refreshed by dbo.RefreshCrmTextCache) - no linked-server round-trip on this hot path.
--
-- Which column is the "Calibration Item"? The story's own example ("device defined as Chamber
-- -> calibration item Chamber") matches DeviceFamily, not the long PARTDES. Note also that
-- OrdersProductType (dbo.OrdersProductTypes.OrdersProductTypeName), already returned by this SP,
-- carries the same description as PARTDES but with the digits in the correct order
-- ("מאזניים עד 100 ק'ג" vs PARTDES "מאזניים עד 001 ק'ג") - prefer it for display.
--
-- Verified on STAGE after the change: order 12 -> 4 rows/60 cols (was 4/55); order 982 -> 13/60
-- (same with @LoggedInUserEmail), 0.06-0.14s. Coverage over 3,986 OrderDetails rows:
-- DeviceFamily 100%, PartDescription 100%, TextToCatalogNumber 65%; TextToDevice 20% of 2,579 items.
--
-- Implementation note: this query reaches [OrderDetails] as od THROUGH odi, so a row with no
-- OrderDetailsItem has od = NULL. The part-derived joins therefore hang off a separate alias
-- (odp) keyed on the numbers CTE, otherwise item-less lines (e.g. the נסיעה lines of order 12)
-- would come back with an empty description.
-- =============================================
-- =============================================
-- Author:		Kate Zashalovska
-- Create date: 18/06/2026
-- Description:	
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
cust.[CustomerNameENG],
cust.[CustomerAddress] as [CustAddress],
cust.[CustomerCity] as [CustCity],
cust.[CustomerAddressENG] as [CustAddressENG],
cust.[CustomerCityENG] as [CustCityENG],
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
odi.[CalibrationSpecificationId],
mc.Name as [CalibrationSpecification],
odi.[SpecificationReferenceId],	
sr.[Name] as [SpecificationReference],
odi.[MeasurementUnitId],
mu.ShortNameHe as [MeasurementUnit],
odi.[MeasurementPoints],	
odi.[MeasurementValueList],	
odi.[ProductLocation],
--e.[EquipmentNames], will be deprecated
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
LEFT JOIN [dbo].[MeasurementsSpecifications] mc ON odi.[CalibrationSpecificationId] = mc.ID
LEFT JOIN [dbo].[SpecificationReference] as sr ON odi.[SpecificationReferenceId] = sr.ID
LEFT JOIN [dbo].[MeasurementDeviceUnits] as mu ON odi.[MeasurementUnitId] = mu.MeasurementDeviceUnitId
LEFT JOIN [dbo].[Statuses] as scs ON odi.[CalibrationStatusId] = scs.StatusId
LEFT JOIN [dbo].[Statuses] as stit ON odi.StickerTypeId = stit.StatusId
LEFT JOIN [dbo].[CalibratorsToWorkPlan] as ctwp ON ctwp.[OrderWorkPlanId] = wp.[OrderWorkPlanId] AND ctwp.[CalibratorId] = @LoggedInUserId AND ctwp.IsDeleted = 0
WHERE wp.[OrderWorkPlanId] = @OrderWorkPlanId 
)
SELECT
FIRST_VALUE(r.[OrderWorkPlanId]) OVER(ORDER BY r.[OrderWorkPlanId] DESC) as [OrderWorkPlanId],
FIRST_VALUE(r.[OrderNumber]) OVER(ORDER BY r.[OrderWorkPlanId] DESC) as [OrderNumber],
FIRST_VALUE(r.[CustomerId]) OVER(ORDER BY r.[OrderWorkPlanId] DESC) as [CustomerId],
FIRST_VALUE(r.[CustomerName]) OVER(ORDER BY r.[OrderWorkPlanId] DESC) as [CustomerName],
FIRST_VALUE(r.[CustomerNameENG]) OVER(ORDER BY r.[OrderWorkPlanId] DESC) as [CustomerNameENG],
FIRST_VALUE(COALESCE(r.[OrderDetailId],n.[OrderDetailId])) OVER(PARTITION BY r.[OrderDetailId] ORDER BY r.[OrderDetailId]) as [OrderDetailId],
FIRST_VALUE(COALESCE(r.[OrderLineCnt],n.[OrderLineCnt])) OVER(PARTITION BY r.[OrderDetailId] ORDER BY r.[OrderDetailId]) as [OrderLineCnt],
FIRST_VALUE(COALESCE(r.[OrdersProductTypeId],n.[OrdersProductTypeId])) OVER(PARTITION BY r.[OrderDetailId] ORDER BY r.[OrderDetailId]) as [OrdersProductTypeId],
COALESCE(opt1.[OrdersProductTypeName],opt2.[OrdersProductTypeName]) AS [OrdersProductType],
COALESCE(opt1.[OrdersProductTypeNameENG],opt2.[OrdersProductTypeNameENG]) AS [OrdersProductTypeENG],
r.[OrderDetailsItemId],
r.[ActualCalibrationDate],	
r.[NextCalibrationDate],	
r.[SerialNumber],
r.[ManufacturerNumber],
r.[DeviceModel],
r.[AdditionalDeviceNumber],	
CASE 
	WHEN @IsUserCalibrator = 1 THEN IIF(CHARINDEX(ctwp.OrderDetailsMbaReportNumber,r.[MbaReportNumber] ) <> 0,r.[MbaReportNumber],CONCAT(ctwp.OrderDetailsMbaReportNumber,'',ROW_NUMBER() OVER (PARTITION BY COALESCE(r.[OrderWorkPlanId],n.[OrderWorkPlanId]) ORDER BY r.[OrderWorkPlanId])  ))
ELSE r.[MbaReportNumber]
END as [MbaReportNumber],
r.[MainCategoryId] as [OrdersMainCategoryId],	
r.[OrdersMainCategory],
r.[OrdersSecondaryCategoryId],	
r.[OrdersSecondaryCategory],
r.[CalibrationSpecificationId],	
r.[CalibrationSpecification],
r.[SpecificationReferenceId],	
r.[SpecificationReference],
r.[MeasurementUnitId],
r.[MeasurementUnit],
r.[MeasurementPoints],	
r.[MeasurementValueList],	
r.[ProductLocation],
--r.[EquipmentNames],
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
odi.VisualCheck,
odi.ShouldShowGraphV, 
odi.ShouldShowCertificateIcon,
odi.RequiredProbability,
odi.ReportLanguage,
CONCAT(u.FirstName,' ',u.LastName) as CalibratorFullName,
COALESCE(odi.SiteAddress,cs.CustomerSiteAddress, CONCAT(r.[CustAddress], ', ', r.[CustCity])) as SiteAddress,
COALESCE(cs.CustomerSiteAddressENG, IIF(r.[CustAddressENG] IS NOT NULL AND r.[CustCityENG] IS NOT NULL, CONCAT(r.[CustAddressENG], ', ', r.[CustCityENG]), r.[CustAddressENG])) as SiteAddressENG,
odi.ProductLocation,
odi.[OrdersDeviceManufacturer],
odi.[ControllerType],
odi.[DiagramMapLink],
-- MBA-666: Calibration Item / device description sourced from Priority (amaba.dbo.PART +
-- FAMILY) and the CRM free-text blocks, all served from the local cache refreshed by
-- dbo.RefreshCrmTextCache - no per-request linked-server round-trip.
cpi.[PartDescription]   as [PartDescription],    -- PART.PARTDES  (numbers appear in visual order)
cpi.[FamilyId]          as [DeviceFamilyId],     -- PART.FAMILY
cpi.[FamilyDescription] as [DeviceFamily],       -- FAMILY.FAMILYDES, e.g. מאזניים / מד לחץ / תנור
cct.[CatalogText]       as [TextToCatalogNumber],-- טקסט למק"ט   (PARTTEXT)
cdt.[DeviceText]        as [TextToDevice]        -- טקסט למכשיר  (SERNUMBERSTEXT)
FROM  numbers as n
LEFT JOIN result as r ON  r.OrderDetailId = n.OrderDetailId and r.rn = n.cnt 
LEFT JOIN [dbo].[OrdersProductTypes] as opt1 ON n.[OrdersProductTypeId] = opt1.[OrdersProductTypeId]
LEFT JOIN [dbo].[OrdersProductTypes] as opt2 ON r.[OrdersProductTypeId] = opt2.[OrdersProductTypeId]
LEFT JOIN [dbo].[CalibratorsToWorkPlan] as ctwp ON ctwp.[OrderWorkPlanId] = COALESCE(r.[OrderWorkPlanId],n.[OrderWorkPlanId]) AND ctwp.[CalibratorId] = @LoggedInUserId AND ctwp.IsDeleted = 0
LEFT JOIN [dbo].[OrderDetailsItems] as odi ON n.OrderDetailId = odi.OrderDetailId AND odi.[OrderDetailsItemId] = r.[OrderDetailsItemId]
LEFT JOIN [dbo].[Users] as u ON odi.MainCalibratorId = u.ID
LEFT JOIN [dbo].[OrderDetails] as od ON od.OrderDetailId = odi.OrderDetailId
LEFT JOIN [dbo].[CustomerSites] as cs ON od.CustomerSiteId = cs.CustomerSiteId
-- od is reached through odi here, so rows with no item would lose the part data;
-- join OrderDetails straight off the numbers CTE instead.
LEFT JOIN [dbo].[OrderDetails]   as odp ON odp.OrderDetailId = n.OrderDetailId
LEFT JOIN [dbo].[CrmPartInfo]    as cpi ON cpi.PART = odp.PART
LEFT JOIN [dbo].[CrmCatalogText] as cct ON cct.PART = odp.PART
LEFT JOIN [dbo].[CrmDeviceText]  as cdt ON cdt.SERN = odi.SERN
OUTER APPLY
(
SELECT 
	ShortNameEn as MeasurementDeviceUnitEn,
	ShortNameHe as MeasurementDeviceUnitHeb,
	ic.NominalValue,
	ic.Tolerance,
	ic.MinToleranceBorder,
	ic.MaxToleranceBorder
FROM [dbo].[CalibrationEnvironmentalConditions] as ic
JOIN [dbo].[MeasurementDeviceUnits] as mu ON ic.MeasurementDeviceUnitId = mu.MeasurementDeviceUnitId
WHERE ic.OrderDetailsItemId = r.[OrderDetailsItemId] and ic.IsDeleted = 0
FOR JSON PATH
) as ds(EnvironmentalConditions)
WHERE (@OrderDetailsItems IS NULL OR r.OrderDetailsItemId = @OrderDetailsItems)
ORDER BY [OrderDetailId]
option (maxrecursion 0)
    