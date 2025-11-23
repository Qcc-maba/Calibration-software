-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 19/11/2025
-- Description:	Mark/unmark the devices with checkbox
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-41
-- =============================================
CREATE     PROCEDURE [dbo].[AssignValidatedStatusToOrderDevice]
@UserEmail NVARCHAR(50),
@OrderDetailsItemId INT,
@IsChecked BIT
/*
EXEC [dbo].[AssignValidatedStatusToOrderDevice]
@UserEmail ='sinova_super_admin@gmail.com',
@OrderDetailsItemId = 1309,
@IsChecked = 0
*/
AS
BEGIN
SET NOCOUNT ON;

DECLARE @UserId INT = (SELECT ID FROM [dbo].[Users] WHERE Email = @UserEmail) 

IF NOT EXISTS (
SELECT 1 FROM [dbo].[Users] as u
LEFT JOIN [dbo].[UserRoles] as ur ON u.UserRoleId = ur.UserRoleId
WHERE u.ID = @UserId AND u.IsActive = 1
)
THROW 51000, 'Provided user is not active', 1;

UPDATE [dbo].[OrderDetailsItems]
SET IsChecked = @IsChecked,
	UpdateUserID = @UserId,
	UpdatedDate = GETDATE()
WHERE OrderDetailsItemId = @OrderDetailsItemId

END