MERGE INTO [dbo].[UserRoles] AS dest
USING (
		SELECT 
		[UserRoleDescriptionENG]
		,[UserRoleDescriptionHEB]
		,[UserRoleName]
		,[IsApplicationRole]
		FROM (
			VALUES
			('Super Admin',N'משתמש על','SuperAdmin',1),
			('Team Leader',N'מנהל מחלקה','TeamLeader',1),
			('Calibrator',N'כייל','Calibrator',1),
			('Operation Manager',N'מנהל תפעול','OperationManager',1),
			('Coordinator',N'משבץ','Coordinator',1),
			('Internal Validator',N'ולידטור','InternalValidator',1),
			('External Validator',N'ולידטור','ExternalValidator',1),
			('Customer ',N'לקוח','Customer ',1),
			('Customer support',N'שירות לקוחות','CustomerSupport',1),
			('Packing',N'אריזה','Packing',1),
			('Logistic Manager',N'מנהל לוגיסטי','LogisticManager',1),
			('Driver',N'נהג','Driver',1)
		) ds ([UserRoleDescriptionENG],[UserRoleDescriptionHEB],[UserRoleName],[IsApplicationRole])
	) AS source
	ON dest.[UserRoleName] = source.[UserRoleName]
WHEN MATCHED
	THEN
		UPDATE
		SET  dest.[UserRoleDescriptionHEB] = source.[UserRoleDescriptionHEB]
			,dest.[UserRoleDescriptionENG] = source.[UserRoleDescriptionENG]
			,dest.[IsApplicationRole] = source.[IsApplicationRole]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [UserRoleDescriptionENG]
			,[UserRoleDescriptionHEB]
			,[UserRoleName]
			,[IsApplicationRole]
			)
		VALUES (
			 source.[UserRoleDescriptionENG]
			,source.[UserRoleDescriptionHEB]
			,source.[UserRoleName]
			,source.[IsApplicationRole]
			);
