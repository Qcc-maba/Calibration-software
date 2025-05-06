-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/04/2025
-- Description:	Assign equipment to order
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[AssignEquipmentToOrder]
@OrderID NVARCHAR(100),
@EquipmentIDs NVARCHAR(MAX)=''

/*
EXEC dbo.AssignEquipmentToOrder @OrderID = 'LA25100036', @EquipmentIDs = '578,579'
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
if @EquipmentIDs IS NOT NULL AND EXISTS (
SELECT 1 FROM #AssociatedEquipmentIDs as t
JOIN [dbo].[CalibEquipments] as e ON e.ID = t.EquipmentId
WHERE  e.StatusId <> 30 -- only available equipment
) 
THROW 51000, 'Incorrect or inactive equipment were found in list or equipment not in available state.', 1;

DECLARE @OrderWorkPlanId INT
SELECT @OrderWorkPlanId = OrderWorkPlanId FROM [dbo].[OrderWorkPlans] WHERE OrderNumber= @OrderID


UPDATE [dbo].[CalibEquipmentsToOrderHeaders]
SET IsDeleted = 1
WHERE OrderWorkPlanId = @OrderWorkPlanId

IF (SELECT COUNT(*) FROM #AssociatedEquipmentIDs) >= 1

INSERT [dbo].[CalibEquipmentsToOrderHeaders]
(
OrderWorkPlanId,
CalibEquipmentId
)
SELECT 
    @OrderWorkPlanId,
	EquipmentId
FROM #AssociatedEquipmentIDs as aei



END