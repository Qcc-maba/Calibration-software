CREATE   PROCEDURE [dbo].[GetCarAssignmentByDateRange]
@StartDate DATE,
@EndDate DATE
AS
BEGIN

SET NOCOUNT ON;

IF DATEDIFF(DAY,@StartDate,@EndDate) > 35 THROW 51000, 'Date range too wide. Can not be more than 31 days.', 1;

    ;WITH dates
    as
    ( SELECT @StartDate as AssignDate
    UNION ALL
    SELECT DATEADD(day,1,AssignDate) as AssignDate
    FROM dates
    WHERE DATEADD(day,1,AssignDate) <=@EndDate
    )
    SELECT 
        COALESCE(cto.[AssignDate] ,d.[AssignDate]) as [AssignDate]
        ,cto.[AssignQuater0]
        ,cto.[AssignQuater1]
        ,cto.[AssignQuater2]
        ,cto.[AssignQuater3]
        ,cto.[OrderWorkPlanId]
        ,cto.[CarId]
    FROM dates as d
    LEFT JOIN [dbo].[CarsToOrder] as cto ON d.AssignDate = cto.AssignDate


END