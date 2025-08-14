CREATE   PROCEDURE  [dbo].[GetAllSpecificationReferences]
@SecondaryCategoryId INT = NULL
AS
SELECT [ID]
      ,[Name] as SpecificationReference
      ,[CreatedDate]
      ,[UpdatedDate]
      ,[IsDeleted]
      ,[UpdateUserID]
FROM [dbo].[SpecificationReference]
WHERE [IsDeleted] = 0 AND (@SecondaryCategoryId IS NULL OR SecondaryCategoryId = @SecondaryCategoryId)