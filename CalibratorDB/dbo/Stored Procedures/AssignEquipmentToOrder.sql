-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/04/2025
-- Description:	Assign equipment to order
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE dbo.AssignEquipmentToOrder
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

/*
if NOT EXISTS (
SELECT 1 FROM [dbo].[Users] WHERE Email = @Email AND IsActive = 1
)
THROW 51000, 'Incorrect or inactive user provided.', 1;

DECLARE @UserId INT
SELECT @UserId = ID FROM [dbo].[Users] WHERE Email = @Email*/

INSERT [dbo].[CalibEquipmentsToOrderHeaders]
(
OrderId,
CalibEquipmentId
)
SELECT 
    @OrderID,
	EquipmentId
FROM #AssociatedEquipmentIDs


END