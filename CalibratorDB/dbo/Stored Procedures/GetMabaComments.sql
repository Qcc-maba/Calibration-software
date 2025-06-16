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

SELECT [OrderDetailId]
      ,CAST(DECOMPRESS([MabaComment]) as NVARCHAR(MAX)) as [MabaComment]
  FROM [dbo].[MabaComments]
  WHERE [IsDeleted] = 0 AND [OrderDetailId] = @OrderDetailId

END