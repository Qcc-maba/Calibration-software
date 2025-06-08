-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 08/06/2025
-- Description:	This SP return all orders main categories
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-276
-- =============================================
CREATE   PROCEDURE [dbo].[GetAllOrderDeviceMainCategories]
AS
BEGIN
	SELECT DISTINCT
	       omc.[OrdersMainCategoryId]
		  ,omc.OrdersMainCategoryName as [OrderDeviceMainCategories]
		  ,ss.SourceName
	  FROM [dbo].[OrderWorkPlans] as wp
	  JOIN [dbo].[Source] as ss ON wp.[SourceId] = ss.[SourceId]
	  JOIN [dbo].[OrderDetails] as od ON od.[OrderWorkPlanId] = wp.[OrderWorkPlanId]
	  JOIN [dbo].[OrdersMainCategories] as omc ON omc.[OrdersMainCategoryId] = od.[OrdersMainCategoryId]
	  WHERE od.[IsDeleted] = 0 and wp.[IsCancelled] = 0
END