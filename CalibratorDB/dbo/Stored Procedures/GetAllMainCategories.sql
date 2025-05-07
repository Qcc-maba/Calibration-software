
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 07/05/2025
-- Description:	Get main categories
-- JiraLink: 
-- =============================================
CREATE  PROCEDURE [dbo].[GetAllMainCategories]
AS
SELECT mc.ID, 
	   mc.EquipmentMainClassNameHEB,	
	   mc.Description,
	   mc.EquipmentMainClassNameENG
FROM [dbo].[CalibEquipmentMainClass] as mc
WHERE mc.IsDeleted = 0