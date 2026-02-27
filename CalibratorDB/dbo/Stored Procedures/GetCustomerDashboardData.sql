-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 26/02/2026
-- Description:	Get customer dashboad data
-- =============================================
CREATE   PROCEDURE dbo.GetCustomerDashboardData
@PageNumber AS INT = 1,                  -- Resulting page for pagination, starting in 1
@RowsOfPage AS INT = 50,                 -- Result page size
@OrderBy AS NVARCHAR(MAX) = 'CalibratioinDate',      -- OrderBy column
@OrderByAsc AS BIT = 0,                  -- OrderBy direction (ASC/DESC)
@LoggedInUserEmail NVARCHAR(50),
@GlobalSearch NVARCHAR(200) = NULL
AS

DECLARE @LoggedInUserId INT = 0
DECLARE @SourceId TINYINT

SELECT 
	@LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

DROP TABLE IF EXISTS #CustomerOrdersIds
CREATE TABLE #CustomerOrdersIds
(
OrderWorkPlanId INT NOT NULL
)

INSERT #CustomerOrdersIds(OrderWorkPlanId)
SELECT wp.OrderWorkPlanId
FROM [dbo].[OrderWorkPlans] as wp
WHERE wp.[CustomerId] = 2159--@LoggedInUserId

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'
;WITH ds
AS
(
SELECT 
COALESCE(clst.StatusDescriptionHEB,N'''+N'מחכה לכיול'+''') as DeviceStatus
,itm.ActualCalibrationDate as CalibratioinDate
,od.OrderWorkPlanId
,IIF(od.IsInHouse = 1,N'''+N'מעבדה'+''',N'''+N'לקוח'+''') as CalibratioinLocation
,pt.OrdersProductTypeName as DeviceDescription
,itm.SerialNumber
,itm.ActualReturnDate
,od.CalibratorId
,u.FirstName as CalibratorFirstName
,u.LastName as CalibratorLastName
,u.Phone as CalibratorPhoneNumber
,ctwp.AssigmentDate as CalibratorAssigmentDate
,ROW_NUMBER() OVER( PARTITION BY itm.SerialNumber ORDER BY wp.OrderWorkPlanId DESC) as IsLatestOrder
FROM 
[dbo].[OrderWorkPlans] as wp
JOIN #CustomerOrdersIds as f ON wp.OrderWorkPlanId = f.OrderWorkPlanId
JOIN [dbo].[OrderDetails] as od ON wp.OrderWorkPlanId = od.OrderWorkPlanId
LEFT JOIN [dbo].[OrderDetailsItems] as itm ON itm.OrderDetailId = od.OrderDetailId
LEFT JOIN [dbo].[Customers] as c ON wp.[CustomerId] = c.[CustomerId]
LEFT JOIN [dbo].[Statuses] as clst ON itm.[CalibrationStatusId] = clst.[StatusId]
LEFT JOIN [dbo].[MainCategories] as mcf ON od.MainCategoryId	= mcf.ID
LEFT JOIN [dbo].[Users] as u ON od.CalibratorId = u.[ID]
LEFT JOIN [dbo].[CalibratorsToWorkPlan] as ctwp ON ctwp.[OrderWorkPlanId] = wp.[OrderWorkPlanId] AND ctwp.[CalibratorId] = od.CalibratorId AND ctwp.IsDeleted = 0
LEFT JOIN [dbo].[SecondaryCategories] as scf ON od.SecondaryCategoryId = scf.ID
LEFT JOIN [dbo].[CustomerSites] as css ON css.CustomerSiteId = od.CustomerSiteId
LEFT JOIN [dbo].[OrdersProductTypes] as pt ON od.OrdersProductTypeId = pt.OrdersProductTypeId
--WHERE wp.[CustomerId] = 2159
),
devices_cnt
AS
(
SELECT 
d.DeviceStatus
,d.CalibratioinDate
,d.CalibratioinLocation
,d.DeviceDescription
,d.SerialNumber
,d.ActualReturnDate
,d.CalibratorId
,d.CalibratorFirstName
,d.CalibratorLastName
,d.CalibratorPhoneNumber
,d.CalibratorAssigmentDate
,d.IsLatestOrder
,SUM(IIF(d.IsLatestOrder = 1,1,NULL)) OVER( ORDER BY d.DeviceStatus) as OverallDevicesCount
,SUM(IIF(d.IsLatestOrder = 1 AND COALESCE(d.CalibratioinDate,''1900-01-01'') < GETDATE(),1,NULL)) OVER( ORDER BY d.DeviceStatus) as ExpiredevicesCount
,COALESCE(SUM(IIF(d.IsLatestOrder = 1 AND d.CalibratioinDate > GETDATE(),1,NULL)) OVER( ORDER BY d.DeviceStatus),0) as CalibratedDevicesCount
,COALESCE(SUM(IIF(d.IsLatestOrder = 1 AND d.DeviceStatus=N'''+N'מחכה לכיול'+''',1,NULL)) OVER( ORDER BY d.DeviceStatus),0) as DevicesWaitingForCalibrationCount
FROM ds as d
)
SELECT 
ds.DeviceStatus
,ds.CalibratioinDate
,ds.CalibratioinLocation
,ds.DeviceDescription
,ds.SerialNumber
,ds.ActualReturnDate
,ds.CalibratorId
,ds.CalibratorFirstName
,ds.CalibratorLastName
,ds.CalibratorPhoneNumber
,ds.CalibratorAssigmentDate
,ds.OverallDevicesCount
,ds.ExpiredevicesCount
,ds.CalibratedDevicesCount
,ds.DevicesWaitingForCalibrationCount
,SUM(IsLatestOrder) OVER( ORDER BY ds.DeviceStatus) as ItemsCount
FROM devices_cnt as ds
WHERE ds.IsLatestOrder = 1'
,CASE WHEN @GlobalSearch IS NOT NULL THEN ' AND CONCAT(ds.DeviceDescription,ds.SerialNumber,ds.CalibratorFirstName,ds.CalibratorLastName,ds.CalibratorPhoneNumber) LIKE N''%'+ @GlobalSearch +'%'''ELSE ' ' END
,'ORDER BY ' , @OrderBy , CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END , ' OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')


 PRINT LEN(@sql)
PRINT CAST(@sql as VARCHAR(MAX))
EXEC (@sql)