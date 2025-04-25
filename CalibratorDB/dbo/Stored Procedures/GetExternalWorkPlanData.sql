
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 03/04/2025
-- Description:	Get work plan data
-- =============================================
CREATE PROCEDURE [dbo].[GetExternalWorkPlanData]
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
	@AssignedCalibrators NVARCHAR(100) = NULL,
	@DeviceModel NVARCHAR(100) = NULL,
	@PrintedNumber NVARCHAR(100) = NULL,
	@DateFrom DATETIME2(0) = NULL,
	@DateTo DATETIME2(0) = NULL,
	@DeviceNumber NVARCHAR(20) = NULL,
	@DeviceManufacturer NVARCHAR(255) = NULL,
	@AssignedCalibratorsIds NVARCHAR(MAX) = NULL,
	@EquipmentIds NVARCHAR(MAX) = NULL,
	@SpecialCareTypeIds NVARCHAR(255) = NULL
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

	IF @AssignedCalibrators IS NOT NULL
	BEGIN
	DROP TABLE IF EXISTS #Calibrators
	CREATE TABLE #Calibrators
	(
	CalibratorId INT
	)
	INSERT #Calibrators(CalibratorId)
	SELECT u.ID FROM [dbo].[Users] as u 
	JOIN [dbo].[UsersToUserRoles] as r ON u.ID = r.UserId
	WHERE u.IsActive = 1 AND r.UserRoleId = 3 --Calibrator
		  AND (
			u.LastName LIKE '%'+@AssignedCalibrators+'%' 
			OR u.FirstName LIKE '%'+@AssignedCalibrators+'%'
			OR u.FirstNameEng LIKE '%'+@AssignedCalibrators+'%'
			OR u.LastNameEng LIKE '%'+@AssignedCalibrators+'%'
			OR CONCAT(u.FirstName,' ',u.LastName) LIKE '%'+@AssignedCalibrators+'%'
			OR CONCAT(u.FirstNameEng,' ',u.LastNameEng) LIKE '%'+@AssignedCalibrators+'%'
			OR CONCAT(u.LastName,' ',u.FirstName) LIKE '%'+@AssignedCalibrators+'%'
			OR CONCAT(u.LastNameEng,' ',u.FirstNameEng) LIKE '%'+@AssignedCalibrators+'%'
	) and u.ID > 0

	INSERT #FilteredDetails(OrderWorkPlanId)
   	SELECT DISTINCT cwp.[OrderWorkPlanId]
	FROM [dbo].[CalibratorsToWorkPlan] as cwp
	JOIN #Calibrators AS c ON c.CalibratorId = cwp.CalibratorId
	LEFT JOIN #FilteredDetails as fd ON cwp.OrderWorkPlanId = fd.OrderWorkPlanId
	WHERE fd.OrderWorkPlanId IS NULL

	END

	DROP TABLE IF EXISTS #AssignedCalibrators
	CREATE TABLE #AssignedCalibrators
	(
	[OrderWorkPlanId] INT
	)
	INSERT #AssignedCalibrators([OrderWorkPlanId])
	SELECT DISTINCT wp.OrderWorkPlanId FROM dbo.ParseCSVToTable(@AssignedCalibratorsIds) as f
	JOIN [dbo].[CalibratorsToWorkPlan] as wp ON wp.CalibratorId = f.Value

	DROP TABLE IF EXISTS #EquipmentId
	CREATE TABLE #EquipmentId
	(
	[OrderWorkPlanId] INT
	)
	INSERT #EquipmentId([OrderWorkPlanId])
	SELECT DISTINCT ce.OrderWorkPlanId FROM dbo.ParseCSVToTable(@EquipmentIds) as f
	JOIN [dbo].[CalibEquipmentsToOrderHeaders] as ce ON ce.CalibEquipmentId = f.Value

	DROP TABLE IF EXISTS #SpecialCareTypes
	CREATE TABLE #SpecialCareTypes
	(
	[SpecialCareTypeId] INT
	)
	INSERT #SpecialCareTypes([SpecialCareTypeId])
	SELECT DISTINCT f.Value FROM dbo.ParseCSVToTable(@SpecialCareTypeIds) as f

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'
 SELECT 
        wp.[OrderNumber] AS [OrderNumber] ,
        MAX(od.[CalibDate]) AS [Date],
        spc.[SpecialCares],
        od.[CustomerName] as [ClientName],
        od.[CustomerCity] as [Location],
        wp.[WorkPlanOpenDate] as [WorkPlanOpenDate],
		sp.StatusDescriptionENG AS SpecialCareENG,
		sp.StatusDescriptionHEB AS SpecialCareHEB, 
        co.[Cars],
        coh.EquipmentIds,
		coh.EquipmentNames,
		cwp.Calibrators,
        NULL as Notes,
		mc.MainCategory,
		wp.[IsCancelled],
		STRING_AGG(od.SerialNumber,'','') AS DeviceNumber,
		STRING_AGG(od.DeviceManufacturer,'','') AS DeviceManufacturer,
		STRING_AGG(od.DeviceModel,'','') AS DeviceModel,
		COUNT(1) OVER(PARTITION BY 1 ORDER BY wp.[OrderNumber] ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING ) as ItemsCount
    FROM [dbo].[OrderWorkPlans] as wp'
    ,IIF((SELECT COUNT(*) FROM #FilteredDetails) > 0,' JOIN #FilteredDetails as f ON wp.OrderWorkPlanId = f.OrderWorkPlanId ',' ')
	,IIF((SELECT COUNT(*) FROM #AssignedCalibrators) > 0,' JOIN #AssignedCalibrators as ac ON wp.OrderWorkPlanId = ac.OrderWorkPlanId ',' ')
	,IIF((SELECT COUNT(*) FROM #EquipmentId) > 0,' JOIN #EquipmentId as eid ON wp.OrderWorkPlanId = eid.OrderWorkPlanId ',' ')
	,'JOIN [dbo].[OrderDetails] as od ON wp.OrderWorkPlanId = od.OrderWorkPlanId'
	,IIF((SELECT COUNT(*) FROM #SpecialCareTypes) > 0,' JOIN #SpecialCareTypes as sct ON od.SpecialCareTypeId = sct.SpecialCareTypeId ',' ')
	,'LEFT JOIN 
	(
		SELECT co.OrderWorkPlanId,STRING_AGG(co.CarId,'','') as [Cars]
		FROM [dbo].[CarsToOrder] as co 
		WHERE co.IsDeleted = 0
		GROUP BY co.OrderWorkPlanId
	 ) as co
	ON wp.OrderWorkPlanId = co.OrderWorkPlanId
	LEFT JOIN 
	(
		SELECT cwp.OrderWorkPlanId,STRING_AGG(CONCAT(u.FirstName,'' '',u.LastName),'','') as Calibrators
		FROM [dbo].[CalibratorsToWorkPlan] as cwp
		JOIN [dbo].[Users] as u ON cwp.CalibratorId = u.ID
		WHERE cwp.IsDeleted = 0
		GROUP BY cwp.OrderWorkPlanId
	 ) as cwp
	ON wp.OrderWorkPlanId = cwp.OrderWorkPlanId
	LEFT JOIN 
	(
	 SELECT OrderWorkPlanId, STRING_AGG(MainCategory,'','') AS MainCategory
	 FROM (
	 SELECT DISTINCT OrderWorkPlanId,MainCategory
	 FROM [dbo].[OrderDetails]
	 WHERE IsInHouse = 0 and IsCancelled = 0
	 ) ds
	 GROUP BY OrderWorkPlanId
	) as mc ON wp.OrderWorkPlanId = mc.OrderWorkPlanId
	LEFT JOIN 
	(
	 SELECT OrderWorkPlanId, 
	 STRING_AGG(StatusDescriptionENG,'','') AS StatusDescriptionENG,
	 STRING_AGG(StatusDescriptionHEB,'','') AS StatusDescriptionHEB
	 FROM (
	 SELECT DISTINCT od.OrderWorkPlanId, s.StatusDescriptionENG,
	 s.StatusDescriptionHEB
	 FROM [dbo].[OrderDetails] as od
	 JOIN [dbo].[Statuses] as s ON od.SpecialCareTypeId = s.StatusId
	 WHERE od.IsInHouse = 0 and od.IsCancelled = 0
	 ) ds
	 GROUP BY OrderWorkPlanId
	) as sp ON wp.OrderWorkPlanId = sp.OrderWorkPlanId
	LEFT JOIN 
	( 
	  SELECT coh.OrderWorkPlanId, STRING_AGG(coh.CalibEquipmentId,'', '') as EquipmentIds, 
			STRING_AGG(ce.EquipmentName,'', '') as EquipmentNames
	  FROM [dbo].[CalibEquipmentsToOrderHeaders] as coh
	  JOIN [dbo].[CalibEquipments] as ce ON coh.CalibEquipmentId = ce.ID AND ce.IsDeleted = 0
	  WHERE coh.IsDeleted = 0
	  GROUP BY coh.OrderWorkPlanId
	)as coh ON wp.OrderWorkPlanId = coh.OrderWorkPlanId
	LEFT JOIN 
	(
	 SELECT OrderWorkPlanId,STRING_AGG(SpecialCareTypeId,'','') as SpecialCares
	 FROM [dbo].[OrderDetails]
	 WHERE IsInHouse = 0 and IsCancelled = 0
	 GROUP BY OrderWorkPlanId 
	) as spc ON wp.OrderWorkPlanId = spc.OrderWorkPlanId
	WHERE od.IsInHouse = 0 AND wp.IsCancelled = 0'
	,CASE WHEN @ClientName IS NOT NULL THEN ' AND od.CustomerName LIKE N''%'+ @ClientName +'%'' 'ELSE ' ' END
	,CASE WHEN @Date IS NOT NULL AND  @Date > '1900-01-01' THEN ' AND od.CalibDate = '''+CAST(@Date as NVARCHAR(20)) +''' 'ELSE ' ' END
	,CASE WHEN @MainCategory IS NOT NULL THEN ' AND od.MainCategory LIKE N''%'+ @MainCategory+'%'' 'ELSE ' ' END
	,CASE WHEN @SecondCategory IS NOT NULL THEN ' AND od.SecondCategory LIKE N''%'+ @SecondCategory +'%'' 'ELSE ' ' END
	,CASE WHEN @Location  IS NOT NULL THEN ' AND od.CustomerCity LIKE N''%'+@Location +'%'' 'ELSE ' ' END
	,CASE WHEN @ProductType IS NOT NULL THEN ' AND od.PartName LIKE N''%'+ @ProductType +'%'' 'ELSE ' ' END
	,CASE WHEN @ProducedIn IS NOT NULL THEN ' AND od.DeviceManufacturer LIKE N''%'+ @ProducedIn +'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceModel IS NOT NULL THEN ' AND od.DeviceModel LIKE N''%'+ @DeviceModel +'%'' 'ELSE ' ' END
	,CASE WHEN @PrintedNumber IS NOT NULL THEN ' AND od.SerialNumber LIKE N''%'+ @PrintedNumber+'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceNumber IS NOT NULL THEN ' AND od.SerialNumber LIKE N''%'+ @DeviceNumber +'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceManufacturer IS NOT NULL THEN ' AND od.DeviceManufacturer LIKE N''%'+ @DeviceManufacturer +'%'''ELSE ' ' END
	,'GROUP BY wp.[OrderNumber], 
	spc.[SpecialCares],
	od.[CustomerName], 
	od.[CustomerCity],
	wp.[WorkPlanOpenDate],
	co.[Cars],
	mc.MainCategory,
    coh.EquipmentIds,
	coh.EquipmentNames,
	cwp.Calibrators,
	sp.StatusDescriptionENG,
	sp.StatusDescriptionHEB, 
	wp.[IsCancelled]'
	,CASE WHEN @DateFrom IS NOT NULL AND @DateTo IS NOT NULL 
		  THEN ' HAVING MAX(od.[CalibDate]) >= '''+CAST(@DateFrom AS nvarchar(20))+''' AND MAX(od.[CalibDate]) <= '''+CAST(@DateTo AS nvarchar(20))+''''
	  ELSE ' ' END
  ,  'ORDER BY ' , QUOTENAME(@OrderBy) , CASE WHEN @OrderByAsc = 1 THEN ' ASC' ELSE ' DESC' END , '
    OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')

PRINT @sql
EXEC sp_executesql @sql

END