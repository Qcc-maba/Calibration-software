CREATE   PROCEDURE [stg].[MergeCustomerRemarks]
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 06/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
AS
BEGIN

SET NOCOUNT ON;

MERGE INTO [dbo].[CustomerRemarks] AS dest
USING (
	SELECT 
	     c.CustomerId
		,cr.CompresedText as [CustomerRemark]
		,cr.CUST as [CustomerIdFromSource]
		,ss.[SourceId]
		,cr.HashText as [TextHash]
		,0 as [UpdateUserID]
	FROM stg.stg_CustomerRemarks as cr
	JOIN [dbo].[Source] as ss ON cr.SourceSystem = ss.SourceName
	JOIN [dbo].[Customers] as c ON c.CustomerIdFromSource = cr.CUST AND c.[SourceId] = ss.[SourceId]
	) AS source
	ON 	dest.[CustomerId] = source.[CustomerId]
		AND dest.[SourceId] = source.[SourceId]
WHEN MATCHED
	AND dest.[TextHash] <> source.[TextHash]
	THEN
		UPDATE
		SET 
			 dest.[CustomerRemark] = source.[CustomerRemark]
			,dest.[TextHash] = source.[TextHash]
			,dest.[UpdatedDate] = GETDATE()
			,dest.[UpdateUserID] = source.[UpdateUserID]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
		     [CustomerId]
			,[CustomerRemark]
			,[CustomerIdFromSource]
			,[SourceId]
			,[TextHash]
			,[UpdateUserID]
			)
		VALUES (
             source.CustomerId
			,source.[CustomerRemark]
			,source.[CustomerIdFromSource]
			,source.[SourceId]
			,source.[TextHash]
			,source.[UpdateUserID]
			);
END