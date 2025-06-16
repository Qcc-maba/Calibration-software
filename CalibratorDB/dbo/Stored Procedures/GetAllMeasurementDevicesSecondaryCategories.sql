

-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 15/06/2025
-- Description:	Get secondary categories
-- JiraLink: 
-- =============================================
CREATE PROCEDURE  GetAllMeasurementDevicesSecondaryCategories
AS
SELECT ce.ID, ce.Name as  SecondCategory
FROM [dbo].[MeasurementDevicesSubClass] as ce
WHERE ce.IsDeleted = 0