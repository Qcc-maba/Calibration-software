-- Mirrors the definition deployed on STAGE (Calibrator) as of 2026-10-26 (MBA-1002),
-- plus the three MBA-802 humidity columns, already on STAGE but not yet in this file on develop,
-- plus SpecificationReferenceEn (MBA-623), which goes to STAGE with that ticket.
-- Regenerated from the live object; see the in-body comments for what each change does
-- and why. Do not hand-edit without redeploying — this file is a mirror, not the source.
-- =============================================
-- Author:		Kate Zashalovska
-- Create date: 18/06/2026
-- Description:	
-- JiraLink: 
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[GetOrderDetailsDevices]
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

-- MBA-1002: the calibrator's MABA prefix on this work plan, and the highest number already used with it
-- on any live device. A generated MABA No continues after that number: numbering by slot position gave
-- 39 empty slots on PROD (2026-10-26) a number another device already carried.
DECLARE @MbaPrefix NVARCHAR(200), @MbaPrefixMaxNo INT = 0
IF @IsUserCalibrator = 1
BEGIN
	SELECT TOP 1 @MbaPrefix = NULLIF(LTRIM(RTRIM(ctwp.OrderDetailsMbaReportNumber)), '')
	FROM [dbo].[CalibratorsToWorkPlan] as ctwp
	WHERE ctwp.[OrderWorkPlanId] = @OrderWorkPlanId AND ctwp.[CalibratorId] = @LoggedInUserId AND ctwp.IsDeleted = 0
	ORDER BY ctwp.[OrderDetailsMbaReportNumber] DESC

	IF @MbaPrefix IS NOT NULL
		SELECT @MbaPrefixMaxNo = ISNULL(MAX(TRY_CAST(SUBSTRING(i.MbaReportNumber, LEN(@MbaPrefix) + 2, 20) AS INT)), 0)
		FROM [dbo].[OrderDetailsItems] as i
		WHERE ISNULL(i.IsDeleted, 0) = 0
		  AND LEFT(i.MbaReportNumber, LEN(@MbaPrefix) + 1) = @MbaPrefix + N'/'
END


;WITH numbers
as
(
-- MBA: a line gets as many slots as it has devices, never fewer than OrderLineCnt. The
-- recursion used to stop at OrderLineCnt, so a line carrying more items than its count
-- (32476 on LA26103958: count 1, items 11058 and 11059) silently dropped the surplus item,
-- and the wizard opened it to 'no items'.
SELECT 1 as cnt, od.OrderLineCnt, od.OrderDetailId, od.OrdersProductTypeId, od.OrderWorkPlanId,
       Slots = CASE WHEN ic.ItemCount > ISNULL(od.OrderLineCnt, 0) THEN ic.ItemCount ELSE ISNULL(od.OrderLineCnt, 0) END
FROM [dbo].[OrderDetails] as od 
OUTER APPLY (SELECT ItemCount = COUNT(*) FROM [dbo].[OrderDetailsItems] AS i
             WHERE i.OrderDetailId = od.OrderDetailId AND ISNULL(i.IsDeleted, 0) = 0) AS ic
WHERE od.OrderWorkPlanId = @OrderWorkPlanId
UNION ALL
SELECT n.cnt +1, od.OrderLineCnt, od.OrderDetailId, od.OrdersProductTypeId, od.OrderWorkPlanId, n.Slots
FROM numbers as n
JOIN [dbo].[OrderDetails] as od ON od.OrderDetailId = n.OrderDetailId AND od.OrderLineCnt = n.OrderLineCnt
WHERE od.OrderWorkPlanId = @OrderWorkPlanId
AND n.cnt < n.Slots
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
sr.[NameEn] as [SpecificationReferenceEn], -- MBA-623: the name on an English report
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
-- MBA-1002: ordered by item, not by the partition column, so a device keeps its slot (and the MABA No
-- generated from that slot's position) between loads.
ROW_NUMBER() OVER( PARTITION BY odi.OrderDetailId ORDER BY odi.OrderDetailsItemId) as rn
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
,
-- MBA-1002: each unnumbered slot's place among all the work plan's unnumbered slots, counted here rather
-- than in the final SELECT, whose WHERE narrows to one device when @OrderDetailsItems is passed (the app
-- does), which would make every device "first".
mbaGen as
(
SELECT n.OrderDetailId, n.cnt,
       ROW_NUMBER() OVER (ORDER BY IIF(NULLIF(LTRIM(RTRIM(r.[MbaReportNumber])), '') IS NULL, 0, 1), n.OrderDetailId, n.cnt) as GenNo
FROM numbers as n
LEFT JOIN result as r ON r.OrderDetailId = n.OrderDetailId and r.rn = n.cnt
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
-- MBA-1002: build the MABA No from the calibrator's prefix only when there is a prefix. With no
-- assignment on the work plan, or an empty OrderDetailsMbaReportNumber, CHARINDEX(NULL, ...) is NULL,
-- the IIF fell to CONCAT(NULL, '', n), and page 1 showed and then saved a bare row number ('1', '2')
-- over the device's real MABA No. On STAGE 2026-10-26, 17 of 21 live assignments had no prefix.
-- MBA-1002 (approved 2026-10-26): a device that already has a MABA No keeps it; before, a stored
-- number without the prefix was replaced by prefix + n, and page 1 saved that over Priority's number.
-- A generated number gets the '/' that 8,585 of 8,668 live devices use (the prefix is stored without
-- it, and the validator screens list only NNNNNNN/x), and is numbered by line and slot: the old
-- ROW_NUMBER was ordered by the column it was partitioned by, so the number could change between loads.
-- Approved 2026-10-28: the number is @MbaPrefixMaxNo + the slot's place among the unnumbered slots, so it
-- never repeats one in use, and saving the first slot leaves the next slot's number unchanged.
CASE
	WHEN @MbaPrefix IS NOT NULL
	 AND NULLIF(LTRIM(RTRIM(r.[MbaReportNumber])), '') IS NULL
	THEN CONCAT(@MbaPrefix, '/', @MbaPrefixMaxNo + g.GenNo)
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
r.[SpecificationReferenceEn],
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
-- MBA-855: the Identification screen reads these three, and AssignProductIdentificationData
-- writes them, but they were never returned, so the screen opened with them empty (STAGE item
-- 2371 stores Reference Documents '14' and showed none). Saving the screen then wrote the empty
-- list back.
odi.[SpecificationReferenceIds],
odi.[Tolerance],
odi.[Resolution],
-- MBA-802: the humidity set of a humidity device (its unit is always %RH). NULL on every other device.
odi.[HumidityAccuracy],
odi.[HumidityTolerance],
odi.[HumidityResolution],
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
LEFT JOIN mbaGen as g ON g.OrderDetailId = n.OrderDetailId AND g.cnt = n.cnt
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
-- resolve by CATALOG NUMBER: OrderDetails.PART is wrong on 169 lines (it points at a different
-- Priority product), while PartName is authoritative and PART.PARTNAME is unique.
LEFT JOIN [dbo].[CrmPartInfo]    as cpi ON cpi.PartName = odp.PartName
LEFT JOIN [dbo].[CrmCatalogText] as cct ON cct.PART     = cpi.PART
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
    