-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 19/08/2025
-- Description:	Stop calibration: User will add comment to specific order item and set status to CalibrationFailed
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[CalibrationStoppedComment]
@LoggedInUserEmail NVARCHAR(100),
@OrderDetailsItemId INT,
@CalibrationStoppedComment NVARCHAR(1000)=''

/*
EXEC [dbo].[CalibrationStoppedComment]
@LoggedInUserEmail =N'sinova_calibrator@gmail.com',
@OrderDetailsItemId =2361,
@CalibrationStoppedComment = N'Test comment'
*/
AS
BEGIN

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

DECLARE @StatusCategoryId INT
SELECT @StatusCategoryId = s.StatusCategoryId
FROM [dbo].[Statuses] as s
JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
WHERE sc.StatusDescriptionENG = N'CalibrationStatuses' AND s.StatusDescriptionENG = N'CalibrationFailed'

UPDATE [dbo].[OrderDetailsItems]
SET CalibrationStoppedComment = @CalibrationStoppedComment,
	CalibrationStatusId = @StatusCategoryId,
	UpdateUserID = @LoggedInUserId,
	UpdatedDate = GETDATE()
WHERE OrderDetailsItemId = @OrderDetailsItemId

END