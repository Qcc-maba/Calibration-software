-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 24/04/2025
-- Description:	This SP should unassign a car to a specific order.
-- JiraLink: 
-- =============================================
CREATE    PROCEDURE [dbo].[EditCarAssigmentToOrder]
@CarID INT,
@OrderNumber NCHAR(12),
@Date DATE,
@QuartersOfDay NVARCHAR(10),
@LoggedInUserEmail NVARCHAR(100) = NULL
--EXEC dbo.EditCarAssigmentToOrder @CarID = 3,@OrderNumber = 'LA25101669',@Date = '2025-04-11',@QuartersOfDay ='0,1,2,3'

AS
BEGIN

DECLARE @Userid INT
IF @LoggedInUserEmail IS NOT NULL
SELECT @Userid = ID FROM dbo.Users WHERE Email = @LoggedInUserEmail

DROP TABLE IF EXISTS #QuartersOfDay
CREATE TABLE #QuartersOfDay
(
QuarterId INT
)

INSERT #QuartersOfDay(QuarterId)
SELECT Value FROM dbo.ParseCSVToTable(@QuartersOfDay)

if (SELECT SUM(QuarterId) FROM #QuartersOfDay) > 6
THROW 51000, 'Incorrect values passed for quaters.', 1;

DECLARE @OrderWorkPlanId INT
SELECT @OrderWorkPlanId =  o.OrderWorkPlanId FROM [dbo].[OrderWorkPlans] as o 
WHERE o.OrderNumber = @OrderNumber AND o.IsCancelled = 0
IF @OrderWorkPlanId IS NULL
THROW 51000, 'Incorrect or not active order number passed.', 1;

if NOT EXISTS (
SELECT 1 FROM dbo.Cars as c
WHERE c.CarId = @CarID
)
THROW 51000, 'Incorrect car id passed.', 1;

DECLARE 
@part0db BIT,
@part1db BIT,
@part2db BIT,
@part3db BIT,
@exists BIT
-- inital parameters assigment
SELECT  
    @part0db = MAX(CASE WHEN QuarterId = 0 THEN 0 ELSE NULL END),
    @part1db = MAX(CASE WHEN QuarterId = 1 THEN 0 ELSE NULL END),
    @part2db = MAX(CASE WHEN QuarterId = 2 THEN 0 ELSE NULL END),
    @part3db = MAX(CASE WHEN QuarterId = 3 THEN 0 ELSE NULL END)
FROM #QuartersOfDay;
-- get data from db and merge results
SELECT  @part0db =  COALESCE(@part0db,AssignQuater0),
		@part1db =  COALESCE(@part1db,AssignQuater1),
		@part2db =  COALESCE(@part2db,AssignQuater2),
		@part3db =  COALESCE(@part3db,AssignQuater3)
FROM [dbo].[CarsToOrder] as cto
WHERE cto.CarId = @CarID AND cto.OrderWorkPlanId = @OrderWorkPlanId 
		AND cto.AssignDate = @Date

UPDATE [dbo].[CarsToOrder]
SET AssignQuater0 = NULLIF(@part0db,0),
	AssignQuater1 = NULLIF(@part1db,0),
	AssignQuater2 = NULLIF(@part2db,0),
	AssignQuater3 = NULLIF(@part3db,0),
	UpdatedDate = GETDATE(),
	UpdateUserID = @Userid
WHERE CarId = @CarID AND OrderWorkPlanId = @OrderWorkPlanId 
		AND AssignDate = @Date

END