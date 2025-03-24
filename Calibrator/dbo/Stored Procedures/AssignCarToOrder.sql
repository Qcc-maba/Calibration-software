-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/03/2025
-- Description:	This SP should assign a car to a specific order. It should return the status of the operation.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-182
-- =============================================
CREATE   PROCEDURE dbo.AssignCarToOrder
@CarID INT,
@OrderNumber NCHAR(12),
@Date DATE,
@QuartersOfDay NVARCHAR(10)

--EXEC dbo.AssignCarToOrder @CarID = 3,@OrderNumber = 'LA24101404',@Date = '2025-04-11',@QuartersOfDay ='0,1,2,3'

AS
BEGIN

DROP TABLE IF EXISTS #QuartersOfDay
CREATE TABLE #QuartersOfDay
(
QuarterId INT
)

INSERT #QuartersOfDay(QuarterId)
SELECT Value FROM dbo.ParseCSVToTable(@QuartersOfDay)

if (SELECT SUM(QuarterId) FROM #QuartersOfDay) > 6
THROW 51000, 'Incorrect values passed for quaters.', 1;

if NOT EXISTS (
SELECT 1 FROM Orders as o 
WHERE OrderNumber = @OrderNumber --add filters for isdeleted and isactive
)
THROW 51000, 'Incorrect or not active order number passed.', 1;

if NOT EXISTS (
SELECT 1 FROM dbo.Cars as c
WHERE c.CarId = @CarID
)
THROW 51000, 'Incorrect car id passed.', 1;


if exists
(
SELECT 1 FROM [dbo].[CarsToOrder] as cto
WHERE cto.CarId = @CarID AND cto.OrderNumber = @OrderNumber AND cto.AssignDate = @Date
)
THROW 51000, 'Car already assigned to order.', 1;


INSERT [dbo].[CarsToOrder](CarId,OrderNumber,AssignDate,AssignQuater0,AssignQuater1,AssignQuater2,AssignQuater3)
SELECT @CarID as CarID, 
	   @OrderNumber as OrderNumber,
	   @Date as AssignDate,
	   MAX(IIF(QuarterId = 0,1,NULL)) as AssignQuater0,
	   MAX(IIF(QuarterId = 1,1,NULL)) as AssignQuater1,
	   MAX(IIF(QuarterId = 2,1,NULL)) as AssignQuater2,
	   MAX(IIF(QuarterId = 3,1,NULL)) as AssignQuater3
FROM #QuartersOfDay

END