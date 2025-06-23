-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 08/06/2025
-- Description:	This SP return customers for orders
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-276
-- =============================================
CREATE   PROCEDURE [dbo].[GetAllOrderClients]
AS
BEGIN
	SELECT DISTINCT
	       c.CustomerId	
	      ,c.CustomerName	
		  ,c.CustomerPhone	
		  ,c.CustomerCity	
		  ,c.CustomerAddress
		  ,ss.SourceName
	  FROM [dbo].[Customers] as c
	  JOIN [dbo].[Source] as ss ON c.[SourceId] = ss.[SourceId]
	  JOIN [dbo].[OrderWorkPlans] as od ON od.[CustomerId] = c.[CustomerId]
	  WHERE c.[IsDeleted] = 0
END