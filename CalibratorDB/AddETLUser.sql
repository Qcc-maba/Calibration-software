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
           ,[Mobile]
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