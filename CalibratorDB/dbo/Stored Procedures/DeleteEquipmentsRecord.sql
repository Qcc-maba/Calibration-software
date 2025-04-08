-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 08/04/2025
-- Description:	This SP should delete car record
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-210
-- =============================================
CREATE    PROCEDURE [dbo].[DeleteEquipmentsRecord]
@EquipmentsIDs NVARCHAR(MAX)

/*
EXEC [dbo].[DeleteEquipmentsRecord] 
   @EquipmentsIDs = '88,87'
*/

AS
BEGIN

SET NOCOUNT ON;

DROP TABLE IF EXISTS #EquipmentsIDs
CREATE TABLE #EquipmentsIDs
(
EquipmentId INT PRIMARY KEY
)

INSERT #EquipmentsIDs(EquipmentId)
SELECT Value FROM dbo.ParseCSVToTable(@EquipmentsIDs)

BEGIN TRAN

DELETE ce 
FROM dbo.CarsToEquipment as ce
JOIN #EquipmentsIDs as d ON ce.EquipmentId = d.EquipmentId

DELETE c
FROM [dbo].[CalibEquipments] as c
JOIN #EquipmentsIDs as d ON c.ID = d.EquipmentId

COMMIT 

END