-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 26/11/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[AssingMabaComments]
@MabaCommentId INT,
@MabaComment NVARCHAR(MAX)
AS
BEGIN

SET NOCOUNT ON;
 
  UPDATE [dbo].[MabaComments] 
  SET [MabaComment] = COMPRESS(@MabaComment)
  WHERE MabaCommentId = @MabaCommentId

END