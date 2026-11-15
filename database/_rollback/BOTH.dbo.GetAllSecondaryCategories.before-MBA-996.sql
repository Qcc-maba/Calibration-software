/* dbo.GetAllSecondaryCategories as it was on STAGE and PROD (identical) before MBA-996, captured 2026-11-15. */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 01/04/2025
-- Description:	Get secondary categories
-- JiraLink:
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetAllSecondaryCategories]
AS
SELECT ce.ID, ce.SecondaryCategoryName as SecondCategory
FROM [dbo].[SecondaryCategories] as ce
WHERE ce.IsDeleted = 0
GO
