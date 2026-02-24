-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 16/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE     PROCEDURE [dbo].[GetCalibrationProcessComments]
@OrderDetailsItemId INT,
@IsInternal BIT = 1
AS
BEGIN

SET NOCOUNT ON;

SELECT OrderDetailsItemId
      ,CalibrationProcessCommentId
      ,CAST(DECOMPRESS([CalibrationProcessComment]) as NVARCHAR(MAX)) as [CalibrationProcessComment]
      ,N'orders/SO25000296/a02cc88e-7182-4d1b-afc4-a7367aa15744.pdf' as [CustomerSpecialInstructionsAttachment]
  FROM [dbo].[CalibrationProcessComments]
  WHERE [IsDeleted] = 0 AND OrderDetailsItemId = @OrderDetailsItemId AND IsInternal = @IsInternal

END