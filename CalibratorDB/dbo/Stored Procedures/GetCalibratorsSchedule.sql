-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/05/2025
-- Description:	Get calibrators schedule
-- =============================================
CREATE   PROCEDURE [dbo].[GetCalibratorsSchedule]
@DateFirstWeekDay DATE
AS
BEGIN
    SET NOCOUNT ON;

DROP TABLE IF EXISTS #DateRange
CREATE TABLE #DateRange
(
    OrderWorkPlanId INT,
	CalibrationDate DATE,
	WorkPlanOpenDate DATE,
	CustomerAddress NVARCHAR(100),
	CustomerName NVARCHAR(255)
)
;WITH cte
AS
(
SELECT 0 as d
UNION ALL 
SELECT d + 1 FROM cte
WHERE d < 4
)
INSERT #DateRange (OrderWorkPlanId,CalibrationDate,WorkPlanOpenDate,CustomerAddress,CustomerName)
SELECT DISTINCT 
    wp.OrderWorkPlanId,
	COALESCE(DATEADD(DAY,dt.d,@DateFirstWeekDay),wd.CalibDate) as CalibrationDate,
	wp.WorkPlanOpenDate,
	wd.CustomerAddress as [Location],
	wd.CustomerName
FROM cte as dt
LEFT JOIN [dbo].[OrderDetails] as wd ON DATEADD(DAY,dt.d,@DateFirstWeekDay) = wd.CalibDate
LEFT JOIN [dbo].[OrderWorkPlans] as wp ON wd.OrderWorkPlanId = wp.OrderWorkPlanId

SELECT
	 dr.CalibrationDate	
	,dr.WorkPlanOpenDate
	,dr.CustomerAddress
	,dr.CustomerName
	,dr.OrderWorkPlanId	
	,c.CarIds 
	,ctwp.CalibratorIds
	,cetwp.CalibEquipmentIds
FROM #DateRange as dr
LEFT JOIN 
(
SELECT 
	 cto.OrderWorkPlanId
	,STRING_AGG(cto.CarId,',') as CarIds
FROM [dbo].[CarsToOrder] as cto 
WHERE cto.IsDeleted = 0
GROUP BY cto.OrderWorkPlanId
)c ON c.OrderWorkPlanId = dr.OrderWorkPlanId
LEFT JOIN 
(
	SELECT 
	ctwp.OrderWorkPlanId,
	STRING_AGG(ctwp.CalibratorId,',') AS CalibratorIds
	FROM [dbo].[CalibratorsToWorkPlan] as ctwp 
	WHERE ctwp.IsDeleted = 0
	GROUP BY ctwp.OrderWorkPlanId
) as ctwp ON ctwp.OrderWorkPlanId = dr.OrderWorkPlanId 
LEFT JOIN 
(
	SELECT 
	cetwp.OrderWorkPlanId,
	STRING_AGG(cetwp.CalibEquipmentId,',') AS CalibEquipmentIds
	FROM [dbo].[CalibEquipmentsToOrderHeaders] as cetwp
	WHERE cetwp.IsDeleted = 0
	GROUP BY cetwp.OrderWorkPlanId
) as cetwp ON cetwp.OrderWorkPlanId = dr.OrderWorkPlanId 

END