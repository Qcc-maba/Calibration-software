-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 01/04/2025
-- Description:	Get departments list
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[GetDepartments]
AS
SELECT 
	ID,
	DepartmentName
FROM dbo.Departments
WHERE IsDeleted = 0