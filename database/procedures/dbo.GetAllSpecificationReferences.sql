/*
    dbo.GetAllSpecificationReferences                                                   MBA-623
    ---------------------------------------------------------------------------------------------
    The reference documents offered in the device and cycle pickers, optionally for one secondary
    category.

    MBA-623 adds Description (shown under the name in the picker), NameEn (the name on an English
    report) and CalculationCase (what the summary computes), so the app stops deriving the last two
    from the name. Soft-deleted documents stay out of the picker; a cycle that already uses one
    still gets its name from dbo.GetCalibrationCycles.
*/
CREATE OR ALTER PROCEDURE [dbo].[GetAllSpecificationReferences]
    @SecondaryCategoryId INT = NULL
AS
SELECT [ID]
      ,[Name] AS SpecificationReference
      ,[Description]
      ,[NameEn]
      ,[CalculationCase]
      ,[CreatedDate]
      ,[UpdatedDate]
      ,[IsDeleted]
      ,[UpdateUserID]
FROM [dbo].[SpecificationReference]
WHERE [IsDeleted] = 0 AND (@SecondaryCategoryId IS NULL OR SecondaryCategoryId = @SecondaryCategoryId)
GO
