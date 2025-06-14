
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 07/05/2025
-- Description:	Get main categories
-- JiraLink: 
-- =============================================
CREATE  PROCEDURE [dbo].[GetAllMainCategories]
AS
SELECT mc.Id, 
	   mc.NameHebrew as EquipmentMainClassNameHEB,	
	   NULL as Description,
	   mc.NameEnglish as EquipmentMainClassNameENG
FROM [dbo].[MeasurementDevicesMainClasses] as mc
WHERE mc.IsDeleted = 0