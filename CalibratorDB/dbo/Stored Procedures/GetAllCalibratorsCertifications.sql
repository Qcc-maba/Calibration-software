CREATE PROCEDURE  [dbo].[GetAllCalibratorsCertifications]
AS
SELECT ID, [Name] as [Certificate]
FROM [dbo].[MeasurementsSpecifications]
WHERE IsDeleted = 0