-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/03/2025
-- Description:	This SP should return a list of all company employees
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-168
-- =============================================
CREATE   PROCEDURE [dbo].[GetAllEmployees]

-- EXEC dbo.GetAllEmployees

AS
SELECT u.ID,
	   u.FirstName,
	   u.LastName
FROM [dbo].[Users] as u
WHERE u.IsActive = 1 AND u.ID > 0