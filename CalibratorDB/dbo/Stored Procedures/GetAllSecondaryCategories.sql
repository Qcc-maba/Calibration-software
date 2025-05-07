
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 01/04/2025
-- Description:	Get secondary categories
-- JiraLink: 
-- =============================================
CREATE  PROCEDURE [dbo].[GetAllSecondaryCategories]
AS
SELECT ce.ID, ce.Name as  SecondCategory
FROM [dbo].[CalibEquipmentSubClass] as ce
WHERE ce.IsDeleted = 0