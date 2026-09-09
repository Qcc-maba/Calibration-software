/*
    dbo.GetAllOrderLocations
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
-- Description:	This SP return customer locations
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-276
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetAllOrderLocations]
AS
BEGIN
	SELECT DISTINCT
		   c.[CustomerCity] as CustomerLocation,
		   c.[CustomerId],
		   od.[SourceId],
		   s.[SourceDisplayName] AS [SourceName]
	  FROM [dbo].[Customers] as c
	  JOIN [dbo].[OrderWorkPlans] as od ON od.[CustomerId] = c.[CustomerId]
	  JOIN [dbo].[Source] as s ON od.SourceId = s.SourceId
	  WHERE c.[IsDeleted] = 0 AND LEN([CustomerCity]) > 0
END
