-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 08/06/2025
-- Description:	This SP return customers for orders
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-276
-- =============================================
CREATE   PROCEDURE [dbo].[GetAllProductTypes]
AS
BEGIN
	SELECT DISTINCT
	       od.PartName as ProductType
	  FROM [dbo].[OrderWorkPlans] as wp
	  JOIN [dbo].[OrderDetails] as od ON od.[OrderWorkPlanId] = wp.[OrderWorkPlanId]
	  WHERE od.[IsDeleted] = 0 and wp.[IsCancelled] = 0
END