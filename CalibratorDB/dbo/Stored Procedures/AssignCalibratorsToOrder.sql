-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/03/2025
-- Description:	This SP should assign calibrators to a specific order. 
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-180
-- =============================================

CREATE   PROCEDURE [dbo].[AssignCalibratorsToOrder]
@OrderNumber NCHAR(12),
@StartDate DATETIME2(0),
@CalibratorIDs NVARCHAR(300),
@Note NVARCHAR(255),
@CarId INT = NULL,
@LoggedInUserEmail NVARCHAR(100) = NULL

--exec dbo.AssignCalibratorsToOrder @OrderNumber = N'LA25100557', @StartDate = '2025-03-17 16:23:00', @CalibratorIDs = '2,6,7,8', @Note = N'test record'
AS
BEGIN

SET NOCOUNT ON;


DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

DROP TABLE IF EXISTS #CalibratorIDs
CREATE TABLE #CalibratorIDs
(
CalibratorID INT
)

INSERT #CalibratorIDs(CalibratorID)
SELECT Value FROM dbo.ParseCSVToTable(@CalibratorIDs)

--- Check if all users are valid
if EXISTS (
SELECT 1 FROM #CalibratorIDs as u
LEFT JOIN [dbo].[Users] as ul ON u.CalibratorID = ul.ID
WHERE ul.ID IS NULL OR ul.IsActive = 0
)
THROW 51000, 'Incorrect or inactive calibrators were found in list.', 1;

DECLARE @WorkPlanId INT

SELECT @WorkPlanId = wp.OrderWorkPlanId FROM [dbo].[OrderWorkPlans]  as wp
WHERE wp.OrderNumber = @OrderNumber 


UPDATE [dbo].[OrderWorkPlans]
SET Notes = @Note
WHERE OrderWorkPlanId = @WorkPlanId

UPDATE dbo.CalibratorsToWorkPlan
SET UpdatedDate = GETDATE(),
    UpdateUserID = @LoggedInUserId,
    IsDeleted = 0
WHERE OrderWorkPlanId = @WorkPlanId and IsDeleted = 1

INSERT dbo.CalibratorsToWorkPlan(OrderWorkPlanId,CalibratorId,AssigmentDate,UpdateUserID,CarId)
SELECT DISTINCT @WorkPlanId, c.CalibratorID, @StartDate,@LoggedInUserId,@CarId
FROM #CalibratorIDs as c 
LEFT JOIN dbo.CalibratorsToWorkPlan as wp ON c.CalibratorID = wp.CalibratorId AND wp.OrderWorkPlanId = @WorkPlanId
WHERE wp.CalibratorId IS NULL


END