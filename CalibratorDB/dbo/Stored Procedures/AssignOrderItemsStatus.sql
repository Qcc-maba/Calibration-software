-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 28/04/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[AssignOrderItemsStatus]
@UserEmail NVARCHAR(50),
@OrderDetailsItemId INT,
@StatusName NVARCHAR(100),
@StatusCategoryName  NVARCHAR(100)
/*
EXEC [dbo].[AssignOrderItemsStatus]
@UserEmail ='sinova_super_admin@gmail.com',
@OrderDetailsItemId = 1309,
@StatusName = 'StandbyModeCustomerReason',
@StatusCategoryName= 'ReportStatus'
*/
AS
BEGIN
SET NOCOUNT ON;

DECLARE @UserId INT = (SELECT ID FROM [dbo].[Users] WHERE Email = @UserEmail) 

DECLARE @StatusId INT,@StatusCategoryId INT

SELECT 
@StatusId = s.StatusId,
@StatusCategoryId = sc.StatusCategoryId
FROM [Calibrator].[dbo].[Statuses] as s
JOIN [Calibrator].[dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
WHERE s.StatusDescriptionENG = @StatusName AND sc.StatusDescriptionENG = @StatusCategoryName

IF NOT EXISTS (
SELECT 1 FROM [dbo].[Users] as u
LEFT JOIN [dbo].[UserRoles] as ur ON u.UserRoleId = ur.UserRoleId
WHERE u.ID = @UserId /*AND ur.UserRoleName = 'Calibrator'*/ and u.IsActive = 1
)
THROW 51000, 'Provided user is not active', 1;

IF @StatusCategoryName NOT IN (N'ReportStatus',N'CalibrationStatuses')
THROW 51000, 'Incorrect ReportStatus or CalibrationStatus provided', 1;

IF NOT EXISTS 
(SELECT 1 FROM [dbo].[OrderItemsStatusesHistory] WHERE [OrderDetailsItemId] = @OrderDetailsItemId
AND [StatusId] = @StatusId AND [StatusCategoryId] = @StatusCategoryId
)
INSERT [dbo].[OrderItemsStatusesHistory]
           ([OrderDetailsItemId]
           ,[StatusId]
           ,[StatusCategoryId]
           ,[UpdateUserID]
           )
	VALUES
			(
            @OrderDetailsItemId,
            @StatusId,
            @StatusCategoryId,
            @UserId
			)
            
IF @StatusCategoryName = 'ReportStatus'

    UPDATE [dbo].[OrderDetailsItems]
    SET [CalibrationReportStatusId] = @StatusId
    WHERE [OrderDetailsItemId]  = @OrderDetailsItemId AND COALESCE([CalibrationReportStatusId],0) <> @StatusId

ELSE 
    UPDATE [dbo].[OrderDetailsItems]
    SET [CalibrationStatusId] = @StatusId
    WHERE [OrderDetailsItemId] = @OrderDetailsItemId AND COALESCE([CalibrationStatusId],0) <> @StatusId



END