-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 03/04/2025
-- Description:	Get work plan data
-- =============================================
CREATE  PROCEDURE [dbo].[GetExternalWorkPlanData]
    @PageNumber AS INT = 1,                  -- Resulting page for pagination, starting in 1
    @RowsOfPage AS INT = 1000,                 -- Result page size
    @OrderBy AS NVARCHAR(MAX) = 'Date',      -- OrderBy column
    @OrderByAsc AS BIT = 1,                  -- OrderBy direction (ASC/DESC)
    -- Filter parameters (all nullable)
	@ClientName NVARCHAR(255) = NULL,
	@Date DATE = NULL,
	@MainCategory NVARCHAR(100) = NULL,
	@SecondCategory NVARCHAR(100) = NULL,
	@Location NVARCHAR(100) = NULL,
	@ProductType NVARCHAR(100) = NULL,
	@ProducedIn NVARCHAR(255) = NULL,
	--@AssignedCalibrators NVARCHAR(100) = NULL,
	@DeviceModel NVARCHAR(100) = NULL,
	@DateFrom DATETIME2(0) = NULL,
	@DateTo DATETIME2(0) = NULL,
	@DeviceNumber NVARCHAR(20) = NULL,
	@DeviceManufacturer NVARCHAR(255) = NULL,
	@AssignedCalibratorsIds NVARCHAR(MAX) = NULL, -- -1 means that we should include orders with empty calibrator
	@EquipmentIds NVARCHAR(MAX) = NULL,
	@SpecialCareTypeIds NVARCHAR(255) = NULL,
	@OrderNumber NVARCHAR(20) = NULL,
	@GlobalSearch NVARCHAR(200) = NULL
AS

BEGIN
    SET NOCOUNT ON;
	SET ANSI_WARNINGS OFF;

	IF @OrderBy NOT IN 
	(N'OrderNumber',N'Date',N'SpecialCares',N'ClientName',N'Location',N'WorkPlanOpenDate',
	N'Cars',N'Calibrators',N'Equipments',N'Notes',N'MainCategory')
	THROW 51000, 'Incorrect value for parameter @OrderBy. Available values |OrderNumber|Date|SpecialCares|ClientName|Location|WorkPlanOpenDate|Cars|Calibrators|Equipments|Notes|MainCategory|', 1;


	DROP TABLE IF EXISTS #FilteredDetails
	CREATE TABLE #FilteredDetails
	(
	OrderWorkPlanId INT PRIMARY KEY
	)

	--IF @AssignedCalibrators IS NOT NULL
	--BEGIN
	--	DROP TABLE IF EXISTS #Calibrators
	--	CREATE TABLE #Calibrators
	--	(
	--	CalibratorId INT
	--	)
	--	INSERT #Calibrators(CalibratorId)
	--	SELECT u.ID FROM [dbo].[Users] as u 
	--	JOIN [dbo].[UserRoles] as r ON u.UserRoleId  = r.UserRoleId AND r.UserRoleDescriptionENG='Calibrator'
	--	WHERE u.IsActive = 1 
	--		  AND (
	--			u.LastName LIKE '%'+@AssignedCalibrators+'%' 
	--			OR u.FirstName LIKE '%'+@AssignedCalibrators+'%'
	--			OR u.FirstNameEng LIKE '%'+@AssignedCalibrators+'%'
	--			OR u.LastNameEng LIKE '%'+@AssignedCalibrators+'%'
	--			OR CONCAT(u.FirstName,' ',u.LastName) LIKE '%'+@AssignedCalibrators+'%'
	--			OR CONCAT(u.FirstNameEng,' ',u.LastNameEng) LIKE '%'+@AssignedCalibrators+'%'
	--			OR CONCAT(u.LastName,' ',u.FirstName) LIKE '%'+@AssignedCalibrators+'%'
	--			OR CONCAT(u.LastNameEng,' ',u.FirstNameEng) LIKE '%'+@AssignedCalibrators+'%'
	--	) and u.ID > 0

	--	INSERT #FilteredDetails(OrderWorkPlanId)
 --  		SELECT DISTINCT cwp.[OrderWorkPlanId]
	--	FROM [dbo].[CalibratorsToWorkPlan] as cwp
	--	JOIN #Calibrators AS c ON c.CalibratorId = cwp.CalibratorId
	--	LEFT JOIN #FilteredDetails as fd ON cwp.OrderWorkPlanId = fd.OrderWorkPlanId
	--	WHERE fd.OrderWorkPlanId IS NULL and cwp.IsDeleted = 0

	--END

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

	DROP TABLE IF EXISTS #SpecialCareTypes
	CREATE TABLE #SpecialCareTypes
	(
	[SpecialCareTypeId] INT
	)
	INSERT #SpecialCareTypes([SpecialCareTypeId])
	SELECT DISTINCT f.Value FROM dbo.ParseCSVToTable(@SpecialCareTypeIds) as f

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'SELECT wp.[OrderNumber] AS [OrderNumber],
        MAX(od.[ActualCalibrationDate]) AS [Date],
		MAX(od.[CustomerId]) as [CustomerId], 
        spc.[SpecialCares],
        REVERSE(c.[CustomerName]) as [ClientName],
        REVERSE(c.[CustomerCity]) as [Location],
        wp.[WorkPlanOpenDate] as [WorkPlanOpenDate],
		sp.StatusDescriptionENG AS SpecialCareENG,
		sp.StatusDescriptionHEB AS SpecialCareHEB, 
        co.[Cars],
        coh.EquipmentIds,
		coh.EquipmentNames,
		cwp.Calibrators,
        NULL as Notes,
		mc.MainCategory,
		NULL AS SecondCategory,
		wp.[IsCancelled],
		STRING_AGG(od.SerialNumber,'','') AS DeviceNumber,
		STRING_AGG(dm.OrdersDeviceManufacturerDescription,'','') AS DeviceManufacturer,
		STRING_AGG(od.DeviceModel,'','') AS DeviceModel,
	    MAX(wp.VPRICE) as VPRICE,
	    MAX(wp.PRICE) as PRICE,
		MAX(od.[PartName]) as PartName, 
		MAX(od.[OrderDetailId]) as OrderDetailId,
		MAX(wp.[OrderLineCnt]) as OrderLineCnt,
		COUNT(1) OVER(PARTITION BY 1 ORDER BY wp.[OrderNumber] ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as ItemsCount
    FROM [dbo].[OrderWorkPlans] as wp'
    ,IIF((SELECT COUNT(*) FROM #FilteredDetails) > 0,' JOIN #FilteredDetails as f ON wp.OrderWorkPlanId = f.OrderWorkPlanId ',' ')
	,IIF(@AssignedCalibratorsIds IS NOT NULL,' JOIN #AssignedCalibrators as ac ON wp.OrderWorkPlanId = ac.OrderWorkPlanId ',' ')
	,IIF(@EquipmentIds IS NOT NULL,' JOIN #EquipmentId as eid ON wp.OrderWorkPlanId = eid.OrderWorkPlanId ',' ')
	,'LEFT JOIN [dbo].[OrderDetails] as od ON wp.OrderWorkPlanId = od.OrderWorkPlanId
	  LEFT JOIN [dbo].[Customers] as c ON od.[CustomerId] = c.[CustomerId]
	  LEFT JOIN [dbo].[OrdersDeviceManufacturers] as dm ON od.[OrdersDeviceManufacturerId] = dm.[OrdersDeviceManufacturerId]
	',IIF(@SpecialCareTypeIds IS NOT NULL,' JOIN #SpecialCareTypes as sct ON od.SpecialCareTypeId = sct.SpecialCareTypeId ',' ')
	,'LEFT JOIN 
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
	(SELECT OrderWorkPlanId, STRING_AGG(MainCategory,'','') AS MainCategory
	 FROM ( SELECT DISTINCT od.OrderWorkPlanId,omc.OrdersMainCategoryName as MainCategory
	 FROM [dbo].[OrderDetails] as od
	 JOIN [dbo].[OrderWorkPlans] as wp ON od.OrderWorkPlanId = wp.OrderWorkPlanId
	 JOIN [dbo].[OrdersMainCategories] as omc ON od.OrdersMainCategoryId = omc.OrdersMainCategoryId
	 WHERE od.IsInHouse = 0 and wp.IsCancelled = 0
	 ) ds GROUP BY OrderWorkPlanId
	) as mc ON wp.OrderWorkPlanId = mc.OrderWorkPlanId
	LEFT JOIN 
	( SELECT OrderWorkPlanId,STRING_AGG(StatusDescriptionENG,'','') AS StatusDescriptionENG,
	 STRING_AGG(StatusDescriptionHEB,'','') AS StatusDescriptionHEB
	 FROM (SELECT DISTINCT od.OrderWorkPlanId, s.StatusDescriptionENG, s.StatusDescriptionHEB
	 FROM [dbo].[OrderDetails] as od
	 JOIN [dbo].[Statuses] as s ON od.SpecialCareTypeId = s.StatusId
	 WHERE od.IsInHouse = 0 and od.IsCancelled = 0
	 ) ds GROUP BY OrderWorkPlanId
	) as sp ON wp.OrderWorkPlanId = sp.OrderWorkPlanId
	LEFT JOIN 
	( SELECT coh.OrderWorkPlanId, STRING_AGG(coh.MeasurementDeviceId,'', '') as EquipmentIds, 
			STRING_AGG(ce.Description,'', '') as EquipmentNames
	  FROM [dbo].[MeasurementDevicesToOrderHeaders] as coh
	  JOIN [dbo].[MeasurementDevices] as ce ON coh.MeasurementDeviceId = ce.ID AND ce.IsDeleted = 0
	  WHERE coh.IsDeleted = 0 GROUP BY coh.OrderWorkPlanId
	)as coh ON wp.OrderWorkPlanId = coh.OrderWorkPlanId
	LEFT JOIN 
	(SELECT OrderWorkPlanId,STRING_AGG(SpecialCareTypeId,'','') as SpecialCares
	 FROM [dbo].[OrderDetails] WHERE IsInHouse = 0 and IsCancelled = 0
	 GROUP BY OrderWorkPlanId 
	) as spc ON wp.OrderWorkPlanId = spc.OrderWorkPlanId
	WHERE od.IsInHouse = 0 AND wp.IsCancelled = 0'
	,CASE WHEN @ClientName IS NOT NULL THEN ' AND c.CustomerName LIKE N''%'+ @ClientName +'%'' 'ELSE ' ' END
	,CASE WHEN @Date IS NOT NULL AND  @Date > '1900-01-01' THEN ' AND od.CalibDate = '''+CAST(@Date as NVARCHAR(MAX)) +''' 'ELSE ' ' END
	,CASE WHEN @MainCategory IS NOT NULL THEN ' AND mc.MainCategory LIKE N''%'+ @MainCategory+'%'' 'ELSE ' ' END
	,CASE WHEN @SecondCategory IS NOT NULL THEN ' AND od.SecondCategory LIKE N''%'+ @SecondCategory +'%'' 'ELSE ' ' END
	,CASE WHEN @Location  IS NOT NULL THEN ' AND c.CustomerCity LIKE N''%'+@Location +'%'' 'ELSE ' ' END
	,CASE WHEN @ProductType IS NOT NULL THEN ' AND od.PartName LIKE N''%'+ @ProductType +'%'' 'ELSE ' ' END
	,CASE WHEN @ProducedIn IS NOT NULL THEN ' AND dm.OrdersDeviceManufacturerDescription LIKE N''%'+ @ProducedIn +'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceModel IS NOT NULL THEN ' AND od.DeviceModel LIKE N''%'+ @DeviceModel +'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceNumber IS NOT NULL THEN ' AND od.SerialNumber LIKE N''%'+ @DeviceNumber +'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceManufacturer IS NOT NULL THEN ' AND dm.OrdersDeviceManufacturerDescription LIKE N''%'+ @DeviceManufacturer +'%'''ELSE ' ' END
    ,CASE WHEN @OrderNumber IS NOT NULL THEN ' AND wp.OrderNumber LIKE N''%'+ @OrderNumber +'%'''ELSE ' ' END
    ,CASE WHEN @GlobalSearch IS NOT NULL THEN ' AND CONCAT(cwp.[Calibrators],mc.[MainCategory],c.[CustomerCity],c.[CustomerName],od.[SecondCategory],sp.[StatusDescriptionENG],wp.[OrderNumber]) LIKE N''%'+ @GlobalSearch +'%'''ELSE ' ' END
	,'GROUP BY wp.[OrderNumber], 
	spc.[SpecialCares],
	c.[CustomerName], 
	c.[CustomerCity],
	wp.[WorkPlanOpenDate],
	co.[Cars],
	mc.MainCategory,
	--od.SecondCategory,
    coh.EquipmentIds,
	coh.EquipmentNames,
	cwp.Calibrators,
	sp.StatusDescriptionENG,
	sp.StatusDescriptionHEB, 
	wp.[IsCancelled]'
	,CASE WHEN @DateFrom IS NOT NULL AND @DateTo IS NOT NULL 
		  THEN ' HAVING MAX(od.[CalibDate]) >= '''+CAST(@DateFrom AS NVARCHAR(MAX))+''' AND MAX(od.[CalibDate]) <= '''+CAST(@DateTo AS NVARCHAR(MAX))+''''
	  ELSE ' ' END
  ,  'ORDER BY ' , QUOTENAME(@OrderBy) , CASE WHEN @OrderByAsc = 1 THEN ' ASC' ELSE ' DESC' END , ' OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')
PRINT LEN(@sql)
PRINT @sql
EXEC (@sql)
--EXEC sp_executesql @sql

END