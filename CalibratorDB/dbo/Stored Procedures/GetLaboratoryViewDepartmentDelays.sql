
-- =============================================
-- Author:		Shamailov Slavik
-- Create date: 13/02/2025
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[GetLaboratoryViewDepartmentDelays]
AS
BEGIN

SET NOCOUNT ON;

WITH cte
as
(
SELECT dp.Department, 
		COALESCE(SUM(ROUND(dd.cnt * 1.0 / dp.Average, 1)),0) as Delays
FROM [dbo].[DepartmentDelays] as dd
JOIN [dbo].[CustomerSupportDepartmentParts] as dp ON dd.SKU = dp.Item
GROUP BY dp.Department
)
SELECT 
	c.Department,
	c.Delays,
	CASE 
		WHEN c.Delays < 5 THEN 'Green' 
		WHEN c.Delays >= 5 AND c.Delays < 7.5 THEN 'Yellow' 
		WHEN c.Delays >= 7.5 AND c.Delays < 10 THEN 'Orange' 
		WHEN c.Delays >= 10 THEN 'Red' ELSE NULL 
	END  AS Color
FROM cte as c
ORDER BY c.Delays DESC
END