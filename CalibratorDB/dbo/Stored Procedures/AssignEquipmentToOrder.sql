-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/04/2025
-- Description:	Assign equipment to order
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[AssignEquipmentToOrder]
@OrderID INT,
@EquipmentIDs NVARCHAR(200)

/*
EXEC dbo.AssignEquipmentToOrder @OrderID = 1, @EquipmentIDs = '578,579'
*/
AS
BEGIN

SET NOCOUNT ON;

DROP TABLE IF EXISTS #AssociatedEquipmentIDs
CREATE TABLE #AssociatedEquipmentIDs
(
EquipmentId INT
)

INSERT #AssociatedEquipmentIDs(EquipmentId)
SELECT Value FROM dbo.ParseCSVToTable(@EquipmentIDs)

--- Check equipment id's is valid
if EXISTS (
SELECT 1 FROM #AssociatedEquipmentIDs as t
LEFT JOIN [dbo].[CalibEquipments] as e ON e.ID = t.EquipmentId
WHERE  e.ID IS NULL OR e.StatusId <> 30 -- only available equipment
)
THROW 51000, 'Incorrect or inactive equipment were found in list or equipment not in available state.', 1;

INSERT [dbo].[CalibEquipmentsToOrderHeaders]
(
OrderWorkPlanId,
CalibEquipmentId
)
SELECT 
    @OrderID,
	EquipmentId
FROM #AssociatedEquipmentIDs as aei
LEFT JOIN [dbo].[CalibEquipmentsToOrderHeaders] as cih 
		ON cih.CalibEquipmentId = aei.EquipmentId AND cih.OrderWorkPlanId = @OrderID
WHERE aei.EquipmentId IS NULL


END