-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 31/03/2025
-- Description:	Assign car for one or more equipment
-- JiraLink: 
-- =============================================
CREATE PROCEDURE dbo.AssignCarToEquipment
@CarId INT,
@EquipmentName NVARCHAR(800)

/*
EXEC dbo.AssignCarToEquipment @CarId = 1, @EquipmentName = N'603,7bar a'
*/

AS

SET NOCOUNT ON;

BEGIN

DROP TABLE IF EXISTS #Equipment
CREATE TABLE #Equipment
(
EquipmentId INT,
StatusId INT
)
INSERT #Equipment(EquipmentId,StatusId)
SELECT u.ID, u.StatusId FROM dbo.ParseCSVToTable(@EquipmentName) as v
LEFT JOIN [dbo].[CalibEquipments] as u  ON v.Value = u.EquipmentName

IF EXISTS 
(
SELECT 1 FROM #Equipment WHERE EquipmentId IS NULL
UNION ALL
SELECT 1 FROM #Equipment WHERE StatusId IN (31,32)
)
THROW 51000, 'Incorrect or inactive equipment was provided.', 1;

UPDATE c
SET c.CarId = @CarId 
FROM [dbo].[CalibEquipments] as c
JOIN #Equipment as e ON c.ID = e.EquipmentId

END