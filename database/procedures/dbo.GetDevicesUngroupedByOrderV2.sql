CREATE PROCEDURE [dbo].[GetDevicesUngroupedByOrderV2]
    @OrderNumber NVARCHAR(20) = NULL,
    @MainCategories NVARCHAR(MAX) = NULL,
    @SecondaryCategories NVARCHAR(MAX) = NULL,
    @DeviceManufacturer NVARCHAR(50) = NULL,
    @DeviceModels NVARCHAR(MAX) = NULL,
    @GlobalSearch NVARCHAR(MAX) = NULL,
    @Page NVARCHAR(100) = 'coordinator-orders',
    @PageNumber AS INT = 1,
    @RowsOfPage AS INT = 10,
    @OrderBy AS NVARCHAR(MAX) = 'OrderNumber',
    @OrderByAsc AS BIT = 1,
    @OrderWorkPlanIds NVARCHAR(MAX) = NULL,
    @OrderWorkDetailsItemsIds NVARCHAR(MAX) = NULL,
    @ExcludeAwaitingCollectionOrders BIT = 0
AS
BEGIN
SET NOCOUNT ON;

DECLARE @ExtIntFilter BIT = NULL

IF @Page IN (N'external-schedule', N'external-orders', N'coordinator-orders') SET @ExtIntFilter = 0
IF @Page IN (N'internal-orders') SET @ExtIntFilter = 1

IF @ExcludeAwaitingCollectionOrders = 1
BEGIN
    DROP TABLE IF EXISTS #AwaitingCollectionOrders
    CREATE TABLE #AwaitingCollectionOrders(OrderWorkPlanId INT)

    INSERT #AwaitingCollectionOrders(OrderWorkPlanId)
    SELECT wp.OrderWorkPlanId
    FROM [dbo].[OrderWorkPlans] as wp
    JOIN Statuses as s ON wp.OrderOverallStatusId = s.StatusId
    WHERE s.StatusDescriptionENG = 'AwaitingCollection'

    CREATE UNIQUE CLUSTERED INDEX IDX_AwaitingCollectionOrders
    ON #AwaitingCollectionOrders(OrderWorkPlanId)
END

DROP TABLE IF EXISTS #MainCategories
CREATE TABLE #MainCategories(MainCategory NVARCHAR(50))

INSERT #MainCategories(MainCategory)
SELECT DISTINCT CAST(v.Value AS NVARCHAR(50))
FROM dbo.ParseCSVToTable(@MainCategories) as v

DROP TABLE IF EXISTS #SecondaryCategories
CREATE TABLE #SecondaryCategories(SecondaryCategory NVARCHAR(50))

INSERT #SecondaryCategories(SecondaryCategory)
SELECT DISTINCT v.Value
FROM dbo.ParseCSVToTable(@SecondaryCategories) as v

DROP TABLE IF EXISTS #DeviceModels
CREATE TABLE #DeviceModels(DeviceModel NVARCHAR(30))

INSERT #DeviceModels(DeviceModel)
SELECT DISTINCT v.Value
FROM dbo.ParseCSVToTable(@DeviceModels) as v

DECLARE @StatusesForOrders NVARCHAR(MAX)

SELECT @StatusesForOrders = STRING_AGG(s.StatusId, ',')
FROM [dbo].[Statuses] as s
JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
WHERE sc.StatusDescriptionENG = 'OrderStatus'
  AND s.StatusDescriptionENG <> 'Executed'

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
N'SELECT
     IIF(', COALESCE(CAST(@ExtIntFilter AS NVARCHAR(1)), N'0'), N' = 1, itm.MbaReportNumber, op.OrderNumber) as OrderNumber
    ,od.OrderWorkPlanId as OrderId
    ,od.OrderDetailId
    ,itm.OrderDetailsItemId
    ,od.PART as CatalogPartId
    ,od.PartName as CatalogNumber
    ,itm.SERN
    ,opt.OrdersProductTypeName AS DeviceType
    ,mc.ID AS DepartmentId
    ,mc.MainCategoryName as MainCategory
    ,sc.SecondaryCategoryName AS SecondCategory
    ,itm.SerialNumber
    ,itm.AdditionalDeviceNumber
    ,itm.DeviceModel
    ,itm.MbaReportNumber
    ,itm.OrdersDeviceManufacturer as DeviceManufacturer
    ,cals.[StatusDescriptionHEB] as CalibrationStatus
    ,ordst.[StatusDescriptionHEB] as OrderStatus
    ,ordst.[StatusDescriptionENG] as OrderStatusENG
    ,itm.[IsChecked]
    ,op.[CustomerId]
    ,itm.[ActualCalibrationDate]
    ,itm.ExpectedReturnDate as CalibrationDeadline
    ,c.CustomerName
    ,cbl.Calibrators
    ,scs.StatusDescriptionHEB as SpecialTreatment
    ,itm.CustomerReceivingDate
    ,itm.ShippingDoc
    ,itm.ShippingAddress
    ,c.CustomerAddress
    ,custeqv.details as AdditionalEquipment
    ,op.ShipTypeDesc as ShippingMethod
    ,itm.[StickerAmount]
    ,stist.[StatusDescriptionHEB] as [StickerType]
    ,ct.CatalogText as TextToCatalogNumber
    ,dt.DeviceText as TextToDevice
    ,op.CustomerComment
    ,COUNT(1) OVER() as ItemsCount
FROM [dbo].[OrderDetails] as od
JOIN [dbo].[OrderWorkPlans] as op ON od.OrderWorkPlanId = op.OrderWorkPlanId
LEFT JOIN [dbo].[Statuses] as scs ON od.SpecialCareTypeId = scs.StatusId
LEFT JOIN [dbo].[OrderDetailsItems] as itm ON itm.OrderDetailId = od.OrderDetailId
LEFT JOIN [dbo].[Customers] as c ON op.[CustomerId] = c.[CustomerId]
LEFT JOIN [dbo].[MainCategories] as mc ON od.MainCategoryId = mc.ID
LEFT JOIN [dbo].[SecondaryCategories] sc ON od.SecondaryCategoryId = sc.ID
LEFT JOIN [dbo].[OrdersProductTypes] as opt ON od.OrdersProductTypeId = opt.OrdersProductTypeId
LEFT JOIN [dbo].[Statuses] as cals ON cals.[StatusId] = itm.[CalibrationStatusId]
LEFT JOIN [dbo].[Statuses] as ordst ON ordst.[StatusId] = op.[OrderOverallStatusId]
LEFT JOIN [dbo].[Statuses] as stist ON stist.[StatusId] = itm.[StickerTypeId]
LEFT JOIN [dbo].[CrmCatalogText] as ct ON ct.PART = od.PART
LEFT JOIN [dbo].[CrmDeviceText] as dt ON dt.SERN = itm.SERN

OUTER APPLY
(
    SELECT
        [OrderWorkPlanId],
        STRING_AGG(CONCAT(u.FirstName, '' '', u.LastName), '','') as Calibrators
    FROM [dbo].[CalibratorsToWorkPlan] as c
    JOIN [dbo].[Users] as u ON c.[CalibratorId] = u.[ID]
    WHERE op.OrderWorkPlanId = c.[OrderWorkPlanId]
    GROUP BY [OrderWorkPlanId]
) as cbl

OUTER APPLY
(
    SELECT
        d.OrderDetailsItemId,
        ''['' +
        STRING_AGG(
            CONCAT(
                ''{'',
                ''"ItemsCount":'', d.[ItemsCount], '','',
                ''"AccessoryDescription":'', ''"'', d.[AccessoryDescription], ''","'',
                ''"AccessoryLocation":'', ''"'', d.[AccessoryLocation], ''"'',
                ''}''
            ),
            '',''
        )
        + '']'' AS details
    FROM [dbo].[ClientAccessoryOrderDetailsItems] AS d
    WHERE d.OrderDetailsItemId = itm.OrderDetailsItemId
    GROUP BY d.OrderDetailsItemId
) as custeqv
'
,IIF(@OrderWorkPlanIds IS NOT NULL, N' JOIN STRING_SPLIT(''' + @OrderWorkPlanIds + N''', '','') as wpf ON op.OrderWorkPlanId = wpf.value', N' ')
,IIF(@OrderWorkDetailsItemsIds IS NOT NULL, N' JOIN STRING_SPLIT(''' + @OrderWorkDetailsItemsIds + N''', '','') as wpf1 ON itm.OrderDetailsItemId = wpf1.value', N' ')
,IIF(@MainCategories IS NOT NULL, N' JOIN #MainCategories as mcf ON mc.MainCategoryName COLLATE DATABASE_DEFAULT = mcf.MainCategory COLLATE DATABASE_DEFAULT', N' ')
,IIF(@SecondaryCategories IS NOT NULL, N' JOIN #SecondaryCategories as scf ON sc.SecondaryCategoryName COLLATE DATABASE_DEFAULT = scf.SecondaryCategory COLLATE DATABASE_DEFAULT ', N' ')
,IIF(@DeviceModels IS NOT NULL, N' JOIN #DeviceModels as dm ON itm.DeviceModel COLLATE DATABASE_DEFAULT = dm.DeviceModel COLLATE DATABASE_DEFAULT ', N' ')
,N'
WHERE op.OrderOverallStatusId IN(', @StatusesForOrders, N')
'
,IIF(@ExcludeAwaitingCollectionOrders = 1, N'AND NOT EXISTS (SELECT 1 FROM #AwaitingCollectionOrders as f WHERE f.OrderWorkPlanId = op.OrderWorkPlanId)', N'')
,IIF(@OrderNumber IS NOT NULL, N'AND op.OrderNumber = TRIM(''' + @OrderNumber + N''')', N' ')
,IIF(@DeviceManufacturer IS NOT NULL, N'AND itm.OrdersDeviceManufacturer LIKE ''%' + @DeviceManufacturer + N'%''', N' ')
,CASE WHEN @ExtIntFilter IS NOT NULL THEN N' AND od.IsInHouse=' + CAST(@ExtIntFilter as NVARCHAR(MAX)) + N' ' ELSE N' ' END
,CASE WHEN @GlobalSearch IS NOT NULL THEN
    N' AND CONCAT(op.OrderNumber,opt.OrdersProductTypeName,mc.MainCategoryName,sc.SecondaryCategoryName,itm.SerialNumber,itm.AdditionalDeviceNumber,itm.DeviceModel,itm.MbaReportNumber,itm.OrdersDeviceManufacturer,cals.[StatusDescriptionHEB],c.CustomerName,cbl.Calibrators,scs.StatusDescriptionHEB,od.PART,od.PartName,itm.SERN,ct.CatalogText,dt.DeviceText,op.CustomerComment) LIKE N''%' + @GlobalSearch + N'%'''
 ELSE N' ' END
,N'ORDER BY ', @OrderBy,
  CASE WHEN @OrderByAsc = 1 THEN N' ASC' WHEN @OrderByAsc = 0 THEN N' DESC' ELSE N'' END,
  N' OFFSET ', (@PageNumber - 1) * @RowsOfPage,
  N' ROWS FETCH NEXT ', @RowsOfPage,
  N' ROWS ONLY OPTION(RECOMPILE); '
)

PRINT @sql
EXEC sp_executesql @sql

END