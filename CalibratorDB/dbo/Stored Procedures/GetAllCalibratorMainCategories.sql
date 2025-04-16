-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 16/04/2025
-- Description:	This SP should return all main categories
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-178
-- =============================================
CREATE PROCEDURE [dbo].[GetAllCalibratorMainCategories]
--EXEC dbo.[GetAllCalibratorMainCategories]

AS 	

SELECT DISTINCT MainCategory
FROM [dbo].[OrderDetails]