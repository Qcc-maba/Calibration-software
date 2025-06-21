-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 20/06/2025
-- Description:	This SP return all orders product types
-- JiraLink:
-- =============================================
CREATE    PROCEDURE [dbo].[GetAllOrdersProductTypes]
AS
BEGIN
	SELECT 
		OrdersProductTypeId	
		,OrdersProductTypeName
	FROM [dbo].[OrdersProductTypes]
	WHERE IsDeleted = 0
END