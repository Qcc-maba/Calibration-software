
-- =============================================
-- Author:		Shamailov Slavik
-- Create date: 13/02/2025
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[GetLaboratoryViewDepartmentDelays]
AS
BEGIN

	SET NOCOUNT ON;

	SELECT TOP (100) PERCENT Department, SUM(DISTINCT Delay) AS Delays,
		CASE 
			WHEN SUM(DISTINCT Delay) < 5 THEN 'Green' 
			WHEN SUM(DISTINCT Delay) >= 5 AND SUM(DISTINCT Delay) < 7.5 THEN 'Yellow' 
			WHEN SUM(DISTINCT Delay) >= 7.5 AND SUM(DISTINCT Delay) < 10 THEN 'Orange' 
			WHEN SUM(DISTINCT Delay) >= 10 THEN 'Red' ELSE NULL 
		END  AS Color
	FROM   (
		SELECT TOP (100) PERCENT dbo.CustomerSupportDepartmentParts.Department, ROUND(COUNT(servcalls.SKU) / dbo.CustomerSupportDepartmentParts.Average, 1) AS Delay
		FROM  [31.168.173.93].amaba.dbo.servcalls_view AS servcalls INNER JOIN
				dbo.CustomerSupportDepartmentParts ON servcalls.SKU = dbo.CustomerSupportDepartmentParts.Item
		WHERE   (servcalls.[Service status] = 'נקלט')
		GROUP BY dbo.CustomerSupportDepartmentParts.Department, dbo.CustomerSupportDepartmentParts.Average) AS CustomerSupportDepartmentDelays
	GROUP BY Department
	HAVING        (SUM(DISTINCT Delay) IS NOT NULL)
	ORDER BY Delays

END