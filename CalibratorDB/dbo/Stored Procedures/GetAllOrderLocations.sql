-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 08/06/2025
-- Description:	This SP return customer locations
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-276
-- =============================================
CREATE   PROCEDURE [dbo].[GetAllOrderLocations]
AS
BEGIN
	SELECT DISTINCT
		   [CustomerCity] as CustomerLocation
		  ,ss.SourceName
	  FROM [dbo].[Customers] as c
	  JOIN [dbo].[Source] as ss ON c.[SourceId] = ss.[SourceId]
	  JOIN [dbo].[OrderDetails] as od ON od.[CustomerId] = c.[CustomerId]
	  WHERE c.[IsDeleted] = 0 AND LEN([CustomerCity]) > 0
END