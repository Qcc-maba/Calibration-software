/*
    dbo.GetAllOrderClients
    ---------------------------------------------------------------------------------------------
    Returns dbo.Source.SourceDisplayName aliased as SourceName.

    SourceName itself cannot be renamed: it is the join key the whole Priority sync runs on
    (stg.SourceSystem = Source.SourceName, in six Merge procedures), and Priority sends the
    literal 'SEPHARM'. Renaming it would silently stop SE PHARMA syncing. The display name is a
    separate column, and the alias keeps the result-set contract identical.
*/
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 08/06/2025
-- Description:	This SP return customers for orders
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-276
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetAllOrderClients]
AS
BEGIN
	SELECT DISTINCT
	       c.CustomerId	
	      ,c.CustomerName	
		  ,c.CustomerPhone	
		  ,c.CustomerCity	
		  ,c.CustomerAddress
		  ,c.SourceId
		  ,ss.SourceDisplayName AS SourceName
	  FROM [dbo].[Customers] as c
	  JOIN [dbo].[Source] as ss ON c.[SourceId] = ss.[SourceId]
	  JOIN [dbo].[OrderWorkPlans] as od ON od.[CustomerId] = c.[CustomerId]
	  WHERE c.[IsDeleted] = 0
END
