DELETE FROM [dbo].[Users] WHERE ID =0
SET IDENTITY_INSERT [dbo].[Users] ON 

INSERT INTO [dbo].[Users]
           (
		    [ID]
		   ,[FirstName]
           ,[LastName]
           ,[FirstNameEng]
           ,[LastNameEng]
           ,[Email]
           ,[Password]
           ,[Phone]
           ,[IsActive]
		   ,[UserRoleId])
     VALUES
           (0
		   ,'ETL'
           ,'ETL'
           ,'ETL'
           ,'ETL'
           ,'N/A'
           ,''
           ,'N/A'
           ,1
		   ,1)
SET IDENTITY_INSERT [dbo].[Users] OFF 
-- Do not execute on prod
MERGE INTO [dbo].[Users] AS dest
USING (
  SELECT 
[FirstName], [LastName], NULL AS [FirstNameEng], NULL AS  [LastNameEng], [Email], '1234' as [Password], NULL AS [Phone], 1 as  [IsActive],GETDATE() AS [CreatedDate], NULL AS [UpdatedDate],NULL AS [UpdateUserID], NULL AS [UserAddress], NULL AS [LocationArea], NULL as [Stamp], ur.UserRoleId
FROM (
VALUES
(N'רות',N'עווד',N'ruth_aw@mba.co.il'),
(N'ורד',N'לב',N'vered_le@mba.co.il'),
(N'ורד',N'גנון',N'vered_ga@mba.co.il'),
(N'קוסטיה',N'קליוקין',N'kosta_kl@mba.co.il'),
(N'ישראייר',N'בע"מ',N'irynag@israir.co.il'),
(N'קרן',N'שרעבי',N'keren_sh@mba.co.il'),
(N'עופרה',N'שלמה',N'ofra_sh@mba.co.il'),
(N'דורלי',N'לוי-חלי',N'dorli_le@mba.co.il'),
(N'שרונה',N'קורן',N'sharona_ko@mba.co.il'),
(N'דברת',N'לוי',N'dovrat_le@mba.co.il'),
(N'אופיר',N'בסביץ',N'ofir_ba@mba.co.il'),
(N'יונת',N'יוסף',N'yonat_be@mba.co.il')
) ds ([FirstName],[LastName],[Email])
JOIN dbo.UserRoles as ur ON 'CustomerSupport' = ur.UserRoleName
UNION ALL
	SELECT 
	     ds.[FirstName]
		,ds.[LastName]
		,ds.[FirstNameEng]
		,ds.[LastNameEng]
		,ds.[Email]
		,ds.[Password]
		,ds.[Phone]
		,ds.[IsActive]
		,ds.[CreatedDate]
		,ds.[UpdatedDate]
		,ds.[UpdateUserID]
		,ds.[UserAddress]
		,ds.[LocationArea]
		,ds.[Stamp]
		,ur.UserRoleId
	FROM (
		VALUES (
			 N'sinova'
			,N'validator'
			,N'Sinova'
			,N'Validator'
			,N'sinova_validator@gmail.com'
			,'123'
			,''
			,1
			,GETDATE()
			,NULL
			,0
			,''
			,''
			,''
			,'Validator'
			)
			,(
			 N'sinova'
			,N'coordinator'
			,N'Sinova'
			,N'Coordinator'
			,N'sinova_coordinator@gmail.com'
			,'123'
			,''
			,1
			,GETDATE()
			,NULL
			,0
			,''
			,''
			,''
			,'Coordinator'
			)
			,(
			 N'sinova'
			,N'super admin'
			,N'Sinova'
			,N'Super admin'
			,N'sinova_super_admin@gmail.com'
			,'123'
			,''
			,1
			,GETDATE()
			,NULL
			,0
			,''
			,''
			,''
			,'SuperAdmin'
			)
			,(
			 N'sinova'
			,N'team leader'
			,N'Sinova'
			,N'Team leader'
			,N'sinova_team_leader@gmail.com'
			,'123'
			,''
			,1
			,GETDATE()
			,NULL
			,0
			,''
			,''
			,'123-456'
			,'TeamLeader'
			)
			,(
			 N'sinova'
			,N'Calibrator'
			,N'Sinova'
			,N'Calibrator'
			,N'sinova_calibrator@gmail.com'
			,'123'
			,''
			,1
			,GETDATE()
			,NULL
			,0
			,''
			,''
			,''
			,'Calibrator'
			)
			,(
			 N'sinova'
			,N'Operation Manager'
			,N'Sinova'
			,N'Operation Manager'
			,N'sinova_operation_manager@gmail.com'
			,'123'
			,''
			,1
			,GETDATE()
			,NULL
			,0
			,''
			,''
			,''
			,'OperationManager'
			)
			,(
			 N'sinova'
			,N'client'
			,N'Sinova'
			,N'Client'
			,N'sinova_client@gmail.com'
			,'123'
			,''
			,1
			,GETDATE()
			,NULL
			,0
			,''
			,''
			,''
			,'Client'
			)
			,(
			 N'sinova'
			,N'customer support'
			,N'Sinova'
			,N'Customer Support'
			,N'sinova_customer_support@gmail.com'
			,'123'
			,''
			,1
			,GETDATE()
			,NULL
			,0
			,''
			,''
			,''
			,'CustomerSupport'
			)
			,(
			 N'אלירן'
			,N'חדד'
			,N'Eliran'
			,N'Hadad'
			,N'Eliran_ha@mba.co.il'
			,'1234'
			,'0545486607'
			,1
			,GETDATE()
			,NULL
			,0
			,''
			,''
			,''
			,'SuperAdmin'
			)
			,(
			 N'sinova'
			,N'ExternalCalibrator'
			,N'sinova'
			,N'ExternalCalibrator'
			,N'ExternalCalibrator@mba.co.il'
			,'1234'
			,'0585686607'
			,1
			,GETDATE()
			,NULL
			,0
			,''
			,''
			,''
			,'ExternalCalibrator'
			),
			(
			 N'sinova'
			,N'Packing'
			,N'sinova'
			,N'Packing'
			,N'Packing@mba.co.il'
			,'1234'
			,'0585686607'
			,1
			,GETDATE()
			,NULL
			,0
			,''
			,''
			,''
			,'Packing'
			),
			(
			 N'sinova'
			,N'LogisticManager'
			,N'sinova'
			,N'LogisticManager'
			,N'LogisticManager@mba.co.il'
			,'1234'
			,'0585686607'
			,1
			,GETDATE()
			,NULL
			,0
			,''
			,''
			,''
			,'LogisticManager'
			),
			(
			 N'sinova'
			,N'Driver'
			,N'sinova'
			,N'Driver'
			,N'Driver@mba.co.il'
			,'1234'
			,'0585686608'
			,1
			,GETDATE()
			,NULL
			,0
			,''
			,''
			,''
			,'Driver'
			)
		) ds([FirstName], [LastName], [FirstNameEng], [LastNameEng], [Email], [Password], [Phone], [IsActive], [CreatedDate], [UpdatedDate], [UpdateUserID], [UserAddress], [LocationArea], [Stamp],[UserRole])
		JOIN dbo.UserRoles as ur ON ds.[UserRole] = ur.UserRoleName
	) AS source
	ON dest.[Email] = source.[Email]
WHEN MATCHED
	THEN
		UPDATE
		SET dest.[FirstName] = source.[FirstName]
			,dest.[LastName] = source.[LastName]
			,dest.[FirstNameEng] = source.[FirstNameEng]
			,dest.[LastNameEng] = source.[LastNameEng]
			,dest.[Password] = source.[Password]
			,dest.[Phone] = source.[Phone]
			,dest.[IsActive] = source.[IsActive]
			,dest.[CreatedDate] = source.[CreatedDate]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[UpdateUserID] = source.[UpdateUserID]
			,dest.[UserAddress] = source.[UserAddress]
			,dest.[LocationArea] = source.[LocationArea]
			,dest.[UserRoleId] = source.[UserRoleId]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[FirstName]
			,[LastName]
			,[FirstNameEng]
			,[LastNameEng]
			,[Email]
			,[Password]
			,[Phone]
			,[IsActive]
			,[CreatedDate]
			,[UpdatedDate]
			,[UpdateUserID]
			,[UserAddress]
			,[LocationArea]
			,[UserRoleId]
			)
		VALUES (
			source.[FirstName]
			,source.[LastName]
			,source.[FirstNameEng]
			,source.[LastNameEng]
			,source.[Email]
			,source.[Password]
			,source.[Phone]
			,source.[IsActive]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[UpdateUserID]
			,source.[UserAddress]
			,source.[LocationArea]
			,source.[UserRoleId]
			);