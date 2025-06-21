CREATE   PROCEDURE  [dbo].[GetAllSpecificationReferences]
AS
SELECT [ID]
      ,[Name] as SpecificationReference
      ,[CreatedDate]
      ,[UpdatedDate]
      ,[IsDeleted]
      ,[UpdateUserID]
FROM [dbo].[SpecificationReference]
WHERE [IsDeleted] = 0