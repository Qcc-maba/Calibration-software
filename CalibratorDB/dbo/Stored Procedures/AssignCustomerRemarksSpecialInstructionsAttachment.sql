-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 24/02/2026
-- Description:	
-- JiraLink: 
-- =============================================
CREATE    PROCEDURE [dbo].[AssignCustomerRemarksSpecialInstructionsAttachment]
@CustomerId INT,
@LoggedInUserEmail NVARCHAR(50),
@CustomerSpecialInstructionsAttachment NVARCHAR(200)
AS
BEGIN

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d


IF EXISTS (SELECT 1 FROM [dbo].[CustomerRemarks] WHERE CustomerId=@CustomerId)
UPDATE [dbo].[CustomerRemarks] 
	SET [CustomerSpecialInstructionsAttachment] = @CustomerSpecialInstructionsAttachment
WHERE [CustomerId] =@CustomerId

ELSE
		INSERT [dbo].[CustomerRemarks] 
		       (
				 [CustomerId]
				,[SourceId]
				,[CustomerSpecialInstructionsAttachment]
				,[UpdateUserID]
				)
			VALUES (
				 @CustomerId
				,@SourceId
				,@CustomerSpecialInstructionsAttachment
				,@LoggedInUserId
				);

END