-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 15/05/2025
-- Description:	Get all measurements specification
-- JiraLink: 
-- =============================================
CREATE    PROCEDURE [dbo].[GetMeasurementsSpecifications]
AS
SELECT mc.[ID]
      ,mc.[Name]--CONCAT([Name],IIF(LEN(DescriptionHeb) > 0,'-',''),DescriptionHeb) as [Name]
      ,mc.MainCategoryId as  [DepartmentId]
      ,mc.[DescriptionHeb]
      ,mc.[DescriptionEng]
  FROM [dbo].[MeasurementsSpecifications] as mc
  WHERE [IsDeleted] = 0