CREATE    PROCEDURE [stg].[MergeCustomersContactsData]
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 04/06/2025
-- Description:	Merge customer contact data and create user for them to be able login to app
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

--Add customer contact as a user
	DECLARE @UserRoleId INT
	SELECT @UserRoleId = UserRoleId FROM UserRoles
	WHERE UserRoleDescriptionENG = N'Customer'

	MERGE INTO [dbo].[Users] AS dest
	USING (
		SELECT 
			 IIF(CHARINDEX(N' ', c.CustomerContactName) > 0,LEFT(c.CustomerContactName, CHARINDEX(N' ', c.CustomerContactName) - 1),'') as [FirstName]
			,IIF(CHARINDEX(N' ', REVERSE(c.CustomerContactName)) > 0,RIGHT(c.CustomerContactName,CHARINDEX(N' ', REVERSE(c.CustomerContactName)) - 1),'') as [LastName]
			,c.[CustomerContactEmail] as [Email]
			,1234 AS [Password]
			,IIF(LEN(c.[CustomerContactPhone]) > 0,c.[CustomerContactPhone], c.[CustomerContactAdditionalPhoneNumber]) as [Phone]
			,1 as [IsActive]
			,0 as [UpdateUserID]
			,@UserRoleId as[UserRoleId]
			,c.[SourceId]
	FROM [dbo].[CustomerContacts] as c
	WHERE LEN(c.[CustomerContactEmail]) > 0
		) AS source
		ON dest.[Email] = source.[Email]
	/*WHEN MATCHED
		THEN
			UPDATE
			SET  dest.[FirstName] = source.[FirstName]
				,dest.[LastName] = source.[LastName]
				,dest.[Password] = source.[Password]
				,dest.[Phone] = source.[Phone]
				,dest.[IsActive] = source.[IsActive]
				,dest.[UpdateUserID] = source.[UpdateUserID]
				,dest.[UserRoleId] = source.[UserRoleId]
				,dest.[SourceId] = source.[SourceId]*/
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [FirstName]
				,[LastName]
				,[Email]
				,[Password]
				,[Phone]
				,[IsActive]
				,[UpdateUserID]
				,[UserRoleId]
				,[SourceId]
				)
			VALUES (
				 source.[FirstName]
				,source.[LastName]
				,source.[Email]
				,source.[Password]
				,source.[Phone]
				,source.[IsActive]
				,source.[UpdateUserID]
				,source.[UserRoleId]
				,source.[SourceId]
				);


END