-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 28/04/2025
-- Description:	Assign availability for calibrator
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[AssignOrderItemsStatus]
@UserEmail NVARCHAR(50),
@MbaReportNumber NVARCHAR(20),
@OrderItemStatusId int,
@OrderItemsStatusDate datetime2(0)
/*
DECLARE @dt DATETIME2(0) = GETDATE()

EXEC [dbo].[AssignOrderItemsStatus]
@UserEmail ='sinova_super_admin@gmail.com',
@MbaReportNumber ='2523195/4',
@OrderItemStatusId = 81,
@OrderItemsStatusDate = @dt;
*/
AS
BEGIN
SET NOCOUNT ON;

DECLARE @UserId INT = (SELECT ID FROM [dbo].[Users] WHERE Email = @UserEmail) 

IF NOT EXISTS (
SELECT 1 FROM [dbo].[Users] as u
LEFT JOIN [dbo].[UserRoles] as ur ON u.UserRoleId = ur.UserRoleId
WHERE u.ID = @UserId /*AND ur.UserRoleName = 'Calibrator'*/ and u.IsActive = 1
)
THROW 51000, 'Provided user is not active', 1;

IF NOT EXISTS (
SELECT 1 FROM [dbo].[OrderDetailsItems] as od WHERE od.MbaReportNumber = @MbaReportNumber
)
THROW 51000, 'Provided MbaReportNumber not exists', 1;

IF NOT EXISTS (
SELECT 1
  FROM [dbo].[Statuses] as s
  JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
  WHERE s.StatusId = @OrderItemStatusId AND sc.StatusDescriptionENG = 'ReportStatus'
)
THROW 51000, 'Incorrect ReportStatus provided', 1;

IF EXISTS (
SELECT 1
  FROM [dbo].[OrderItemsStatuses] as ois
  WHERE ois.[MbaReportNumber] = @MbaReportNumber AND 
		ois.[OrderItemStatusDate] = @OrderItemsStatusDate
)
THROW 51000, 'Entry already exists. Please check status date', 1;


INSERT [dbo].[OrderItemsStatuses]
           ([MbaReportNumber]
           ,[OrderItemStatusId]
           ,[OrderItemStatusDate]
           ,[UserId]
           )
	VALUES
			(
			@MbaReportNumber,
			@OrderItemStatusId,
			@OrderItemsStatusDate,
			@UserId 
			)

END