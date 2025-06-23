-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 16/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE     PROCEDURE [dbo].[GetCalibrationProcessComments]
@OrderDetailsItemId INT
AS
BEGIN

SET NOCOUNT ON;

SELECT OrderDetailsItemId
      ,CAST(DECOMPRESS([CalibrationProcessCommentComment]) as NVARCHAR(MAX)) as [CalibrationProcessCommentComment]
  FROM [dbo].[CalibrationProcessComments]
  WHERE [IsDeleted] = 0 AND OrderDetailsItemId = @OrderDetailsItemId

END