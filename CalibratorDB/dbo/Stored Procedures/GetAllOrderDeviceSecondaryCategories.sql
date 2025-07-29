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
		   osc.ID as OrdersSecondaryCategoryId
	      ,osc.SecondaryCategoryName as [OrderDeviceSecondaryCategories]
	  FROM [dbo].[SecondaryCategories] as osc 
	  WHERE osc.[IsDeleted] = 0
END