/*
    stg.MergeCustomersContactsData                                                     MBA-922
    ---------------------------------------------------------------------------------------------
    Carries IsPrimary and DoNotMail through from staging, and fixes the match test.

    The WHEN MATCHED clause ANDed every field comparison together, so a row only updated when EVERY
    field had changed at once - which never happens. One of those lines even tested for equality
    rather than difference. In practice nothing was ever updated; only inserts worked. It is an OR
    now, which is what was meant.
*/
CREATE OR ALTER PROCEDURE [stg].[MergeCustomersContactsData]
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
			,ISNULL(cc.[IsPrimary],0) as [IsPrimary]
			,ISNULL(cc.[DoNotMail],0) as [DoNotMail]
		FROM stg.stg_CustomerContacts as cc
		JOIN dbo.Source as ss ON cc.SourceSystem = ss.SourceName
		JOIN [dbo].[Customers] as c ON cc.[CustomerId] = c.[CustomerIdFromSource] AND c.[SourceId] = ss.SourceId 
		) AS source
		ON dest.CustomerContactIdFromSource = source.CustomerContactIdFromSource
			AND dest.[SourceId] = source.[SourceId]
	/* This used to AND every comparison together, so a row only updated when EVERY field had
	   changed at once - which never happens, and one of the lines even tested for equality.
	   OR is what was meant: update when anything differs. */
	WHEN MATCHED
		AND (   ISNULL(dest.[CustomerContactName],N'')                  <> ISNULL(source.[CustomerContactName],N'')
			 OR ISNULL(dest.[CustomerContactPersonRole],N'')            <> ISNULL(source.[CustomerContactPersonRole],N'')
			 OR ISNULL(dest.[CustomerContactPhone],N'')                 <> ISNULL(source.[CustomerContactPhone],N'')
			 OR ISNULL(dest.[CustomerContactAdditionalPhoneNumber],N'') <> ISNULL(source.[CustomerContactAdditionalPhoneNumber],N'')
			 OR ISNULL(dest.[CustomerContactEmail],N'')                 <> ISNULL(source.[CustomerContactEmail],N'')
			 OR ISNULL(dest.[IsPrimary],0)                              <> source.[IsPrimary]
			 OR ISNULL(dest.[DoNotMail],0)                              <> source.[DoNotMail])
		THEN
			UPDATE
			SET  dest.[CustomerId] = source.[CustomerId]
				,dest.[CustomerContactName] = source.[CustomerContactName]
				,dest.[CustomerContactPersonRole] = source.[CustomerContactPersonRole]
				,dest.[CustomerContactPhone] = source.[CustomerContactPhone]
				,dest.[CustomerContactAdditionalPhoneNumber] = source.[CustomerContactAdditionalPhoneNumber]
				,dest.[CustomerContactEmail] = source.[CustomerContactEmail]
				,dest.[CustomerContactIdFromSource] = source.[CustomerContactIdFromSource]
				,dest.[IsPrimary] = source.[IsPrimary]
				,dest.[DoNotMail] = source.[DoNotMail]
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
				,[IsPrimary]
				,[DoNotMail]
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
				,source.[IsPrimary]
				,source.[DoNotMail]
				);
/*
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
				*/

END
