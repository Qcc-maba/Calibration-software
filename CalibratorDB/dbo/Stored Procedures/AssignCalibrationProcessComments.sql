-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 28/01/2027
-- Description:	Procedure to assign calibration process comment 
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[AssignCalibrationProcessComments]
@LoggedInUserEmail NVARCHAR(50),
@OrderDetailsItemId INT,
@CalibrationProcessCommentId INT = NULL,
@CalibrationProcessComment NVARCHAR(MAX) = NULL,
@IsInternal BIT = 1,
@CalibrationProcessCommentIdToDelete NVARCHAR(MAX) = NULL
AS
BEGIN

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

-- Insert or update internal calibration process comment
  IF @CalibrationProcessComment IS NOT NULL
		  INSERT [dbo].[CalibrationProcessComments]
			(
			   [OrderDetailsItemId]
			  ,[CalibrationProcessComment]
			  ,[TextHash]
			  ,[CreateDate]
			  ,[UpdateUserID]
			  ,[IsDeleted]
			  ,[IsInternal]
		   )
		   SELECT
			@OrderDetailsItemId,
			COMPRESS(@CalibrationProcessComment),
			BINARY_CHECKSUM(@CalibrationProcessComment),
			GETDATE(),
			@LoggedInUserId,
			0,
			@IsInternal
			WHERE @IsInternal = 0 OR
			NOT EXISTS (SELECT 1 FROM [dbo].[CalibrationProcessComments] 
				WHERE [OrderDetailsItemId] = @OrderDetailsItemId AND LEN(LTRIM(RTRIM(@CalibrationProcessComment))) > 1 AND IsInternal = 1)

	IF @CalibrationProcessCommentId IS NOT NULL
		UPDATE [dbo].[CalibrationProcessComments]
			SET [CalibrationProcessComment] = IIF(@CalibrationProcessComment IS NULL,[CalibrationProcessComment],COMPRESS(@CalibrationProcessComment))
			  ,[TextHash] = BINARY_CHECKSUM(IIF(@CalibrationProcessComment IS NULL,[CalibrationProcessComment],@CalibrationProcessComment))
			  ,[UpdatedDate] = GETDATE()
			  ,[UpdateUserID] = @LoggedInUserId
		WHERE OrderDetailsItemId = @OrderDetailsItemId  AND CalibrationProcessCommentId = @CalibrationProcessCommentId
	
	IF @CalibrationProcessCommentIdToDelete IS NOT NULL
	UPDATE [dbo].[CalibrationProcessComments]
		SET [IsDeleted] = 1,
		[UpdateUserID] = @LoggedInUserId
	WHERE OrderDetailsItemId = @OrderDetailsItemId AND CalibrationProcessCommentId IN (SELECT value FROM STRING_SPLIT(@CalibrationProcessCommentIdToDelete,','))

END