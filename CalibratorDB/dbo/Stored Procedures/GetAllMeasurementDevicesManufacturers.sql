

-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 15/06/2025
-- Description:	Get all measurement devices manufacturers
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE  [dbo].[GetAllMeasurementDevicesManufacturers]
AS
SELECT DISTINCT
       Manufacturer as Name
  FROM [dbo].[MeasurementDevices]
  WHERE [IsDeleted] = 0 AND Manufacturer IS NOT NULL