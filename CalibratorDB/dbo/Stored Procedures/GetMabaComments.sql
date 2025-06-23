-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 16/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[GetMabaComments]
@OrderDetailId INT
AS
BEGIN

SET NOCOUNT ON;

SELECT r.OrderDetailId
      ,CAST(DECOMPRESS(m.[MabaComment]) as NVARCHAR(MAX)) as [MabaComment]
  FROM [dbo].[MabaComments] as m
  JOIN [dbo].[MabaCommentsToOrderDetails] as r ON m.MabaCommentId = r.MabaCommentId
  WHERE m.[IsDeleted] = 0 AND r.OrderDetailId = @OrderDetailId

END