

-- =============================================
-- Author:		<Slavik Shamailov>
-- Create date: <29/01/2025>
-- Description:	Returns Department names from Priority
-- =============================================

CREATE PROCEDURE [dbo].[GetDepartmentFromERP]
AS
BEGIN

	SET NOCOUNT ON;

    -- Get Departments
	SELECT	TOP (100) PERCENT DEPTNAME, DEPTDES
	FROM    [31.168.173.93].amaba.dbo.DEPT
	WHERE   (DEPTNAME <> '') AND (DEPTDES <> '')
	ORDER BY DEPTDES;	

END