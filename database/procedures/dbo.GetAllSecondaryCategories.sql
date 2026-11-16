SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 01/04/2025
-- Description:	Get secondary categories
-- JiraLink:
--
-- 2026-11-15 - MBA-996: MainCategoryId added as the last column. dbo.AssignCustomerDevicesData
--              refuses a secondary category of another main category (54209), so the portal's
--              add-device form offers only the secondaries of the chosen main category, and needs
--              to know which that is. Callers read columns by name; the first two are unchanged.
--              Before: database/_rollback/BOTH.dbo.GetAllSecondaryCategories.before-MBA-996.sql
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetAllSecondaryCategories]
AS
SELECT ce.ID, ce.SecondaryCategoryName as SecondCategory, ce.MainCategoryId
FROM [dbo].[SecondaryCategories] as ce
WHERE ce.IsDeleted = 0
GO
