
CREATE PROCEDURE  [dbo].[GetAllCalibratorsCertifications]
AS
SELECT ID, [Name]/*CONCAT([Name],IIF(LEN(DescriptionHeb) > 0,'-',''),DescriptionHeb)*/as [Certificate]
FROM [dbo].[MeasurementsSpecifications]
WHERE IsDeleted = 0