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
		,NULLIF(c.[CustomerNameENG],'') as [CustomerNameENG]
		,NULLIF(c.[CustomerPhone],'') as [CustomerPhone]
		,NULLIF(c.[CustomerCity],'') as [CustomerCity]
		,NULLIF(c.[CustomerCityENG],'') as [CustomerCityENG]
		,NULLIF(c.[CustomerAddress],'') as [CustomerAddress]
		,NULLIF(c.[CustomerAddressENG],'') as [CustomerAddressENG]
		,0 as [UpdateUserID]
		,ss.SourceId
		,c.SignatureAmount		
		,c.ShipTypeDescr
		,c.ReportRequired
		,c.CustomerCode
		,u.ID as CustomerSupportContactId
	FROM stg.stg_Customers as c
	JOIN dbo.Source as ss ON c.SourceSystem = ss.SourceName
	LEFT JOIN dbo.[Users] as u ON c.[AgentUserEmail] = u.[Email]
	) AS source
	ON dest.[CustomerIdFromSource] = source.[CustomerIdFromSource]
		AND dest.SourceId = source.SourceId
WHEN MATCHED
		AND
		    (COALESCE(dest.[CustomerName],'') <> COALESCE(source.[CustomerName],'')
		OR COALESCE(dest.[CustomerNameENG],'') <> COALESCE(source.[CustomerNameENG],'')
		OR COALESCE(dest.[CustomerPhone],'') <> COALESCE(source.[CustomerPhone],'')
		OR COALESCE(dest.[CustomerCity],'') <> COALESCE(source.[CustomerCity],'')
		OR COALESCE(dest.[CustomerCityENG],'') <> COALESCE(source.[CustomerCityENG],'')
		OR COALESCE(dest.[CustomerAddress],'') <> COALESCE(source.[CustomerAddress],'')
		OR COALESCE(dest.[CustomerAddressENG],'') <> COALESCE(source.[CustomerAddressENG],'')
		OR COALESCE(dest.[SignatureAmount],0) <> COALESCE(source.[SignatureAmount],0)
		OR COALESCE(dest.[ShipTypeDescr],'') <> COALESCE(source.[ShipTypeDescr],'')
		OR COALESCE(dest.[ReportRequired],'') <> COALESCE(source.[ReportRequired],'')
		OR COALESCE(dest.[CustomerCode],'') <> COALESCE(source.[CustomerCode],'')
		OR COALESCE(dest.[CustomerSupportContactId],'') <> COALESCE(source.[CustomerSupportContactId],'')
		)
	THEN
		UPDATE
		SET 
		     dest.[CustomerName] = source.[CustomerName]
			,dest.[CustomerNameENG] = source.[CustomerNameENG]
			,dest.[CustomerPhone] = source.[CustomerPhone]
			,dest.[CustomerCity] = source.[CustomerCity]
			,dest.[CustomerCityENG] = source.[CustomerCityENG]
			,dest.[CustomerAddress] = source.[CustomerAddress]
			,dest.[CustomerAddressENG] = source.[CustomerAddressENG]
			,dest.[CustomerIdFromSource] = source.[CustomerIdFromSource]
			,dest.[UpdatedDate] = GETDATE()
			,dest.[UpdateUserID] = 0
			,dest.SignatureAmount = source.SignatureAmount
			,dest.ShipTypeDescr = source.ShipTypeDescr
			,dest.ReportRequired = source.ReportRequired
			,dest.[CustomerCode] = source.[CustomerCode]
			,dest.[CustomerSupportContactId] = source.[CustomerSupportContactId]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [CustomerName]
			,[CustomerNameENG]
			,[CustomerPhone]
			,[CustomerCity]
			,[CustomerCityENG]
			,[CustomerAddress]
			,[CustomerAddressENG]
			,[CustomerIdFromSource]
			,[SourceId]
			,[UpdateUserID]
			,[SignatureAmount]
			,[ShipTypeDescr]
			,[ReportRequired]
			,[CustomerCode]
			,[CustomerSupportContactId]
			)
		VALUES (
			 source.[CustomerName]
			,source.[CustomerNameENG]
			,source.[CustomerPhone]
			,source.[CustomerCity]
			,source.[CustomerCityENG]
			,source.[CustomerAddress]
			,source.[CustomerAddressENG]
			,source.[CustomerIdFromSource]
			,source.[SourceId]
			,source.[UpdateUserID]
			,source.SignatureAmount		
			,source.ShipTypeDescr
			,source.ReportRequired
			,source.[CustomerCode]
			,source.[CustomerSupportContactId]
			);

MERGE INTO [dbo].[CustomerSites] AS dest
USING (
	SELECT 
	     cust.[CustomerId]
		,NULLIF(cs.[CustomerSiteAddress],'') as [CustomerSiteAddress]
		,NULLIF(cs.[CustomerSiteState],'') as [CustomerSiteState]
		,NULLIF(cs.[CustomerSiteZIP],'') as [CustomerSiteZIP]
		,NULLIF(cs.[CustomerSitePhone],'') as [CustomerSitePhone]
		,NULLIF(cs.[CustomerSiteDescription],'') as [CustomerSiteDescription]
		,cs.[CustomerSiteCode]
		,GETDATE() AS [CreateDate]
		,GETDATE() AS [UpdatedDate]
		,0 as [UpdateUserID]
		,0 as [IsDeleted]
		,s.SourceId
	FROM stg.stg_CustomerSites as cs
	JOIN dbo.Source as s ON cs.SourceSystem = s.SourceName
	JOIN dbo.Customers as cust ON cust.CustomerIdFromSource = cs.[CustomerId] AND s.SourceId = cust.SourceId
	) AS source
	ON dest.[CustomerId] = source.[CustomerId] AND dest.[CustomerSiteCode] = source.[CustomerSiteCode]
WHEN MATCHED AND 
	(
	   COALESCE(dest.[CustomerSiteAddress],'') <> COALESCE(source.[CustomerSiteAddress],'')
	OR COALESCE(dest.[CustomerSiteState],'') <>  COALESCE(source.[CustomerSiteState],'')
	OR COALESCE(dest.[CustomerSiteZIP],'') <> COALESCE(source.[CustomerSiteZIP],'')
	OR COALESCE(dest.[CustomerSitePhone],'') <> COALESCE(source.[CustomerSitePhone],'')
	OR COALESCE(dest.[CustomerSiteDescription],'') <>  COALESCE(source.[CustomerSiteDescription],'')
	)
	THEN
		UPDATE
		SET  dest.[CustomerSiteAddress] = source.[CustomerSiteAddress]
			,dest.[CustomerSiteState] = source.[CustomerSiteState]
			,dest.[CustomerSiteZIP] = source.[CustomerSiteZIP]
			,dest.[CustomerSitePhone] = source.[CustomerSitePhone]
			,dest.[CustomerSiteDescription] = source.[CustomerSiteDescription]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[UpdateUserID] = source.[UpdateUserID]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[CustomerId]
			,[CustomerSiteAddress]
			,[CustomerSiteState]
			,[CustomerSiteZIP]
			,[CustomerSitePhone]
			,[CustomerSiteDescription]
			,[CustomerSiteCode]
			,[CreateDate]
			,[UpdateUserID]
			,[SourceId]
			)
		VALUES (
			source.[CustomerId]
			,source.[CustomerSiteAddress]
			,source.[CustomerSiteState]
			,source.[CustomerSiteZIP]
			,source.[CustomerSitePhone]
			,source.[CustomerSiteDescription]
			,source.[CustomerSiteCode]
			,source.[CreateDate]
			,source.[UpdateUserID]
			,source.[SourceId]
			);
END