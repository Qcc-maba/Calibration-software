-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 16/04/2025
-- Description:	This SP return customer contact for order
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[GetMabaContactInfoByOrder]
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
,cc.CustomerContactName as ContactPersonName
,cc.CustomerContactPersonRole as ContactPersonRole
,cc.CustomerContactPhone as PhoneNumber
,cc.CustomerContactAdditionalPhoneNumber as AdditionalPhoneNumber
,cc.CustomerContactEmail as Email
FROM [dbo].[OrderWorkPlans] as wp
JOIN [dbo].[OrderDetails] as od ON wp.OrderWorkPlanId = od.OrderWorkPlanId
JOIN [dbo].[CustomerContacts] as cc ON od.CustomerId = cc.CustomerId
WHERE wp.OrderNumber = @OrderID and wp.IsCancelled = 0


END