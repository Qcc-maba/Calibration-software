
CREATE    PROCEDURE [stg].[MergeMabaComments]
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 16/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
AS
BEGIN

SET NOCOUNT ON;

MERGE INTO [dbo].[MabaComments] AS dest
USING (
	SELECT 
		 cr.PART
		,ss.SourceId
		,cr.CompresedText as [MabaComment]
		,cr.HashText as [TextHash]
		,0 as [UpdateUserID]
	FROM stg.stg_MabaComments as cr
	JOIN [dbo].[Source] as ss ON cr.SourceSystem = ss.SourceName
	) AS source
	ON 	dest.PART = source.PART AND dest.SourceId = source.SourceId
WHEN MATCHED
	AND dest.[TextHash] <> source.[TextHash]
	THEN
		UPDATE
		SET 
			 dest.[MabaComment] = source.[MabaComment]
			,dest.[TextHash] = source.[TextHash]
			,dest.[UpdatedDate] = GETDATE()
			,dest.[UpdateUserID] = source.[UpdateUserID]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [MabaComment]
			,[PART]
			,[SourceId]
			,[TextHash]
			,[UpdateUserID]
			)
		VALUES (
             source.[MabaComment]
			,source.[PART]
			,source.[SourceId]
			,source.[TextHash]
			,source.[UpdateUserID]
			);

	MERGE INTO [dbo].[MabaCommentsToOrderDetails] AS dest
	USING (
		SELECT 
			od.OrderDetailId, od.PART, wp.SourceId , mc.MabaCommentId
		FROM [dbo].[OrderDetails] as od
		JOIN [dbo].[OrderWorkPlans] as wp ON od.OrderWorkPlanId = od.OrderWorkPlanId
		JOIN [dbo].[MabaComments] as mc ON od.PART = mc.PART AND wp.SourceId = mc.SourceId
		) AS source
		ON dest.OrderDetailId = source.OrderDetailId AND dest.MabaCommentId = source.MabaCommentId 
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				[MabaCommentId]
				,[OrderDetailId]
				,[UpdateUserID]
				)
			VALUES (
				source.[MabaCommentId]
				,source.[OrderDetailId]
				,0
				);

END