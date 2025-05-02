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
           ,[IsActive])
     VALUES
           (0
		   ,'ETL'
           ,'ETL'
           ,'ETL'
           ,'ETL'
           ,'N/A'
           ,''
           ,'N/A'
           ,1)
SET IDENTITY_INSERT [dbo].[Users] OFF 
MERGE INTO [dbo].[Users] AS dest
USING (
	SELECT [FirstName]
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
		,[Stamp]
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
			)
			,(
			 N'sinova'
			,N'inactive '
			,N'Sinova'
			,N'Inactive '
			,N'sinova_inactive@gmail.com'
			,'123'
			,''
			,0
			,GETDATE()
			,NULL
			,0
			,''
			,''
			,''
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
			)
			,(
			 N'sinova'
			,N'Operation Manager  '
			,N'Sinova'
			,N'Operation Manager  '
			,N'sinova_operation_manager  @gmail.com'
			,'123'
			,''
			,1
			,GETDATE()
			,NULL
			,0
			,''
			,''
			,''
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
			)
		) ds([FirstName], [LastName], [FirstNameEng], [LastNameEng], [Email], [Password], [Phone], [IsActive], [CreatedDate], [UpdatedDate], [UpdateUserID], [UserAddress], [LocationArea], [Stamp])
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
			,dest.[Stamp] = source.[Stamp]
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
			,[Stamp]
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
			,source.[Stamp]
			);