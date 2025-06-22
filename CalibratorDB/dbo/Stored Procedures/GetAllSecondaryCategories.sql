
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 01/04/2025
-- Description:	Get secondary categories
-- JiraLink: 
-- =============================================
CREATE  PROCEDURE [dbo].[GetAllSecondaryCategories]
AS
SELECT OrdersSecondaryCategoryId as ID, ce.OrdersSecondaryCategoryName as  SecondCategory
FROM [dbo].[OrdersSecondaryCategories] as ce
WHERE ce.IsDeleted = 0