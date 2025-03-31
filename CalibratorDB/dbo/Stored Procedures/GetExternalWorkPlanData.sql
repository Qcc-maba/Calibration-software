
-- =============================================
-- Author:		Shamailov Slavik
-- Create date: 05/03/2025
-- Description:	Get work plan data
-- =============================================
CREATE PROCEDURE [dbo].[GetExternalWorkPlanData]
    @PageNumber AS INT = 1,                  -- Resulting page for pagination, starting in 1
    @RowsOfPage AS INT = 10,                 -- Result page size
    @OrderBy AS NVARCHAR(MAX) = 'CalibDate', -- OrderBy column
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

    -- Create a table variable to hold filtered results
    DECLARE @FilteredResults TABLE (
        [OrderNumber] NVARCHAR(20),
        [Date] DATETIME,
        [WorkOrder] NVARCHAR(100),
        [SpecialCares] NVARCHAR(100),
        [ClientName] NVARCHAR(255),
        [Location] NVARCHAR(100),
        [MainCategoties] NVARCHAR(100),
        [WorkPlanOpenDate] DATETIME,
        [Cars] NVARCHAR(100),
        [Calibrators] NVARCHAR(100),
        [Equipments] NVARCHAR(100),
        [Notes] NVARCHAR(100),
        [ProductType] NVARCHAR(100),
        [DeviceDescription] NVARCHAR(100),
        [MainCategory] NVARCHAR(100),
        [MbaReportNumber] NVARCHAR(100),
        [PrintedNumber] NVARCHAR(100),
		[ProducedIn] NVARCHAR(255),
		[DeviceModel] NVARCHAR(100),
		[IsCancelled] BIT

    );

    -- Insert filtered data
    INSERT INTO @FilteredResults
    SELECT 
        [OrderNumber],
        [CalibDate],
        [Klita],
        [SpecialCares],
        [CustomerName],
        [CustomerCity],
        [MainCategoties],
        [WorkPlanOpenDate],
        [Cars],
        [Calibrators],
        [Equipments],
        [Notes],
        [PartName],
        [DeviceDescription],
        [DepartmentName],
        [MbaReportNumber],
        [SerialNumber],
		[DeviceManufacturer],
		[DeviceModel],
		[IsCancelled]
    FROM [Calibrator].[dbo].[vwWorkPlan] WITH(NOLOCK)
    WHERE 

	    (@ClientName IS NULL OR [CustomerName] LIKE '%' + @ClientName + '%') AND
        --(@CalibDateFrom IS NULL OR [CalibDate] >= @CalibDateFrom) AND
        --(@CalibDateTo IS NULL OR [CalibDate] <= @CalibDateTo) AND
		(@Date IS NULL OR [CalibDate] = @Date) AND
        (@MainCategory IS NULL OR [DepartmentName] LIKE '%' + @MainCategory + '%') AND
		(@SecondCategory IS NULL OR [DeviceDescription] LIKE '%' + @SecondCategory + '%') AND
        (@Location IS NULL OR [CustomerCity] LIKE '%' + @Location + '%') AND
		(@ProductType IS NULL OR [PartName] LIKE '%' + @ProductType + '%') AND
        (@ProducedIn IS NULL OR [DeviceManufacturer] LIKE '%' + @ProducedIn + '%') AND
		(@AssignedCalibrators IS NULL OR [Calibrators] LIKE '%' + @AssignedCalibrators + '%') AND
        -- Modified Calibrators filter to handle individual words in comma-separated list
        --(@Calibrators IS NULL OR 
        --    [Calibrators] LIKE '%' + @Calibrators + '%' OR 
        --    [Calibrators] LIKE '%' + @Calibrators + ',%' OR 
        --    [Calibrators] LIKE '%,' + @Calibrators + '%' OR
        --    [Calibrators] LIKE '%,' + @Calibrators + ',%') AND        		        
		(@DeviceModel IS NULL OR [DeviceModel] LIKE '%' + @DeviceModel + '%') AND
        (@PrintedNumber IS NULL OR [SerialNumber] LIKE '%' + @PrintedNumber + '%');

    -- Return filtered data with pagination and sorting
    SELECT *
    FROM @FilteredResults
    ORDER BY 
        CASE WHEN @OrderBy = 'Date' AND @OrderByAsc = 1 THEN [Date] END,
        CASE WHEN @OrderBy = 'Date' AND @OrderByAsc = 0 THEN [Date] END DESC,
        CASE WHEN @OrderBy = 'OrderNumber' AND @OrderByAsc = 1 THEN OrderNumber END,
        CASE WHEN @OrderBy = 'OrderNumber' AND @OrderByAsc = 0 THEN OrderNumber END DESC,
        CASE WHEN @OrderBy = 'SpecialCares' AND @OrderByAsc = 1 THEN SpecialCares END,
        CASE WHEN @OrderBy = 'SpecialCares' AND @OrderByAsc = 0 THEN SpecialCares END DESC,
        CASE WHEN @OrderBy = 'ClientName' AND @OrderByAsc = 1 THEN ClientName END,
        CASE WHEN @OrderBy = 'ClientName' AND @OrderByAsc = 0 THEN ClientName END DESC,
        CASE WHEN @OrderBy = 'Location' AND @OrderByAsc = 1 THEN [Location] END,
        CASE WHEN @OrderBy = 'Location' AND @OrderByAsc = 0 THEN [Location] END DESC,
        CASE WHEN @OrderBy = 'MainCategoties' AND @OrderByAsc = 1 THEN MainCategoties END,
        CASE WHEN @OrderBy = 'MainCategoties' AND @OrderByAsc = 0 THEN MainCategoties END DESC,
        CASE WHEN @OrderBy = 'WorkPlanOpenDate' AND @OrderByAsc = 1 THEN WorkPlanOpenDate END,
        CASE WHEN @OrderBy = 'WorkPlanOpenDate' AND @OrderByAsc = 0 THEN WorkPlanOpenDate END DESC,
        CASE WHEN @OrderBy = 'Cars' AND @OrderByAsc = 1 THEN Cars END,
        CASE WHEN @OrderBy = 'Cars' AND @OrderByAsc = 0 THEN Cars END DESC,
        CASE WHEN @OrderBy = 'Calibrators' AND @OrderByAsc = 1 THEN Calibrators END,
        CASE WHEN @OrderBy = 'Calibrators' AND @OrderByAsc = 0 THEN Calibrators END DESC,
        CASE WHEN @OrderBy = 'Equipments' AND @OrderByAsc = 1 THEN Equipments END,
        CASE WHEN @OrderBy = 'Equipments' AND @OrderByAsc = 0 THEN Equipments END DESC,
		CASE WHEN @OrderBy = 'Notes' AND @OrderByAsc = 1 THEN Notes END,
		CASE WHEN @OrderBy = 'Notes' AND @OrderByAsc = 0 THEN Notes END DESC
		
    OFFSET (@PageNumber-1) * @RowsOfPage ROWS FETCH NEXT @RowsOfPage ROWS ONLY;

END