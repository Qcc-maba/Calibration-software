-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 15/05/2025
-- Description:	Get all measurements specification
-- JiraLink: 
-- =============================================
CREATE    PROCEDURE [dbo].[GetMeasurementsSpecifications]
AS
SELECT [ID]
      ,[Name]
      ,[DepartmentId]
      ,[DescriptionHeb]
      ,[DescriptionEng]
  FROM [dbo].[MeasurementsSpecifications]
  WHERE [IsDeleted] = 0