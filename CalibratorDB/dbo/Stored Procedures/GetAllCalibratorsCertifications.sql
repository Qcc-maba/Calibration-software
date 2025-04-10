CREATE PROCEDURE  [dbo].[GetAllCalibratorsCertifications]
AS
SELECT ID,Certificate
FROM [dbo].[CalibratorsCertifications]
WHERE IsDeleted = 0