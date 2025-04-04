
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 03/04/2025
-- Description:	Get work plan data
-- =============================================
CREATE PROCEDURE [dbo].[GetExternalWorkPlanData]
    @PageNumber AS INT = 1,                  -- Resulting page for pagination, starting in 1
    @RowsOfPage AS INT = 10,                 -- Result page size
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
	@PrintedNumber NVARCHAR(100) = NULL
	
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
	)

	INSERT #FilteredDetails(OrderWorkPlanId)
   	SELECT DISTINCT cwp.[OrderWorkPlanId]
	FROM [dbo].[CalibratorsToWorkPlan] as cwp
	JOIN #Calibrators AS c ON c.CalibratorId = cwp.CalibratorId
	LEFT JOIN #FilteredDetails as fd ON cwp.OrderWorkPlanId = fd.OrderWorkPlanId
	WHERE fd.OrderWorkPlanId IS NULL

	END

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
        co.[Cars],
        coh.Equipments,
        NULL as Notes,
		wp.[IsCancelled]
		,COUNT(1) OVER(PARTITION BY 1 ORDER BY wp.[OrderNumber] ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING ) as ItemsCount
    FROM [dbo].[OrderWorkPlans] as wp'
    ,IIF((SELECT COUNT(*) FROM #FilteredDetails) > 0,' JOIN #FilteredDetails as f ON wp.OrderWorkPlanId = f.OrderWorkPlanId ',' '),
	'JOIN [dbo].[OrderDetails] as od ON wp.OrderWorkPlanId = od.OrderWorkPlanId
	LEFT JOIN 
	(
		SELECT co.OrderWorkPlanId,STRING_AGG(co.CarId,'','') as [Cars]
		FROM [dbo].[CarsToOrder] as co 
		GROUP BY co.OrderWorkPlanId
	 ) as co
	ON wp.OrderWorkPlanId = co.OrderWorkPlanId
	LEFT JOIN 
	( 
	  SELECT coh.OrderWorkPlanId, STRING_AGG(coh.CalibEquipmentId,'','') as Equipments
	  FROM [dbo].[CalibEquipmentsToOrderHeaders] as coh
	  GROUP BY coh.OrderWorkPlanId
	)as coh ON wp.OrderWorkPlanId = coh.OrderWorkPlanId
	LEFT JOIN 
	(
	 SELECT OrderWorkPlanId,STRING_AGG(SpecialCareTypeId,'','') as SpecialCares
	 FROM [dbo].[OrderDetails]
	 WHERE IsInHouse = 0
	 GROUP BY OrderWorkPlanId 
	) as spc ON wp.OrderWorkPlanId = spc.OrderWorkPlanId
	WHERE od.IsInHouse = 0'
	,CASE WHEN @ClientName IS NOT NULL THEN ' AND od.CustomerName LIKE N''%'+ @ClientName +'%'' 'ELSE ' ' END
	,CASE WHEN @Date IS NOT NULL AND  @Date > '1900-01-01' THEN ' AND od.CalibDate = '''+CAST(@Date as NVARCHAR(20)) +''' 'ELSE ' ' END
	,CASE WHEN @MainCategory IS NOT NULL THEN ' AND od.MainCategory LIKE N''%'+ @MainCategory+'%'' 'ELSE ' ' END
	,CASE WHEN @SecondCategory IS NOT NULL THEN ' AND od.SecondCategory LIKE N''%'+ @SecondCategory +'%'' 'ELSE ' ' END
	,CASE WHEN @Location  IS NOT NULL THEN ' AND od.CustomerCity LIKE N''%'+@Location +'%'' 'ELSE ' ' END
	,CASE WHEN @ProductType IS NOT NULL THEN ' AND od.PartName LIKE N''%'+ @ProductType +'%'' 'ELSE ' ' END
	,CASE WHEN @ProducedIn IS NOT NULL THEN ' AND od.DeviceManufacturer LIKE N''%'+ @ProducedIn +'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceModel IS NOT NULL THEN ' AND od.DeviceModel LIKE N''%'+ @DeviceModel +'%'' 'ELSE ' ' END
	,CASE WHEN @PrintedNumber IS NOT NULL THEN ' AND od.SerialNumber LIKE N''%'+ @PrintedNumber+'%'' 'ELSE ' ' END
	,'GROUP BY wp.[OrderNumber], 
	spc.[SpecialCares],
	od.[CustomerName], 
	od.[CustomerCity],
	wp.[WorkPlanOpenDate],
	co.[Cars],
    coh.[Equipments],
	wp.[IsCancelled]'
  ,  'ORDER BY ' , QUOTENAME(@OrderBy) , CASE WHEN @OrderByAsc = 1 THEN ' ASC' ELSE ' DESC' END , '
    OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')

PRINT @sql
EXEC sp_executesql @sql

END