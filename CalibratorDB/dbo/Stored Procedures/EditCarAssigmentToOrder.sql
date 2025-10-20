-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 24/04/2025
-- Description:	This SP should unassign a car to a specific order.
-- JiraLink: 
-- =============================================
CREATE    PROCEDURE [dbo].[EditCarAssigmentToOrder]
@CarID INT,
@Date DATE,
@QuartersOfDay NVARCHAR(10),
@LoggedInUserEmail NVARCHAR(100) = NULL
--EXEC dbo.EditCarAssigmentToOrder @CarID = 3,@Date = '2025-04-11',@QuartersOfDay ='0,1,2,3'

AS
BEGIN

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

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

UPDATE [dbo].[CarsToOrder]
SET AssignQuater0 = IIF(@part0db = 0,NULL,AssignQuater0),
	AssignQuater1 = IIF(@part1db = 0,NULL,AssignQuater1),
	AssignQuater2 = IIF(@part2db = 0,NULL,AssignQuater2),
	AssignQuater3 = IIF(@part3db = 0,NULL,AssignQuater3),
	UpdatedDate = GETDATE(),
	UpdateUserID = @LoggedInUserId
WHERE CarId = @CarID AND AssignDate = @Date

END