CREATE  PROCEDURE [dbo].[GetAllMainCategories]
AS
SELECT mc.OrdersMainCategoryId as Id, 
	   mc.OrdersMainCategoryName as EquipmentMainClassNameHEB
FROM [dbo].[OrdersMainCategories] as mc
WHERE mc.IsDeleted = 0