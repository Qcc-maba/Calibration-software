CREATE  PROCEDURE [dbo].[GetAllMainCategories]
AS
SELECT mc.ID as Id, 
	   mc.MainCategoryName as EquipmentMainClassNameHEB
FROM [dbo].[MainCategories] as mc
WHERE mc.IsDeleted = 0