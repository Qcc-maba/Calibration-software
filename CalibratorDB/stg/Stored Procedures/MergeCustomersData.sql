CREATE   PROCEDURE [stg].[MergeCustomersData]
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
AS
BEGIN
SET NOCOUNT ON;

MERGE INTO [dbo].[Customers] AS dest
USING (
	SELECT
	     c.[CustomerID] as [CustomerIdFromSource]
		,c.[CustomerName]
		,c.[CustomerPhone]
		,c.[CustomerCity]
		,c.[CustomerAddress]
		,0 as [UpdateUserID]
		,ss.SourceId
		,c.SignatureAmount		
		,c.ShipTypeDescr
		,c.ReportRequired
		,c.CustomerCode
	FROM stg.stg_Customers as c
	JOIN dbo.Source as ss ON c.SourceSystem = ss.SourceName
	) AS source
	ON dest.[CustomerIdFromSource] = source.[CustomerIdFromSource]
		AND dest.SourceId = source.SourceId
WHEN MATCHED
		AND
		    (COALESCE(dest.[CustomerName],'') <> COALESCE(source.[CustomerName],'')
		OR COALESCE(dest.[CustomerPhone],'') <> COALESCE(source.[CustomerPhone],'')
		OR COALESCE(dest.[CustomerCity],'') <> COALESCE(source.[CustomerCity],'')
		OR COALESCE(dest.[CustomerAddress],'') <> COALESCE(source.[CustomerAddress],'')
		OR COALESCE(dest.[SignatureAmount],0) <> COALESCE(source.[SignatureAmount],0)
		OR COALESCE(dest.[ShipTypeDescr],'') <> COALESCE(source.[ShipTypeDescr],'')
		OR COALESCE(dest.[ReportRequired],'') <> COALESCE(source.[ReportRequired],'')
		OR COALESCE(dest.[CustomerCode],'') <> COALESCE(source.[CustomerCode],'')
		)
	THEN
		UPDATE
		SET 
		     dest.[CustomerName] = source.[CustomerName]
			,dest.[CustomerPhone] = source.[CustomerPhone]
			,dest.[CustomerCity] = source.[CustomerCity]
			,dest.[CustomerAddress] = source.[CustomerAddress]
			,dest.[CustomerIdFromSource] = source.[CustomerIdFromSource]
			,dest.[UpdatedDate] = GETDATE()
			,dest.[UpdateUserID] = 0
			,dest.SignatureAmount = source.SignatureAmount
			,dest.ShipTypeDescr = source.ShipTypeDescr
			,dest.ReportRequired = source.ReportRequired
			,dest.[CustomerCode] = source.[CustomerCode]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [CustomerName]
			,[CustomerPhone]
			,[CustomerCity]
			,[CustomerAddress]
			,[CustomerIdFromSource]
			,[SourceId]
			,[UpdateUserID]
			,[SignatureAmount]
			,[ShipTypeDescr]
			,[ReportRequired]
			,[CustomerCode]
			)
		VALUES (
			 source.[CustomerName]
			,source.[CustomerPhone]
			,source.[CustomerCity]
			,source.[CustomerAddress]
			,source.[CustomerIdFromSource]
			,source.[SourceId]
			,source.[UpdateUserID]
			,source.SignatureAmount		
			,source.ShipTypeDescr
			,source.ReportRequired
			,source.[CustomerCode]
			);
END