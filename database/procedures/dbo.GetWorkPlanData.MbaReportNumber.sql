-- =============================================
-- Proc:        dbo.GetWorkPlanData
-- Jira:        MBA — "אישור תיאום כיול ע"י הלקוח" (order-approval by e-mail)
-- Description: Verbatim copy of the live dbo.GetWorkPlanData with ONE behavioural change:
--              the fallback ClientConfirmationStatus for orders whose
--              OrderWorkPlans.ClientConfirmationStatusId is NULL is now 'New' (חדש)
--              instead of 'Pending' (ממתין).
--
--              Why: 'Pending' now means "a coordination e-mail was sent and we are waiting
--              for the customer to answer" — it is the status that triggers the mail. Orders
--              that arrived from the Priority sync and were never sent to the customer must
--              not look pending; they are 'New'. (On STG that is ~990 of ~997 orders.)
--
--              Requires dbo.ClientConfirmationStatus.New.seed.sql to have run first, otherwise
--              @ClientConfirmationStatusDefault resolves to NULL.
--
-- Everything below this header is the live definition as of the change, only
-- CREATE OR ALTER PROCEDURE -> CREATE OR ALTER PROCEDURE and the one WHERE line differ.
-- =============================================
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 03/04/2025
-- Description:	Get work plan data
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetWorkPlanData]
    @PageNumber AS INT = 1,                  -- Resulting page for pagination, starting in 1
    @RowsOfPage AS INT = 50,                 -- Result page size
    @OrderBy AS NVARCHAR(MAX) = 'OrderWorkPlanId',      -- OrderBy column
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
	@ExcludeRejectedOrders BIT = 0,
	@ClientId INT = NULL,
	-- MBA-806/filter fix: the "קוד לקוח" field is Customers.CustomerCode (NVARCHAR, can be
	-- alphanumeric e.g. 'T005585') and is NOT Customers.CustomerId. Prefer this parameter.
	@ClientCode NVARCHAR(50) = NULL
AS

BEGIN
    SET NOCOUNT ON;
	SET ANSI_WARNINGS OFF;

	/* ---------------------------------------------------------------------------------
	   Customer filter resolution (MBA: "קוד לקוח" returned the wrong customer / no rows).
	   Customers has THREE different ids and their ranges overlap:
	     CustomerId           - local surrogate key, what OrderWorkPlans.CustomerId points at
	     CustomerIdFromSource - Priority CUST
	     CustomerCode         - the HP / קוד לקוח the user types on screen
	   Example: code 877 = 'אלכם מדיקל' (CustomerId 4428), while CustomerId 877 is a
	   different company ('פינקלמן') with no work plans - so filtering by the typed code
	   against CustomerId silently returned an empty screen.
	   @ClientCode is the correct input. @ClientId is kept for back-compat and is resolved
	   as a CODE first (that is what the UI sends today), falling back to a real CustomerId.
	   --------------------------------------------------------------------------------- */
	DECLARE @ResolvedCustomerId INT = NULL;

	IF @ClientCode IS NOT NULL
	BEGIN
		SELECT TOP (1) @ResolvedCustomerId = c.CustomerId
		FROM dbo.Customers AS c
		WHERE c.CustomerCode = @ClientCode AND ISNULL(c.IsDeleted, 0) = 0;

		IF @ResolvedCustomerId IS NULL SET @ResolvedCustomerId = -1;  -- unknown code -> no rows
	END
	ELSE IF @ClientId IS NOT NULL
	BEGIN
		SELECT TOP (1) @ResolvedCustomerId = c.CustomerId
		FROM dbo.Customers AS c
		WHERE c.CustomerCode = CAST(@ClientId AS NVARCHAR(20)) AND ISNULL(c.IsDeleted, 0) = 0;

		IF @ResolvedCustomerId IS NULL SET @ResolvedCustomerId = @ClientId;  -- treat as a real CustomerId
	END

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
	/* MBA-902 / MBA-293 AC1: "As soon as Calibrator finishes calibration and generates the report,
	   the Validator should see the calibration validation screen." The validator pages had no status
	   filter at all - internal-validator, external-validator and internal-orders returned an
	   identical 500 rows - so the screen listed orders that had not been calibrated yet, which is
	   why every CRM-sourced column on it came back empty.
	   These are the device statuses that mean calibration is over, taken from the story's own list. */
	DECLARE @ValidatorDeviceStatuses NVARCHAR(200) = N'23,26,29,32,33,34,35,36'
	/* 23 CalibrationSuccess  26 Adjusted  29 ReadyForPacking  32 TestedMetTheStandard
	   33 TestedDidn'tMeetTheStandards  34 CannotBeDetermined  35 AwaitingComments  36 AwaitingSignature
	   Deliberately excluded: 19/37 WaitingForCalibration, 20/38 InCalibration, 30 NotCalibrated -
	   calibration has not finished; and 22 Packaged, 24 Delivered, 27 ReadyForDelivery,
	   28 WaitingForPacking - those have already left the validator. */

	DECLARE @ExtIntFilter BIT = NULL

	/* MBA-902: external-validator and internal-validator were in neither list, so both pages
	   returned the same rows. The mechanism was already here and coordinator-orders uses it -
	   od.IsInHouse is the internal/external definition in this system. */
	IF @Page IN (N'external-schedule',N'external-orders',N'coordinator-orders',N'external-validator') SET @ExtIntFilter = 0 -- IsInHouse = 0 for external orders

	IF @Page IN (N'internal-orders',N'internal-validator') SET @ExtIntFilter = 1 -- IsInHouse = 1 for internal orders
	--validator-orders
	/*-------------------------------------------------*/

	--IF @OrderBy NOT IN 
	--(N'OrderNumber',N'SpecialCares',N'ClientName',N'Location',N'WorkPlanOpenDate',
	--N'Cars',N'Calibrators',N'EquipmentNames',N'Notes',N'MainCategory',N'CalibDate',N'ClientConfirmationStatus',N'ExpectedReturnDate',
	--N'ActualReturnDate',N'CustomerPackingExists',N'PrintedReport',N'ReceivingDate',N'WorkPlanStatus')
	--THROW 51000, 'Incorrect value for parameter @OrderBy. Available values |OrderNumber|SpecialCares|ClientName|
	--ExpectedReturnDate|ActualReturnDate
	--|Location|WorkPlanOpenDate|Cars|Calibrators|EquipmentNames|Notes|MainCategory|CalibDate|ClientConfirmationStatus', 1;

	/* MBA-902: the sparse CRM columns. Sorting one of them ascending put every empty row first, so
	   the screen opened on nothing but dashes even though values exist further down - 6 of 38 rows
	   carry a report number and 11 carry the return dates. Rows that HAVE a value now always come
	   first and the requested direction orders them, the same treatment Cars, Calibrators and
	   EquipmentNames already get below.
	   The expressions are repeated rather than referenced by alias: ORDER BY may use a select-list
	   alias on its own, but not wrapped inside IIF, and CalibratorMabaNumber is a correlated
	   subquery rather than a plain column. */
	DECLARE @SortExpr NVARCHAR(MAX) = NULL

	IF @OrderBy = N'CalibratorMabaNumber' SET @SortExpr = N'(SELECT MIN(i9.MbaReportNumber) FROM [dbo].[OrderDetailsItems] as i9 JOIN [dbo].[OrderDetails] as od9 ON od9.OrderDetailId = i9.OrderDetailId WHERE od9.OrderWorkPlanId = wp.[OrderWorkPlanId] AND ISNULL(od9.IsDeleted,0) = 0 AND ISNULL(i9.IsDeleted,0) = 0 AND i9.MbaReportNumber LIKE ''[0-9][0-9][0-9][0-9][0-9][0-9][0-9]/%'')'
	IF @OrderBy = N'ExpectedReturnDate'   SET @SortExpr = N'MAX(itm.ExpectedReturnDate)'
	IF @OrderBy = N'ActualReturnDate'     SET @SortExpr = N'MAX(itm.ActualReturnDate)'

	IF @SortExpr IS NOT NULL
	BEGIN
		SET @OrderBy = CONCAT(N'IIF(', @SortExpr, N' IS NULL,1,0) ASC, ', @SortExpr, N' ',
		                      CASE WHEN @OrderByAsc = 0 THEN N'DESC' ELSE N'ASC' END)
		SET @OrderByAsc = NULL
	END

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
    /*Apply filter by orders on external order page to get only orders assigned by calibrator for specific date*/
	DECLARE @FilterExternalOrdersForCalibrator BIT = 0
    IF @Page = N'external-orders' AND @DateFrom IS NOT NULL AND @DateTo IS NOT NULL
		BEGIN
			SET @FilterExternalOrdersForCalibrator = 1

			DROP TABLE IF EXISTS #FilterExternalOrdersForCalibrator
			CREATE TABLE #FilterExternalOrdersForCalibrator
			(
			[OrderWorkPlanId] INT
			)
			INSERT #FilterExternalOrdersForCalibrator([OrderWorkPlanId])
			SELECT DISTINCT cal.OrderWorkPlanId 
			FROM [dbo].[CalibratorsToWorkPlan] as cal
			JOIN [dbo].[CarsToOrder] as c ON cal.OrderWorkPlanId = c.OrderWorkPlanId AND cal.AssigmentDate = c.AssignDate AND c.IsDeleted = 0
			WHERE (cal.CalibratorId = @LoggedInUserId OR @SourceId IS NULL)
			AND cal.AssigmentDate >= @DateFrom AND cal.AssigmentDate <=@DateTo
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
	WHERE c.StatusDescriptionENG = N'ClientConfirmationStatus' AND s.StatusDescriptionENG = N'New'

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

	-------------------------------------------------------------------------
	-- Pre-calculate metrics that use STRING_AGG into temp tables
	-------------------------------------------------------------------------

	-- 1. Main Category Names
	DROP TABLE IF EXISTS #MainCatNames;
	CREATE TABLE #MainCatNames (
		OrderWorkPlanId INT,
		MainCategoryName NVARCHAR(400) COLLATE Latin1_General_100_CI_AI_SC
	);
	INSERT INTO #MainCatNames (OrderWorkPlanId, MainCategoryName)
	SELECT maincat.OrderWorkPlanId, STRING_AGG(maincat.MainCategoryName,',') as MainCategoryName
	FROM (
		SELECT DISTINCT wp.OrderWorkPlanId, mcf.MainCategoryName 
		FROM [dbo].[OrderWorkPlans] as wp  
		JOIN [dbo].[OrderDetails] as od ON wp.OrderWorkPlanId = od.OrderWorkPlanId
		JOIN [dbo].[MainCategories] as mcf ON od.MainCategoryId = mcf.ID
	) as maincat
	GROUP BY maincat.OrderWorkPlanId;

	CREATE UNIQUE CLUSTERED INDEX UC_IDX_MainCatNames ON #MainCatNames(OrderWorkPlanId)

	-- 2. Cars and Placement Dates
	DROP TABLE IF EXISTS #CarsAndPlacement;
	CREATE TABLE #CarsAndPlacement (
		OrderWorkPlanId INT,
		Cars NVARCHAR(400) COLLATE Latin1_General_100_CI_AI_SC,
		PlacementDate NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC
	);
	IF @DateFrom IS NOT NULL AND @DateTo IS NOT NULL AND @Page <> N'external-orders'
	BEGIN
		INSERT INTO #CarsAndPlacement (OrderWorkPlanId, Cars, PlacementDate)
		SELECT co.OrderWorkPlanId, STRING_AGG(CAST(co.CarId as NVARCHAR(MAX)),','), STRING_AGG(CAST(co.AssignDate as NVARCHAR(MAX)),',')
		FROM [dbo].[CarsToOrder] as co 
		WHERE co.IsDeleted = 0 AND co.[AssignDate] >= @DateFrom AND co.[AssignDate] <= @DateTo
		GROUP BY co.OrderWorkPlanId;
	END
	ELSE
	BEGIN
		INSERT INTO #CarsAndPlacement (OrderWorkPlanId, Cars, PlacementDate)
		SELECT co.OrderWorkPlanId, STRING_AGG(CAST(co.CarId as NVARCHAR(MAX)),','), STRING_AGG(CAST(co.AssignDate as NVARCHAR(MAX)),',')
		FROM [dbo].[CarsToOrder] as co 
		WHERE co.IsDeleted = 0
		GROUP BY co.OrderWorkPlanId;
	END
	CREATE UNIQUE CLUSTERED INDEX UC_IDX_CarsAndPlacement ON #CarsAndPlacement(OrderWorkPlanId)

	-- 3. Calibrators
	DROP TABLE IF EXISTS #WorkPlanCalibrators;
	CREATE TABLE #WorkPlanCalibrators (
		OrderWorkPlanId INT,
		Calibrators NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC
	);
	INSERT INTO #WorkPlanCalibrators (OrderWorkPlanId, Calibrators)
	SELECT cwp.OrderWorkPlanId, STRING_AGG(CONCAT(u.FirstName,' ',u.LastName),',') as Calibrators
	FROM [dbo].[CalibratorsToWorkPlan] as cwp
	JOIN [dbo].[Users] as u ON cwp.CalibratorId = u.ID
	WHERE cwp.IsDeleted = 0
	GROUP BY cwp.OrderWorkPlanId;
	
	CREATE UNIQUE CLUSTERED INDEX UC_IDX_WorkPlanCalibrators ON #WorkPlanCalibrators(OrderWorkPlanId)


	-- 4. Statuses (SpecialCareTypeId Statuses)
	DROP TABLE IF EXISTS #WorkPlanStatuses;
	CREATE TABLE #WorkPlanStatuses (
		OrderWorkPlanId INT,
		StatusDescriptionENG NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC,
		StatusDescriptionHEB NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC
	);
	INSERT INTO #WorkPlanStatuses (OrderWorkPlanId, StatusDescriptionENG, StatusDescriptionHEB)
	SELECT OrderWorkPlanId, STRING_AGG(StatusDescriptionENG,',') AS StatusDescriptionENG, STRING_AGG(StatusDescriptionHEB,',') AS StatusDescriptionHEB
	FROM (
		SELECT DISTINCT od.OrderWorkPlanId, s.StatusDescriptionENG, s.StatusDescriptionHEB
		FROM [dbo].[OrderDetails] as od
		JOIN [dbo].[Statuses] as s ON od.SpecialCareTypeId = s.StatusId
	) ds 
	GROUP BY OrderWorkPlanId;

	CREATE UNIQUE CLUSTERED INDEX UC_IDX_WorkPlanStatuses ON #WorkPlanStatuses(OrderWorkPlanId)

	-- 5. Equipment
	DROP TABLE IF EXISTS #WorkPlanEquipment;
	CREATE TABLE #WorkPlanEquipment (
		OrderWorkPlanId INT,
		EquipmentIds NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC,
		EquipmentNames NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC
	);
	INSERT INTO #WorkPlanEquipment (OrderWorkPlanId, EquipmentIds, EquipmentNames)
	SELECT coh.OrderWorkPlanId, STRING_AGG(CAST(coh.MeasurementDeviceId AS NVARCHAR(MAX)),', ') as EquipmentIds, STRING_AGG(ce.Description,', ') as EquipmentNames
	FROM [dbo].[MeasurementDevicesToOrderHeaders] as coh
	JOIN [dbo].[MeasurementDevices] as ce ON coh.MeasurementDeviceId = ce.ID AND ce.IsDeleted = 0
	WHERE coh.IsDeleted = 0 
	GROUP BY coh.OrderWorkPlanId;

	CREATE UNIQUE CLUSTERED INDEX UC_IDX_WorkPlanEquipment ON #WorkPlanEquipment(OrderWorkPlanId)

	-- 6. Special Cares
	DROP TABLE IF EXISTS #WorkPlanSpecialCares;
	CREATE TABLE #WorkPlanSpecialCares (
		OrderWorkPlanId INT,
		SpecialCares NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC
	);
	INSERT INTO #WorkPlanSpecialCares (OrderWorkPlanId, SpecialCares)
	SELECT OrderWorkPlanId, STRING_AGG(CAST(SpecialCareTypeId AS NVARCHAR(MAX)),',') as SpecialCares
	FROM [dbo].[OrderDetails]
	GROUP BY OrderWorkPlanId;

	CREATE UNIQUE CLUSTERED INDEX UC_IDX_WorkPlanSpecialCares ON #WorkPlanSpecialCares(OrderWorkPlanId)

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'SELECT 
  --      MAX(CASE ''',@Page,'''
		--	WHEN ''internal-validator'' THEN itm.MbaReportNumber
		--	WHEN ''external-validator'' THEN itm.MbaReportNumber
		--	WHEN ''validator-orders'' THEN itm.MbaReportNumber	
		--	ELSE wp.[OrderNumber] 
		--END) AS [OrderNumber],
		wp.[OrderNumber],
        MAX(co.[PlacementDate]) AS [CalibDate], -- possible bug. Not clear which date should be used
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
		(SELECT MIN(i9.MbaReportNumber) FROM [dbo].[OrderDetailsItems] as i9 JOIN [dbo].[OrderDetails] as od9 ON od9.OrderDetailId = i9.OrderDetailId WHERE od9.OrderWorkPlanId = wp.[OrderWorkPlanId] AND ISNULL(od9.IsDeleted,0) = 0 AND ISNULL(i9.IsDeleted,0) = 0 AND i9.MbaReportNumber LIKE ''[0-9][0-9][0-9][0-9][0-9][0-9][0-9]/%'') as CalibratorMabaNumber, /* MBA-902: a correlated subquery, not an aggregate over itm. The report number belongs to the ORDER, and aggregating over itm would only see the items the validator status filter let through - on STAGE that is 1 order out of 49 instead of 6, because 3,470 of the 3,471 items carrying a real report number have no calibration status at all. */  
	    COALESCE(MAX(clst.StatusDescriptionENG),''',@ClientConfirmationStatusDefault,''') as ClientConfirmationStatus,
		MAX(wp.ShipTypeDesc) AS ShipTypeDesc,
		MAX(c.ReportRequired) AS PrintedReport,
		MAX(wp.CreatedDate) AS ReceivingDate,
		MAX(wpstat.StatusDescriptionENG) AS WorkPlanStatus,
		MAX(wp.CustomerComment) as CustomerComment,
		-- MBA-792: הנחיות לביצוע — Priority ORDERSTEXT, NEGATIVE-ORD side, served from the local cache.
		-- The positive-ORD side is the printed order document (mostly boilerplate) and is NOT this.
		(SELECT ci.InstructionsText   -- plain text; raw HTML is available via GetOrderInstructionsByOrder
		   FROM dbo.CrmOrderInstructions ci WHERE ci.ORD = wp.OrderSourceId) as OrderInstructions,
		MAX(co.[PlacementDate]) AS [PlacementDate],
		MIN(boxcnt.BoxesCount) as BoxesCount,
		COUNT(1) OVER(PARTITION BY 1 ORDER BY wp.[OrderNumber] ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as ItemsCount
    FROM [dbo].[OrderWorkPlans] as wp'
	,IIF(@FilterExternalOrdersForCalibrator = 1,' JOIN #FilterExternalOrdersForCalibrator as filo ON wp.OrderWorkPlanId = filo.OrderWorkPlanId ',' ')
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
	  LEFT JOIN [dbo].[CustomerSites] as css ON css.CustomerSiteId = od.CustomerSiteId
	',IIF(@SpecialCareTypeIds IS NOT NULL,' JOIN #SpecialCareTypes as sct ON od.SpecialCareTypeId = sct.SpecialCareTypeId ',' ')
	 ,IIF(@MainCategory IS NOT NULL,' JOIN #MainCategory as mainc ON od.MainCategoryId = mainc.ID ',' ')
	 ,IIF(@SecondCategory IS NOT NULL,' JOIN #SecondCategory as secc ON od.SecondaryCategoryId = secc.ID ',' ')
	,'LEFT JOIN #MainCatNames as mcat ON wp.OrderWorkPlanId = mcat.OrderWorkPlanId
	'
	,CASE WHEN @DateFrom IS NOT NULL AND @DateTo IS NOT NULL AND @Page <> N'external-orders' THEN '' ELSE 'LEFT' END
	,'
	JOIN #CarsAndPlacement as co ON wp.OrderWorkPlanId = co.OrderWorkPlanId
	LEFT JOIN #WorkPlanCalibrators as cwp ON wp.OrderWorkPlanId = cwp.OrderWorkPlanId
	LEFT JOIN #WorkPlanStatuses as sp ON wp.OrderWorkPlanId = sp.OrderWorkPlanId
	LEFT JOIN #WorkPlanEquipment as coh ON wp.OrderWorkPlanId = coh.OrderWorkPlanId
	LEFT JOIN #WorkPlanSpecialCares as spc ON wp.OrderWorkPlanId = spc.OrderWorkPlanId	
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
	,CASE WHEN @LoggedInUserEmail IS NOT NULL AND @SourceId IS NOT NULL THEN ' AND wp.SourceId = '+CAST(@SourceId AS NVARCHAR(50))  ELSE ' ' END
	,CASE WHEN @ExcludeRejectedOrders = 1 THEN ' AND COALESCE(wp.ClientConfirmationStatusId,0) NOT IN ('+@ClientConfirmationStatus+') 'ELSE ' ' END
	,CASE WHEN @ClientName IS NOT NULL THEN ' AND c.CustomerName LIKE N''%'+ @ClientName +'%'' 'ELSE ' ' END
	,CASE WHEN @ResolvedCustomerId IS NOT NULL THEN ' AND wp.CustomerId = '+ CAST(@ResolvedCustomerId AS NVARCHAR(20)) +' 'ELSE ' ' END
--	,CASE WHEN @Date IS NOT NULL AND  @Date > '1900-01-01' THEN ' AND wp.AssigmentDate = '''+CAST(@Date as NVARCHAR(MAX)) +''' 'ELSE ' ' END
	,CASE WHEN @Location  IS NOT NULL THEN ' AND IIF(css.CustomerSiteId IS NOT NULL,CONCAT_WS('', '',css.CustomerSiteAddress,css.CustomerSiteState,css.CustomerSiteZIP), CONCAT_WS('', '',c.CustomerAddress, c.CustomerCity)) LIKE N''%'+@Location +'%'' 'ELSE ' ' END
	,CASE WHEN @ProductType IS NOT NULL THEN ' AND od.PartName LIKE N''%'+ @ProductType +'%'' 'ELSE ' ' END
	,CASE WHEN @ProducedIn IS NOT NULL THEN ' AND itm.OrdersDeviceManufacturer LIKE N''%'+ @ProducedIn +'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceModel IS NOT NULL THEN ' AND itm.DeviceModel LIKE N''%'+ @DeviceModel +'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceNumber IS NOT NULL THEN ' AND itm.SerialNumber LIKE N''%'+ @DeviceNumber +'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceManufacturer IS NOT NULL THEN ' AND dm.OrdersDeviceManufacturerDescription LIKE N''%'+ @DeviceManufacturer +'%'''ELSE ' ' END
    ,CASE WHEN @GlobalSearch IS NOT NULL THEN ' AND CONCAT(cwp.[Calibrators],mcf.[MainCategoryName],c.[CustomerCity],c.[CustomerName],scf.[SecondaryCategoryName],sp.[StatusDescriptionENG],wp.[OrderNumber],c.[CustomerCode],wp.[CustomerId]) LIKE N''%'+ @GlobalSearch +'%'''ELSE ' ' END
	,CASE WHEN @WorkPlanOpenDate IS NOT NULL THEN ' AND wp.WorkPlanOpenDate = '''+CAST(@WorkPlanOpenDate as NVARCHAR(MAX)) +''' 'ELSE ' ' END
	,CASE WHEN @Notes IS NOT NULL THEN ' AND wp.Notes LIKE N''%'+ @Notes +'%'''ELSE ' ' END
	,CASE WHEN @ExtIntFilter IS NOT NULL THEN ' AND od.IsInHouse='+CAST(@ExtIntFilter as NVARCHAR(MAX))+' 'ELSE ' ' END
	/* MBA-902: only devices whose calibration is finished reach the validator. */
	,CASE WHEN @Page IN (N'internal-validator',N'external-validator',N'validator-orders')
	      THEN ' AND itm.CalibrationStatusId IN ('+@ValidatorDeviceStatuses+') ' ELSE ' ' END
	,'GROUP BY 
	wp.[CustomerId],
 --   CASE ''',@Page,'''
	--	WHEN ''internal-validator'' THEN itm.MbaReportNumber
	--	WHEN ''external-validator'' THEN itm.MbaReportNumber
	--	WHEN ''validator-orders'' THEN itm.MbaReportNumber
	--ELSE wp.[OrderNumber] 
	--END, 
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
	wp.[IsCancelled],
	wp.OrderSourceId '
  ,  'ORDER BY ' , @OrderBy , CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END , ' OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')
PRINT LEN(@sql)
PRINT CAST(@sql as VARCHAR(MAX))
EXEC (@sql)

END