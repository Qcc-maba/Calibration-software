-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 08/06/2025
-- Description:	This SP return all orders secondary categories
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-276
-- =============================================
CREATE   PROCEDURE [dbo].[GetAllOrderDeviceSecondaryCategories]
AS
BEGIN
	SELECT DISTINCT
		   osc.OrdersSecondaryCategoryId
	      ,osc.OrdersSecondaryCategoryName as [OrderDeviceSecondaryCategories]
	  FROM [dbo].[OrderWorkPlans] as wp
	  JOIN [dbo].[OrderDetails] as od ON od.[OrderWorkPlanId] = wp.[OrderWorkPlanId]
	  JOIN [dbo].[OrderDetailsItems] as odi ON odi.[OrderDetailId] = od.[OrderDetailId]
	  JOIN [dbo].[OrdersSecondaryCategories] as osc ON osc.[OrdersSecondaryCategoryId] = odi.[OrdersSecondaryCategoryId]
	  WHERE od.[IsDeleted] = 0 and wp.[IsCancelled] = 0
END