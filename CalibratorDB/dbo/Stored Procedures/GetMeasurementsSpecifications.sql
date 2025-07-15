-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 15/05/2025
-- Description:	Get all measurements specification
-- JiraLink: 
-- =============================================
CREATE    PROCEDURE [dbo].[GetMeasurementsSpecifications]
AS
SELECT [ID]
      ,[Name]--CONCAT([Name],IIF(LEN(DescriptionHeb) > 0,'-',''),DescriptionHeb) as [Name]
      ,[DepartmentId]
      ,[DescriptionHeb]
      ,[DescriptionEng]
  FROM [dbo].[MeasurementsSpecifications]
  WHERE [IsDeleted] = 0-- and 0 =1