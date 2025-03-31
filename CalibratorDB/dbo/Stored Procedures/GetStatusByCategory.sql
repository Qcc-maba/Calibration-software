-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 27/03/2025
-- Description:	Get all statuses for specified categoty
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE dbo.GetStatusByCategory
@StatusDescriptionENG NVARCHAR(255)

/*
EXEC dbo.GetStatusByCategory @StatusDescriptionENG = N'CarStatus'
*/

AS
BEGIN

If NOT EXISTS (SELECT 1 FROM [dbo].[StatusesCategories] as c
				WHERE c.StatusDescriptionENG = @StatusDescriptionENG)
THROW 51000, 'Incorrect category provided.', 1;

SELECT s.StatusId
	   ,s.StatusDescriptionENG
	   ,s.StatusDescriptionHEB
FROM [dbo].[StatusesCategories] as c
JOIN [dbo].[Statuses] as s ON c.StatusCategoryId = s.StatusCategoryId
WHERE c.StatusDescriptionENG = @StatusDescriptionENG

END