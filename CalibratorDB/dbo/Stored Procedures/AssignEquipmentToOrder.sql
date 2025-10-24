-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/04/2025
-- Description:	Assign equipment to order
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[AssignEquipmentToOrder]
@OrderID NVARCHAR(100),
@EquipmentIDs NVARCHAR(MAX)='',
@CheckDate DATE = NULL,
@LoggedInUserEmail NVARCHAR(100) = NULL

/*
EXEC dbo.AssignEquipmentToOrder @OrderID = 'SO25000153', @EquipmentIDs = '578,579'
*/
AS
BEGIN

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d
IF @CheckDate IS NULL SET @CheckDate = GETDATE()

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
JOIN [dbo].[MeasurementDevices] as e ON e.ID = t.EquipmentId
JOIN [dbo].[Statuses] as s ON e.MeasurementDeviceStatusId = s.StatusId
WHERE  s.StatusDescriptionENG <> 'Available'
) 
THROW 51000, 'Incorrect or inactive equipment were found in list or equipment not in available state.', 1;

DECLARE @OrderWorkPlanId INT
SELECT @OrderWorkPlanId = OrderWorkPlanId FROM [dbo].[OrderWorkPlans] WHERE OrderNumber= @OrderID


UPDATE [dbo].[MeasurementDevicesToOrderHeaders]
SET IsDeleted = 1, UpdateUserID = @LoggedInUserId
WHERE OrderWorkPlanId = @OrderWorkPlanId

IF (SELECT COUNT(*) FROM #AssociatedEquipmentIDs WHERE EquipmentId > 0) >= 1

INSERT [dbo].[MeasurementDevicesToOrderHeaders]
(
OrderWorkPlanId,
MeasurementDeviceId,
AssigmentDate,
UpdateUserID
)
SELECT 
    @OrderWorkPlanId,
	EquipmentId,
	@CheckDate,
	@LoggedInUserId
FROM #AssociatedEquipmentIDs as aei


UPDATE [dbo].OrderWorkPlans
SET AssigmentDate = @CheckDate
WHERE OrderWorkPlanId = @OrderWorkPlanId

END