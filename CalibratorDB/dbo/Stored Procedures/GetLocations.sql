-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 06/05/2025
-- Description:	Get location list
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[GetLocations]
AS
SELECT 
	DISTINCT LocationArea
FROM dbo.Users
WHERE LEN(LocationArea) >0