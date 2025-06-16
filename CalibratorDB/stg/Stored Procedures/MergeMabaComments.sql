CREATE   PROCEDURE [stg].[MergeMabaComments]
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
		p.OrderDetailId
		,cr.CompresedText as [MabaComment]
		,cr.HashText as [TextHash]
		,0 as [UpdateUserID]
	FROM stg.stg_MabaComments as cr
	JOIN [dbo].[Source] as ss ON cr.SourceSystem = ss.SourceName
	JOIN 
	(
		SELECT 
		wp.SourceId,
		od.OrderDetailId,
		od.PART
		FROM [dbo].[OrderWorkPlans] as wp
		JOIN [dbo].[OrderDetails] as od ON wp.OrderWorkPlanId = od.OrderWorkPlanId
	) as p ON p.PART = cr.PART AND p.SourceId = ss.SourceId
	) AS source
	ON 	dest.OrderDetailId = source.OrderDetailId
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
			,[OrderDetailId]
			,[TextHash]
			,[UpdateUserID]
			)
		VALUES (
             source.[MabaComment]
			,source.[OrderDetailId]
			,source.[TextHash]
			,source.[UpdateUserID]
			);
END