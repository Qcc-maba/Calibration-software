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
	FROM stg.stg_Customers as c
	JOIN dbo.Source as ss ON c.SourceSystem = ss.SourceName
	) AS source
	ON dest.[CustomerIdFromSource] = source.[CustomerIdFromSource]
		AND dest.SourceId = source.SourceId
WHEN MATCHED
		AND dest.[CustomerName] <> source.[CustomerName]
		AND dest.[CustomerPhone] <> source.[CustomerPhone]
		AND dest.[CustomerCity] <> source.[CustomerCity]
		AND dest.[CustomerAddress] <> source.[CustomerAddress]
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
			);
END