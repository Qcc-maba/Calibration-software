-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 23/11/2025
-- Description:	Add comment to order
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-442
-- =============================================
CREATE   PROCEDURE [dbo].[AssignOrderComment]
@OrderWorkPlanId INT,
@CustomerComment NVARCHAR(200)
/*
EXEC [dbo].[AssignOrderComment]
@OrderWorkPlanId = 10,
@CustomerComment =N'test comment'
*/
AS
BEGIN
SET NOCOUNT ON;

IF NOT EXISTS (
SELECT 1 FROM [dbo].[OrderWorkPlans] as wp
WHERE OrderWorkPlanId = @OrderWorkPlanId
)
THROW 51000, 'Order with provided id not exists', 1;

UPDATE [dbo].[OrderWorkPlans] 
SET CustomerComment = @CustomerComment
WHERE OrderWorkPlanId = @OrderWorkPlanId

END