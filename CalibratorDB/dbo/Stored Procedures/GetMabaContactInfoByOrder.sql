-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 16/04/2025
-- Description:	This SP return customer contact for order
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE dbo.GetMabaContactInfoByOrder
@OrderID NVARCHAR(100)

/*
EXEC [dbo].[GetMabaContactInfoByOrder] 
@OrderID = ''
*/

AS
BEGIN

SET NOCOUNT ON;

SELECT DISTINCT
wp.OrderNumber
,od.CustomerContactName as ContactPersonName
,od.CustomerContactPersonRole as ContactPersonRole
,od.CustomerContactPhone as PhoneNumber
,od.CustomerContactAdditionalPhoneNumber as AdditionalPhoneNumber
,od.CustomerContactEmail as Email
FROM [dbo].[OrderWorkPlans] as wp
JOIN [dbo].[OrderDetails] as od ON wp.OrderWorkPlanId = od.OrderWorkPlanId
WHERE wp.OrderNumber = @OrderID


END