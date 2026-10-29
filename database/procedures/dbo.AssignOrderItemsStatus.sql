/*
    dbo.AssignOrderItemsStatus                                                         MBA-1008
    ---------------------------------------------------------------------------------------------
    Records a report or calibration status for one order line item, in OrderItemsStatusesHistory
    and on OrderDetailsItems.

    Written down from the STAGE definition on 2026-10-29; it had no file in git. Author of the
    original: Eduard Kudlaiev, 28/04/2025.

    Unknown user vs inactive user
    -----------------------------
    The procedure resolved @UserEmail to an id and then refused anyone not active - so an e-mail
    with NO row in Users was reported as 'Provided user is not active'. That is how the MBA-1007
    bench test on 2026-10-29 lost its status changes: the signed-in login had no Users row on
    STAGE, the message pointed at an IsActive flag that did not exist, and the web app showed the
    operator nothing at all (its side is fixed in the same ticket).

    The two cases now raise different texts. Both stay THROW 51000, and the web app matches on the
    text, so keep these strings as they are:
        'Provided user does not exist'
        'Provided user is not active'

    Nothing else changed: the status and category lookups, the history insert and the update are
    the STAGE body as it was.
*/
CREATE OR ALTER PROCEDURE [dbo].[AssignOrderItemsStatus]
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
FROM [dbo].[Statuses] as s
JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
WHERE s.StatusDescriptionENG = @StatusName AND sc.StatusDescriptionENG = @StatusCategoryName

IF @UserId IS NULL
THROW 51000, 'Provided user does not exist', 1;

IF NOT EXISTS (
SELECT 1 FROM [dbo].[Users] as u
LEFT JOIN [dbo].[UserRoles] as ur ON u.UserRoleId = ur.UserRoleId
WHERE u.ID = @UserId AND u.IsActive = 1
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
    WHERE [OrderDetailsItemId]  = @OrderDetailsItemId --AND COALESCE([CalibrationReportStatusId],0) <> @StatusId

ELSE
    UPDATE [dbo].[OrderDetailsItems]
    SET [CalibrationStatusId] = @StatusId
    WHERE [OrderDetailsItemId] = @OrderDetailsItemId --AND COALESCE([CalibrationStatusId],0) <> @StatusId



END
