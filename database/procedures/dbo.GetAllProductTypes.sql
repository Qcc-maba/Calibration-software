/*
    dbo.GetAllProductTypes
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
CREATE OR ALTER PROCEDURE [dbo].[GetAllProductTypes]
AS
BEGIN
	SELECT DISTINCT
	       od.PartName as ProductType,
		   wp.[SourceId],
		   s.[SourceDisplayName] AS [SourceName]
	  FROM [dbo].[OrderWorkPlans] as wp
	  JOIN [dbo].[OrderDetails] as od ON od.[OrderWorkPlanId] = wp.[OrderWorkPlanId]
	  LEFT JOIN [dbo].[Source] as s ON wp.SourceId = s.SourceId
	  WHERE od.[IsDeleted] = 0 and wp.[IsCancelled] = 0
END
