-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 15/05/2025
-- Description:	Get all measurements specification
-- JiraLink: 
-- =============================================
CREATE    PROCEDURE [dbo].[GetMeasurementsSpecifications]
@MainCategoryId INT = NULL,
@SecondarycategoryId INT = NULL
AS
SELECT DISTINCT
       mc.[ID]
      ,mc.Name as [Name]
      ,mc.MainCategoryId as  [DepartmentId]
  FROM [dbo].[MeasurementsSpecifications] as mc
  JOIN [dbo].[MeasurementsSpecificationsToSecondCategory] as sc ON mc.ID = sc.MeasurementsSpecificationId AND sc.[IsDeleted] = 0
  WHERE mc.[IsDeleted] = 0
  AND (@MainCategoryId IS NULL OR mc.MainCategoryId = @MainCategoryId)
  AND (@SecondarycategoryId IS NULL OR sc.SecondaryCategoryId = @SecondarycategoryId)