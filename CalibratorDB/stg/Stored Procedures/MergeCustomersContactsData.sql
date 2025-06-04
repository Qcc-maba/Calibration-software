CREATE    PROCEDURE stg.MergeCustomersContactsData
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 04/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
AS
BEGIN

	SET NOCOUNT ON;

	MERGE INTO [dbo].[CustomerContacts] AS dest
	USING (
		SELECT 
			 c.[CustomerId]
			,cc.[CustomerContactName]
			,cc.[CustomerContactPersonRole]
			,cc.[CustomerContactPhone]
			,cc.[CustomerContactAdditionalPhoneNumber]
			,cc.[CustomerContactEmail]
			,cc.[CustomerContactIdFromSource]
			,ss.SourceId as [SourceId]
			,0 [UpdateUserID]
		FROM stg.stg_CustomerContacts as cc
		JOIN dbo.Source as ss ON cc.SourceSystem = ss.SourceName
		JOIN [dbo].[Customers] as c ON cc.[CustomerId] = c.[CustomerIdFromSource] AND c.[SourceId] = ss.SourceId 
		) AS source
		ON dest.CustomerContactIdFromSource = source.CustomerContactIdFromSource
			AND dest.[SourceId] = source.[SourceId]
	WHEN MATCHED
		AND dest.[CustomerContactName] <> source.[CustomerContactName]
		AND dest.[CustomerContactPersonRole] <> source.[CustomerContactPersonRole]
		AND dest.[CustomerContactPhone] <> source.[CustomerContactPhone]
		AND dest.[CustomerContactAdditionalPhoneNumber] = source.[CustomerContactAdditionalPhoneNumber]
		AND dest.[CustomerContactEmail] <> source.[CustomerContactEmail]
		AND dest.[CustomerContactIdFromSource] <> source.[CustomerContactIdFromSource]
		THEN
			UPDATE
			SET  dest.[CustomerId] = source.[CustomerId]
				,dest.[CustomerContactName] = source.[CustomerContactName]
				,dest.[CustomerContactPersonRole] = source.[CustomerContactPersonRole]
				,dest.[CustomerContactPhone] = source.[CustomerContactPhone]
				,dest.[CustomerContactAdditionalPhoneNumber] = source.[CustomerContactAdditionalPhoneNumber]
				,dest.[CustomerContactEmail] = source.[CustomerContactEmail]
				,dest.[CustomerContactIdFromSource] = source.[CustomerContactIdFromSource]
				,dest.[UpdatedDate] = GETDATE()
				,dest.[UpdateUserID] = 0
	WHEN NOT MATCHED
		THEN
			INSERT (
				 [CustomerId]
				,[CustomerContactName]
				,[CustomerContactPersonRole]
				,[CustomerContactPhone]
				,[CustomerContactAdditionalPhoneNumber]
				,[CustomerContactEmail]
				,[CustomerContactIdFromSource]
				,[SourceId]
				,[UpdateUserID]
				)
			VALUES (
				 source.[CustomerId]
				,source.[CustomerContactName]
				,source.[CustomerContactPersonRole]
				,source.[CustomerContactPhone]
				,source.[CustomerContactAdditionalPhoneNumber]
				,source.[CustomerContactEmail]
				,source.[CustomerContactIdFromSource]
				,source.[SourceId]
				,source.[UpdateUserID]
				);

END