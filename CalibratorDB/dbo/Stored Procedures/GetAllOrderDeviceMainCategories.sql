-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 08/06/2025
-- Description:	This SP return all orders main categories
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-276
-- =============================================
CREATE   PROCEDURE [dbo].[GetAllOrderDeviceMainCategories]
AS
BEGIN
	SELECT mc.ID as [OrdersMainCategoryId], 
		   mc.MainCategoryName as [OrderDeviceMainCategories]
	FROM [dbo].[MainCategories] as mc
	WHERE mc.IsDeleted = 0
END