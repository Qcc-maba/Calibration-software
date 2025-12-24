

-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 03/04/2025
-- Description:	Get work plan data
-- =============================================
CREATE   PROCEDURE [dbo].[GetWorkPlanData]
    @PageNumber AS INT = 1,                  -- Resulting page for pagination, starting in 1
    @RowsOfPage AS INT = 1000,                 -- Result page size
    @OrderBy AS NVARCHAR(MAX) = 'OrderNumber',      -- OrderBy column
    @OrderByAsc AS BIT = 1,                  -- OrderBy direction (ASC/DESC)
    -- Filter parameters (all nullable)
	@ClientName NVARCHAR(255) = NULL,
	@Date DATE = NULL,
	@MainCategory NVARCHAR(100) = NULL,
	@SecondCategory NVARCHAR(100) = NULL,
	@Location NVARCHAR(100) = NULL,
	@ProductType NVARCHAR(100) = NULL,
	@ProducedIn NVARCHAR(255) = NULL,
	@DeviceModel NVARCHAR(100) = NULL,
	@DateFrom DATETIME2(0) = NULL,
	@DateTo DATETIME2(0) = NULL,
	@DeviceNumber NVARCHAR(20) = NULL,
	@DeviceManufacturer NVARCHAR(255) = NULL,
	@AssignedCalibratorsIds NVARCHAR(MAX) = NULL, -- -1 means that we should include orders with empty calibrator
	@EquipmentIds NVARCHAR(MAX) = NULL,
	@SpecialCareTypeIds NVARCHAR(255) = NULL,
	@OrderNumber NVARCHAR(MAX) = NULL,
	@GlobalSearch NVARCHAR(200) = NULL,
	@WorkPlanOpenDate DATETIME2(0) = NULL,
	@CarsIds NVARCHAR(MAX) = NULL,
	@Notes NVARCHAR(255) = NULL,
	@Page NVARCHAR(100),
	@LoggedInUserEmail NVARCHAR(50) = NULL,
	@ExcludeRejectedOrders BIT = 0
AS

BEGIN
    SET NOCOUNT ON;
	SET ANSI_WARNINGS OFF;

	DECLARE @LoggedInUserId INT = 0
	DECLARE @SourceId TINYINT

	SELECT 
	 @LoggedInUserId  = d.UserId 
	,@SourceId = d.SourceId
	FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

	/*
	Filter logic by page
	/coordinator-orders - @page = ‘coordinator-orders’ 
	/external-schedule - @page = ‘external-schedule’
	/internal-orders - @page = ‘internal-orders’
	/calibration-wizard - @page = ‘calibration-wizard’ 
	/external-orders - @page = 'external-orders'
	*/
	/*-------------------------------------------------*/
	DECLARE @ExtIntFilter BIT = NULL

	IF @Page IN (N'external-schedule',N'external-orders',N'coordinator-orders') SET @ExtIntFilter = 0 -- IsInHouse = 0 for external orders

	IF @Page IN (N'internal-orders') SET @ExtIntFilter = 1 -- IsInHouse = 0 for internal orders
	--validator-orders
	/*-------------------------------------------------*/

	--IF @OrderBy NOT IN 
	--(N'OrderNumber',N'SpecialCares',N'ClientName',N'Location',N'WorkPlanOpenDate',
	--N'Cars',N'Calibrators',N'EquipmentNames',N'Notes',N'MainCategory',N'CalibDate',N'ClientConfirmationStatus',N'ExpectedReturnDate',
	--N'ActualReturnDate',N'CustomerPackingExists',N'PrintedReport',N'ReceivingDate',N'WorkPlanStatus')
	--THROW 51000, 'Incorrect value for parameter @OrderBy. Available values |OrderNumber|SpecialCares|ClientName|
	--ExpectedReturnDate|ActualReturnDate
	--|Location|WorkPlanOpenDate|Cars|Calibrators|EquipmentNames|Notes|MainCategory|CalibDate|ClientConfirmationStatus', 1;

	IF @OrderBy IN (N'Cars')
		BEGIN
		SET @OrderBy = CONCAT(N'IIF([Cars] IS NULL,0,1) ',CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END ,N' ,IIF([Calibrators] IS NULL,0,1)', N' ,IIF([EquipmentNames] IS NULL,0,1)')

		SET @OrderByAsc = NULL
		END

	IF @OrderBy IN (N'Calibrators')
		BEGIN
		SET @OrderBy = CONCAT(N' IIF([Cars] IS NULL,0,1) DESC',N' ,IIF([Calibrators] IS NULL,0,1) ',CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END , N' ,IIF([EquipmentNames] IS NULL,0,1)')

		SET @OrderByAsc = NULL
		END

	IF @OrderBy IN (N'EquipmentNames')
		BEGIN
		SET @OrderBy = CONCAT(N' IIF([Cars] IS NULL,0,1) DESC',N' ,IIF([Calibrators] IS NULL,0,1) DESC', N' ,IIF([EquipmentNames] IS NULL,0,1)',CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END )

		SET @OrderByAsc = NULL
		END	


	DROP TABLE IF EXISTS #AssignedCalibrators
	CREATE TABLE #AssignedCalibrators
	(
	[OrderWorkPlanId] INT
	)
	INSERT #AssignedCalibrators([OrderWorkPlanId])
	SELECT DISTINCT wp.OrderWorkPlanId FROM dbo.ParseCSVToTable(@AssignedCalibratorsIds) as f
	JOIN [dbo].[CalibratorsToWorkPlan] as wp ON wp.CalibratorId = f.Value and wp.IsDeleted = 0
	
	IF EXISTS (SELECT 1 FROM dbo.ParseCSVToTable(@AssignedCalibratorsIds) WHERE [Value] = -1)
	INSERT #AssignedCalibrators([OrderWorkPlanId])
	SELECT DISTINCT wp.[OrderWorkPlanId]
	FROM [dbo].[OrderWorkPlans] as wp
	LEFT JOIN [dbo].[CalibratorsToWorkPlan] as cwp ON wp.OrderWorkPlanId = cwp.OrderWorkPlanId and cwp.IsDeleted = 0
	WHERE wp.IsCancelled = 0 AND cwp.OrderWorkPlanId IS NULL

	DROP TABLE IF EXISTS #EquipmentId
	CREATE TABLE #EquipmentId
	(
	[OrderWorkPlanId] INT
	)
	INSERT #EquipmentId([OrderWorkPlanId])
	SELECT DISTINCT ce.OrderWorkPlanId FROM dbo.ParseCSVToTable(@EquipmentIds) as f
	JOIN [dbo].[MeasurementDevicesToOrderHeaders] as ce ON ce.MeasurementDeviceId = f.Value and ce.IsDeleted = 0
	
	DROP TABLE IF EXISTS #CarsIds
	CREATE TABLE #CarsIds
	(
	[OrderWorkPlanId] INT
	)
	INSERT #CarsIds([OrderWorkPlanId])	
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@CarsIds,',') as sp
    JOIN [dbo].[CarsToOrder] as c ON sp.value = c.CarId
	JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderWorkPlanId = c.OrderWorkPlanId
	WHERE wp.IsCancelled = 0 AND c.IsDeleted = 0 

	DROP TABLE IF EXISTS #SpecialCareTypes
	CREATE TABLE #SpecialCareTypes
	(
	[SpecialCareTypeId] INT
	)
	INSERT #SpecialCareTypes([SpecialCareTypeId])
	SELECT DISTINCT f.Value FROM dbo.ParseCSVToTable(@SpecialCareTypeIds) as f

	IF @MainCategory IS NOT NULL
	BEGIN
	DROP TABLE IF EXISTS #MainCategory
	CREATE TABLE #MainCategory
	(
	[ID] INT
	)
	INSERT #MainCategory([ID])
	SELECT ID FROM [dbo].[MainCategories] as mc WHERE mc.MainCategoryName LIKE CONCAT('%',@MainCategory,'%')
	END

	IF @SecondCategory IS NOT NULL
	BEGIN
	DROP TABLE IF EXISTS #SecondCategory
	CREATE TABLE #SecondCategory
	(
	[ID] INT
	)
	INSERT #SecondCategory([ID])
	SELECT ID FROM [dbo].[SecondaryCategories] as sc WHERE sc.SecondaryCategoryName LIKE CONCAT('%',@SecondCategory,'%')
	END

	DECLARE @ClientConfirmationStatusDefault NVARCHAR(50)
	SELECT
	    @ClientConfirmationStatusDefault = s.StatusDescriptionENG
	FROM [dbo].[StatusesCategories] as c
	JOIN [dbo].[Statuses] as s ON c.StatusCategoryId = s.StatusCategoryId
	WHERE c.StatusDescriptionENG = N'ClientConfirmationStatus' AND s.StatusDescriptionENG = N'Pending'

	DECLARE @StatusesForOrders NVARCHAR(MAX)

	SELECT @StatusesForOrders=STRING_AGG(s.StatusId,',')
	FROM [dbo].[Statuses] as s
	JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
	WHERE sc.StatusDescriptionENG='OrderStatus' AND s.StatusDescriptionENG <> 'Executed'

	DROP TABLE IF EXISTS #OrderNumbers
	CREATE TABLE #OrderNumbers
	(
	[OrderWorkPlanId] INT
	)
	INSERT #OrderNumbers([OrderWorkPlanId])	
	SELECT DISTINCT wp.[OrderWorkPlanId] 
	FROM STRING_SPLIT(@OrderNumber,',') as sp
	JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderNumber = sp.value
	WHERE wp.IsCancelled = 0 


	IF @ExcludeRejectedOrders = 1
	BEGIN
		DECLARE @ClientConfirmationStatus NVARCHAR(MAX)

		SELECT @ClientConfirmationStatus=STRING_AGG(s.StatusId,',')
		FROM [dbo].[Statuses] as s
		JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
		WHERE sc.StatusDescriptionENG='ClientConfirmationStatus' AND s.StatusDescriptionENG = 'Rejected'
	END

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'SELECT wp.[OrderNumber] AS [OrderNumber],
        wp.AssigmentDate AS [CalibDate],
		wp.[CustomerId] as [CustomerId], 
		wp.[OrderWorkPlanId],
        spc.[SpecialCares],
        c.[CustomerName] as [ClientName],
        IIF(css.CustomerSiteId IS NOT NULL,CONCAT_WS('', '',css.CustomerSiteAddress,css.CustomerSiteState,css.CustomerSiteZIP), CONCAT_WS('', '',c.CustomerAddress, c.CustomerCity)) as [Location],
        wp.[WorkPlanOpenDate] as [WorkPlanOpenDate],
		sp.StatusDescriptionENG AS SpecialCareENG,
		sp.StatusDescriptionHEB AS SpecialCareHEB, 
        co.[Cars],
        coh.EquipmentIds,
		coh.EquipmentNames,
		cwp.Calibrators,
        wp.Notes as Notes,
		MIN(mcat.[MainCategoryName]) as MainCategory,
		wp.[IsCancelled],
		MAX(CAST(od.CustomerPackingExists as TINYINT)) as CustomerPackingExists,
		MAX(itm.ExpectedReturnDate) as ExpectedReturnDate,
		MAX(itm.ActualReturnDate) as ActualReturnDate,
		COALESCE(MIN(ctwp.OrderDetailsMbaReportNumber),MIN(ctwpdef.OrderDetailsMbaReportNumber))as CalibratorMabaNumber, 
	    COALESCE(MAX(clst.StatusDescriptionENG),''',@ClientConfirmationStatusDefault,''') as ClientConfirmationStatus,
		MAX(wp.ShipTypeDesc) AS ShipTypeDesc,
		MAX(c.ReportRequired) AS PrintedReport,
		MAX(wp.CreatedDate) AS ReceivingDate,
		MAX(wpstat.StatusDescriptionENG) AS WorkPlanStatus,
		MAX(wp.CustomerComment) as CustomerComment,
		wp.AssigmentDate AS [PlacementDate],
		MIN(boxcnt.BoxesCount) as BoxesCount,
		COUNT(1) OVER(PARTITION BY 1 ORDER BY wp.[OrderNumber] ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as ItemsCount
    FROM [dbo].[OrderWorkPlans] as wp'
	,IIF(@AssignedCalibratorsIds IS NOT NULL,' JOIN #AssignedCalibrators as ac ON wp.OrderWorkPlanId = ac.OrderWorkPlanId ',' ')
	,IIF(@EquipmentIds IS NOT NULL,' JOIN #EquipmentId as eid ON wp.OrderWorkPlanId = eid.OrderWorkPlanId ',' ')
	,IIF(@CarsIds IS NOT NULL,' JOIN #CarsIds as cid ON wp.OrderWorkPlanId = cid.OrderWorkPlanId ',' ')
	,IIF(@OrderNumber IS NOT NULL,' JOIN #OrderNumbers as ordnf ON wp.OrderWorkPlanId = ordnf.OrderWorkPlanId ',' ')
	,'JOIN [dbo].[OrderDetails] as od ON wp.OrderWorkPlanId = od.OrderWorkPlanId
	  LEFT JOIN [dbo].[OrderDetailsItems] as itm ON itm.OrderDetailId = od.OrderDetailId
	  LEFT JOIN [dbo].[Customers] as c ON wp.[CustomerId] = c.[CustomerId]
	  LEFT JOIN [dbo].[Statuses] as wpstat ON wp.[OrderOverallStatusId] = wpstat.[StatusId]
	  LEFT JOIN [dbo].[Statuses] as clst ON wp.[ClientConfirmationStatusId] = clst.[StatusId]
	  LEFT JOIN [dbo].[MainCategories] as mcf ON od.MainCategoryId	= mcf.ID
	  LEFT JOIN [dbo].[CalibratorsToWorkPlan] as ctwp ON ctwp.[OrderWorkPlanId] = wp.[OrderWorkPlanId] AND ctwp.[CalibratorId] = ',@LoggedInUserId,' AND ctwp.IsDeleted = 0
	  LEFT JOIN [dbo].[CalibratorsToWorkPlan] as ctwpdef ON ctwpdef.[OrderWorkPlanId] = wp.[OrderWorkPlanId] AND ctwpdef.IsDeleted = 0
	  LEFT JOIN [dbo].[SecondaryCategories] as scf ON od.SecondaryCategoryId = scf.ID
	  LEFT JOIN [dbo].[OrdersDeviceManufacturers] as dm ON itm.[OrdersDeviceManufacturerId] = dm.[OrdersDeviceManufacturerId]
	  LEFT JOIN [dbo].[CustomerSites] as css ON css.CustomerSiteId = od.CustomerSiteId
	',IIF(@SpecialCareTypeIds IS NOT NULL,' JOIN #SpecialCareTypes as sct ON od.SpecialCareTypeId = sct.SpecialCareTypeId ',' ')
	 ,IIF(@MainCategory IS NOT NULL,' JOIN #MainCategory as mainc ON od.MainCategoryId = mainc.ID ',' ')
	 ,IIF(@SecondCategory IS NOT NULL,' JOIN #SecondCategory as secc ON od.SecondaryCategoryId = secc.ID ',' ')
	,'LEFT JOIN 
	  (SELECT maincat.OrderWorkPlanId, STRING_AGG(maincat.MainCategoryName,'','') as MainCategoryName
	  FROM (
		  SELECT DISTINCT wp.OrderWorkPlanId, CAST(mcf.MainCategoryName AS NVARCHAR(MAX)) as MainCategoryName
		  FROM [dbo].[OrderWorkPlans] as wp  
		  JOIN [dbo].[OrderDetails] as od ON wp.OrderWorkPlanId = od.OrderWorkPlanId
		  JOIN [dbo].[MainCategories] as mcf ON od.MainCategoryId	= mcf.ID
		  ) as maincat
	 GROUP BY maincat.OrderWorkPlanId
	) as mcat ON wp.OrderWorkPlanId = mcat.OrderWorkPlanId
	LEFT JOIN 
	(  SELECT co.OrderWorkPlanId,STRING_AGG(co.CarId,'','') as [Cars]
		FROM [dbo].[CarsToOrder] as co 
		WHERE co.IsDeleted = 0
		GROUP BY co.OrderWorkPlanId
	 ) as co ON wp.OrderWorkPlanId = co.OrderWorkPlanId
	LEFT JOIN 
	(	SELECT cwp.OrderWorkPlanId,STRING_AGG(CONCAT(u.FirstName,'' '',u.LastName),'','') as Calibrators
		FROM [dbo].[CalibratorsToWorkPlan] as cwp
		JOIN [dbo].[Users] as u ON cwp.CalibratorId = u.ID
		WHERE cwp.IsDeleted = 0	GROUP BY cwp.OrderWorkPlanId
	 ) as cwp ON wp.OrderWorkPlanId = cwp.OrderWorkPlanId
	LEFT JOIN 
	( SELECT OrderWorkPlanId,STRING_AGG(StatusDescriptionENG,'','') AS StatusDescriptionENG,
	 STRING_AGG(StatusDescriptionHEB,'','') AS StatusDescriptionHEB
	 FROM (SELECT DISTINCT od.OrderWorkPlanId, s.StatusDescriptionENG, s.StatusDescriptionHEB
	 FROM [dbo].[OrderDetails] as od
	 JOIN [dbo].[Statuses] as s ON od.SpecialCareTypeId = s.StatusId
	 ) ds GROUP BY OrderWorkPlanId
	) as sp ON wp.OrderWorkPlanId = sp.OrderWorkPlanId
	LEFT JOIN 
	( SELECT coh.OrderWorkPlanId, STRING_AGG(coh.MeasurementDeviceId,'', '') as EquipmentIds, STRING_AGG(ce.Description,'', '') as EquipmentNames
	  FROM [dbo].[MeasurementDevicesToOrderHeaders] as coh
	  JOIN [dbo].[MeasurementDevices] as ce ON coh.MeasurementDeviceId = ce.ID AND ce.IsDeleted = 0
	  WHERE coh.IsDeleted = 0 GROUP BY coh.OrderWorkPlanId
	)as coh ON wp.OrderWorkPlanId = coh.OrderWorkPlanId
	LEFT JOIN (SELECT OrderWorkPlanId,STRING_AGG(SpecialCareTypeId,'','') as SpecialCares
	 FROM [dbo].[OrderDetails]
	 GROUP BY OrderWorkPlanId 
	) as spc ON wp.OrderWorkPlanId = spc.OrderWorkPlanId
	OUTER APPLY
	(
	SELECT COUNT(DISTINCT pb.PackingBoxId) as BoxesCount
	FROM [dbo].[PackingBox] as pb
	LEFT JOIN [dbo].[PackingBoxToOrderDetailsItems] as itm ON pb.PackingBoxId = itm.PackingBoxId
	LEFT JOIN [dbo].[OrderDetailsItems] as oi ON itm.OrderDetailsItemId = oi.OrderDetailsItemId
	LEFT JOIN [dbo].[OrderDetails] as od ON oi.OrderDetailId = od.OrderDetailId
	WHERE od.OrderWorkPlanId = wp.OrderWorkPlanId AND pb.IsDeleted = 0 AND itm.IsDeleted = 0 
	GROUP BY od.OrderWorkPlanId
	) as boxcnt 
	WHERE wp.OrderOverallStatusId IN(',@StatusesForOrders,') '
	,CASE WHEN @ExcludeRejectedOrders = 1 THEN ' AND COALESCE(wp.ClientConfirmationStatusId,0) NOT IN ('+@ClientConfirmationStatus+') 'ELSE ' ' END
	,CASE WHEN @ClientName IS NOT NULL THEN ' AND c.CustomerName LIKE N''%'+ @ClientName +'%'' 'ELSE ' ' END
	,CASE WHEN @Date IS NOT NULL AND  @Date > '1900-01-01' THEN ' AND wp.AssigmentDate = '''+CAST(@Date as NVARCHAR(MAX)) +''' 'ELSE ' ' END
	,CASE WHEN @Location  IS NOT NULL THEN ' AND IIF(css.CustomerSiteId IS NOT NULL,CONCAT_WS('', '',css.CustomerSiteAddress,css.CustomerSiteState,css.CustomerSiteZIP), CONCAT_WS('', '',c.CustomerAddress, c.CustomerCity)) LIKE N''%'+@Location +'%'' 'ELSE ' ' END
	,CASE WHEN @ProductType IS NOT NULL THEN ' AND od.PartName LIKE N''%'+ @ProductType +'%'' 'ELSE ' ' END
	,CASE WHEN @ProducedIn IS NOT NULL THEN ' AND dm.OrdersDeviceManufacturerDescription LIKE N''%'+ @ProducedIn +'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceModel IS NOT NULL THEN ' AND itm.DeviceModel LIKE N''%'+ @DeviceModel +'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceNumber IS NOT NULL THEN ' AND itm.SerialNumber LIKE N''%'+ @DeviceNumber +'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceManufacturer IS NOT NULL THEN ' AND dm.OrdersDeviceManufacturerDescription LIKE N''%'+ @DeviceManufacturer +'%'''ELSE ' ' END
    ,CASE WHEN @GlobalSearch IS NOT NULL THEN ' AND CONCAT(cwp.[Calibrators],mcf.[MainCategoryName],c.[CustomerCity],c.[CustomerName],scf.[SecondaryCategoryName],sp.[StatusDescriptionENG],wp.[OrderNumber]) LIKE N''%'+ @GlobalSearch +'%'''ELSE ' ' END
	,CASE WHEN @WorkPlanOpenDate IS NOT NULL THEN ' AND wp.WorkPlanOpenDate = '''+CAST(@WorkPlanOpenDate as NVARCHAR(MAX)) +''' 'ELSE ' ' END
	,CASE WHEN @Notes IS NOT NULL THEN ' AND wp.Notes LIKE N''%'+ @Notes +'%'''ELSE ' ' END
	,CASE WHEN @ExtIntFilter IS NOT NULL THEN ' AND od.IsInHouse='+CAST(@ExtIntFilter as NVARCHAR(MAX))+' 'ELSE ' ' END
	,CASE WHEN @DateFrom IS NOT NULL AND @DateTo IS NOT NULL 
		  THEN ' AND wp.[AssigmentDate] >= '''+CAST(@DateFrom AS NVARCHAR(MAX))+''' AND wp.[AssigmentDate] <= '''+CAST(@DateTo AS NVARCHAR(MAX))+''''
	  ELSE ' ' END
	,'GROUP BY wp.AssigmentDate,
	wp.[CustomerId],
	wp.[OrderNumber], 
	wp.[OrderWorkPlanId],
	spc.[SpecialCares],
	c.[CustomerName], 
	IIF(css.CustomerSiteId IS NOT NULL,CONCAT_WS('', '',css.CustomerSiteAddress,css.CustomerSiteState,css.CustomerSiteZIP), CONCAT_WS('', '',c.CustomerAddress, c.CustomerCity)),
	wp.[WorkPlanOpenDate],
	co.[Cars],
    coh.EquipmentIds,
	coh.EquipmentNames,
	cwp.Calibrators,
	wp.Notes,
	sp.StatusDescriptionENG,
	sp.StatusDescriptionHEB, 
	wp.[IsCancelled]'
  ,  'ORDER BY ' , @OrderBy , CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END , ' OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')
PRINT LEN(@sql)
PRINT CAST(@sql as VARCHAR(MAX))
EXEC (@sql)

END