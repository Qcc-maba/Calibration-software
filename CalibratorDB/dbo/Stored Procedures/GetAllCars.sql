
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/03/2025
-- Description:	This SP should get the day range return a list of all cars with their schedule. The schedule should contain all days of the week with detailed information on car availability for each quarter of the day.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-177
-- =============================================
CREATE   PROCEDURE [dbo].[GetAllCars]
@StartWeekDate DATE,
@EndWeekDate DATE 

--exec dbo.GetAllCars @StartWeekDate = '2025-03-10', @EndWeekDate = '2025-03-17'

AS
BEGIN

/*Prepare list of cars with defined dates*/
DROP TABLE IF EXISTS #DateRange
CREATE TABLE #DateRange
(
ID INT NOT NULL,
MabaNumber INT NULL,
Model NVARCHAR(20) NOT NULL,
LicenseNumber NVARCHAR(11) NOT NULL,
Seats TINYINT NOT NULL,
DayDate DATE NOT NULL,
CarStatusId INT
)
;WITH cte
AS
(
SELECT 1 as d
UNION ALL 
SELECT d + 1 FROM cte
WHERE d < 7
)
INSERT #DateRange (ID,MabaNumber,Model,LicenseNumber,Seats,DayDate,CarStatusId)
SELECT 
    c.CarId,
	c.MabaNumber,
	c.Model,
	c.LicenseNumber,
	c.Seats,
	DATEADD(DAY,dt.d-1,@StartWeekDate) as Weekdaydt,
	c.CarStatusId
FROM cte as dt
CROSS JOIN [dbo].[Cars] as c
WHERE DATEADD(DAY,d-1,@StartWeekDate) <= @EndWeekDate AND c.IsDeleted = 0

SELECT dr.ID as CarId,
	dr.MabaNumber,
	dr.Model,
	dr.LicenseNumber,
	dr.Seats,
	dr.DayDate,
	wp.OrderNumber,
	cto.AssignDate,
	cto.AssignQuater0,
	cto.AssignQuater1,
	cto.AssignQuater2,
	cto.AssignQuater3,
	s.StatusDescriptionENG as CarStatusENG,
	s.StatusDescriptionHEB as CarStatusHEB
FROM #DateRange as dr
LEFT JOIN [dbo].[CarsToOrder] as cto ON dr.ID = cto.CarId AND dr.DayDate = cto.AssignDate AND cto.IsDeleted = 0
LEFT JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderWorkPlanId = cto.OrderWorkPlanId  AND wp.IsCancelled = 0
LEFT JOIN [dbo].[Statuses] as s ON s.StatusId = dr.CarStatusId
ORDER BY dr.Id ,dr.DayDate

END