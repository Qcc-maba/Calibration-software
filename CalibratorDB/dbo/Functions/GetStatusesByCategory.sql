-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 16/12/2025
-- Description:	Standartize getting statuses
-- JiraLink: 
-- =============================================

CREATE   FUNCTION [dbo].[GetStatusesByCategory](@StatusesCategory NVARCHAR(255))
RETURNS TABLE
AS
RETURN
(
	SELECT s.StatusId,s.StatusDescriptionENG, s.StatusDescriptionHEB
	FROM [dbo].[Statuses] AS s
	JOIN [dbo].[StatusesCategories] AS sc ON s.StatusCategoryId = sc.StatusCategoryId
	WHERE sc.StatusDescriptionENG = @StatusesCategory
)