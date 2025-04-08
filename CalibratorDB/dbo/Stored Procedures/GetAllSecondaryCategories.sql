
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 01/04/2025
-- Description:	Get main categories
-- JiraLink: 
-- =============================================
CREATE  PROCEDURE [dbo].[GetAllSecondaryCategories]
AS
SELECT DISTINCT SecondCategory
FROM OrderDetails