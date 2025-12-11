-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 05/12/2025
-- Description:	This SP should assign devices to box
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-453
-- =============================================

CREATE   PROCEDURE [dbo].[AssignOrderDetailItemsToBox]
@BarCode NVARCHAR(100),
@OrderDetailsItemIds NVARCHAR(MAX)=NULL,
@Comment NVARCHAR(200) = NULL,
@LoggedInUserEmail NVARCHAR(100),
@IsDelete BIT = 0

AS
BEGIN

SET NOCOUNT ON;


DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

DROP TABLE IF EXISTS #OrderDetailsItemIds
CREATE TABLE #OrderDetailsItemIds
(
OrderDetailsItemId INT
)

INSERT #OrderDetailsItemIds(OrderDetailsItemId)
SELECT Value FROM dbo.ParseCSVToTable(@OrderDetailsItemIds)


DECLARE @Tmp TABLE (PackingBoxId INT);
DECLARE @PackingBoxId INT

IF NOT EXISTS (
		SELECT 1
		FROM [dbo].[PackingBox]
		WHERE [BarCode] = @BarCode
		)
	BEGIN
		INSERT [dbo].[PackingBox] (
			[BarCode]
			,[Comment]
			,[UpdateUserID]
			)
		SELECT @BarCode
			,@Comment
			,@LoggedInUserId
		SET @PackingBoxId = SCOPE_IDENTITY();
	END
ELSE
	BEGIN
		UPDATE [dbo].[PackingBox]
		SET [Comment] = @Comment,
			[UpdateUserID] = @LoggedInUserId,
			[UpdatedDate] = GETDATE(),
			[IsDeleted] = @IsDelete
		OUTPUT deleted.PackingBoxId INTO @Tmp
		WHERE BarCode = @BarCode

	IF @IsDelete = 1
		UPDATE pbi
			SET pbi.IsDeleted = @IsDelete
		FROM [dbo].[PackingBoxToOrderDetailsItems] as pbi
		JOIN @Tmp as t ON pbi.PackingBoxId = t.PackingBoxId
	END


UPDATE pbi
SET [UpdateUserID] = @LoggedInUserId,
	[UpdatedDate] = GETDATE(),
	[IsDeleted] = 1
FROM [dbo].[PackingBoxToOrderDetailsItems] as pbi
	JOIN [dbo].[PackingBox] as pb ON pbi.[PackingBoxId] = pb.PackingBoxId
	LEFT JOIN #OrderDetailsItemIds as itm ON pbi.OrderDetailsItemId = itm.OrderDetailsItemId
WHERE itm.OrderDetailsItemId IS NULL AND pb.BarCode = @BarCode

INSERT INTO [dbo].[PackingBoxToOrderDetailsItems]
           ([OrderDetailsItemId]
           ,[PackingBoxId]
           ,[UpdateUserID]
            )

SELECT 
	itm.OrderDetailsItemId,
	COALESCE((SELECT TOP 1 PackingBoxId FROM @Tmp),@PackingBoxId) AS [PackingBoxId],
	@LoggedInUserId
FROM #OrderDetailsItemIds as itm 
    LEFT JOIN [dbo].[PackingBoxToOrderDetailsItems] as pbi ON pbi.OrderDetailsItemId = itm.OrderDetailsItemId 
WHERE pbi.OrderDetailsItemId IS NULL 
END