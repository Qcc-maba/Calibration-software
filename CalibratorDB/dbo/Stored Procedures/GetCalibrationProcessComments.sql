-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 16/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE     PROCEDURE [dbo].[GetCalibrationProcessComments]
@OrderDetailsId INT
AS
BEGIN

SET NOCOUNT ON;

SELECT OrderDetailsId
      ,CAST(DECOMPRESS([CalibrationProcessCommentComment]) as NVARCHAR(MAX)) as [CalibrationProcessCommentComment]
  FROM [dbo].[CalibrationProcessComments]
  WHERE [IsDeleted] = 0 AND OrderDetailsId = @OrderDetailsId

END