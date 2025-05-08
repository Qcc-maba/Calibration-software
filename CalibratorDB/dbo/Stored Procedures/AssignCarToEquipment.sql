-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 31/03/2025
-- Description:	Assign car for one or more equipment
-- JiraLink: 
-- =============================================
CREATE PROCEDURE [dbo].[AssignCarToEquipment]
@CarId INT,
@EquipmentIds NVARCHAR(MAX),
@LoggedInUserEmail NVARCHAR(50) = NULL

/*
EXEC dbo.AssignCarToEquipment @CarId = 1, @EquipmentIds = '2621'
*/

AS

SET NOCOUNT ON;

BEGIN

DECLARE @Userid INT = 0
IF @LoggedInUserEmail IS NOT NULL
SELECT @Userid = ID FROM dbo.Users WHERE Email = @LoggedInUserEmail

DROP TABLE IF EXISTS #Equipment
CREATE TABLE #Equipment
(
EquipmentId INT,
StatusId INT
)
INSERT #Equipment(EquipmentId,StatusId)
SELECT u.ID, u.StatusId FROM dbo.ParseCSVToTable(@EquipmentIds) as v
LEFT JOIN [dbo].[CalibEquipments] as u  ON v.Value = u.ID

IF EXISTS 
(
SELECT 1 FROM #Equipment WHERE EquipmentId IS NULL
UNION ALL
SELECT 1 FROM #Equipment as e
  JOIN [Calibrator].[dbo].[Statuses] as s ON e.StatusId = s.StatusId
  WHERE s.StatusDescriptionENG <> N'Available'
)
THROW 51000, 'Incorrect or inactive equipment was provided.', 1;

INSERT INTO [dbo].[CarsToEquipment]
           ([CarId]
           ,[EquipmentId]
           ,[UpdateUserID])

SELECT 
	@CarId ,
	e.EquipmentId,
	@Userid
FROM #Equipment as e 
LEFT JOIN [dbo].[CarsToEquipment] as cte ON cte.CarId = @CarId AND e.EquipmentId = cte.EquipmentId
WHERE cte.EquipmentId IS NULL
END