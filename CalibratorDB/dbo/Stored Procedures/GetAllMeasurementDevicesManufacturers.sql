

-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 15/06/2025
-- Description:	Get all measurement devices manufacturers
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE  GetAllMeasurementDevicesManufacturers
AS
SELECT [ID]
      ,[Name]
      ,[Description]
  FROM [dbo].[MeasurementDevicesManufacturers]
  WHERE [IsDeleted] = 0