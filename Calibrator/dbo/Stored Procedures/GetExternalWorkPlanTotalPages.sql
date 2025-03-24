

-- =============================================
-- Author:		Shamailov Slavik
-- Create date: 11/03/2025
-- Description:	Get number of pages for work plan data
-- =============================================
CREATE PROCEDURE [dbo].[GetExternalWorkPlanTotalPages]
    @RowsOfPage AS INT = 10,                 -- Result page size
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

	Declare @PagesCount int

    -- Create a table variable to hold filtered results
    DECLARE @FilteredResults TABLE (
        [OrderNumber] NVARCHAR(100),
        [CalibDate] DATETIME,
        [Klita] NVARCHAR(100),
        [SpecialCares] NVARCHAR(100),
        [CustomerName] NVARCHAR(100),
        [CustomerCity] NVARCHAR(100),
        [MainCategoties] NVARCHAR(100),
        [WorkPlanOpenDate] DATETIME,
        [Cars] NVARCHAR(100),
        [Calibrators] NVARCHAR(100),
        [Equipments] NVARCHAR(100),
        [Notes] NVARCHAR(100),
        [PartName] NVARCHAR(100),
        [DeviceDescription] NVARCHAR(100),
        [DepartmentName] NVARCHAR(100),
        [MbaReportNumber] NVARCHAR(100),
        [SerialNumber] NVARCHAR(100),
		[DeviceManufacturer] NVARCHAR(100),
		[DeviceModel] NVARCHAR(100)

    );

    -- Insert filtered data
    INSERT INTO @FilteredResults
    SELECT *
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

    -- Get total pages count
    SELECT @PagesCount = (COUNT(*) + @RowsOfPage - 1) / @RowsOfPage
    FROM @FilteredResults;

	select @PagesCount

	SET ANSI_WARNINGS ON;
END
