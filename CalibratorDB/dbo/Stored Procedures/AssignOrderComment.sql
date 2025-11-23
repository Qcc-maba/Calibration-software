-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 23/11/2025
-- Description:	Add comment to order
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-442
-- =============================================
CREATE   PROCEDURE [dbo].[AssignOrderComment]
@OrderWorplanId INT,
@CustometComment NVARCHAR(200)
/*
EXEC [dbo].[AssignOrderComment]
@OrderWorplanId = -10,
@CustometComment =N'test comment'
*/
AS
BEGIN
SET NOCOUNT ON;

IF NOT EXISTS (
SELECT 1 FROM [dbo].[OrderWorkPlans] as wp
WHERE OrderWorkPlanId = @OrderWorplanId
)
THROW 51000, 'Order with provided id not exists', 1;

UPDATE [dbo].[OrderWorkPlans] 
SET CustometComment = @CustometComment
WHERE OrderWorkPlanId = @OrderWorplanId

END