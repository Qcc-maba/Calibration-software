MERGE INTO [dbo].[MainCategories] AS dest
USING (
	SELECT [MainCategoryName]
		,[AddedByUserId]
		,[CreatedAt]
		,[UpdatedAt]
		,[IsDeleted]
		FROM (
		VALUES
		('מסה',0,'2025-03-31 13:00:56','',0),
		('לחץ',0,'2025-03-31 13:00:56','',0),
		('אלקטרוניקה',0,'2025-03-31 13:00:56','',0),
		('גזים',0,'2025-03-31 13:00:56','',0),
		('זמן',0,'2025-03-31 13:00:56','',0),
		('טמפרטורה ולחות',0,'2025-03-31 13:00:56','',0),
		('כוח',0,'2025-03-31 13:00:56','',0),
		('מומנט',0,'2025-03-31 13:00:56','',0),
		('תמיסות',0,'2025-03-31 13:00:56','',0),
		('אורך וזווית',0,'2025-03-31 13:00:56','',0),
		('נפח',0,'2025-03-31 13:00:56','',0),
		('ספיקה',0,'2025-03-31 13:00:56','',0),
		('מהירות אוויר',0,'2025-03-31 13:00:56','',0),
		('קשיות',0,'2025-03-31 13:00:56','',0),
		('רדיומטריה',0,'2025-03-31 13:00:56','',0)
		) ds([MainCategoryName],[AddedByUserId],[CreatedAt],[UpdatedAt],[IsDeleted])
	) AS source
	ON dest.[MainCategoryName] = source.[MainCategoryName]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [MainCategoryName]
			,[AddedByUserId]
			,[CreatedAt]
			,[UpdatedAt]
			,[IsDeleted]
			)
		VALUES (
			 source.[MainCategoryName]
			,source.[AddedByUserId]
			,source.[CreatedAt]
			,source.[UpdatedAt]
			,source.[IsDeleted]
			);
/*Add Secondary category*/
MERGE INTO [dbo].[SecondaryCategories] AS dest
USING (
	SELECT [SecondaryCategoryName]
		,CAST([AddedByUserId] AS INT) as [AddedByUserId]
		,[CreatedAt]
		,[IsDeleted]
		,[MainCategoryId]
		FROM (
		VALUES
		(N'רגשים',0,GETDATE(),0,(SELECT ID FROM [dbo].[MainCategories] WHERE MainCategoryName=N'טמפרטורה ולחות')),
		(N'תאים',0,GETDATE(),0,(SELECT ID FROM [dbo].[MainCategories] WHERE MainCategoryName=N'טמפרטורה ולחות')),
		(N'ללא מגע',0,GETDATE(),0,(SELECT ID FROM [dbo].[MainCategories] WHERE MainCategoryName=N'טמפרטורה ולחות')),
		(N'גופים שחורים',0,GETDATE(),0,(SELECT ID FROM [dbo].[MainCategories] WHERE MainCategoryName=N'טמפרטורה ולחות')),
		(N'לחות',0,GETDATE(),0,(SELECT ID FROM [dbo].[MainCategories] WHERE MainCategoryName=N'טמפרטורה ולחות')),
		(N'נוזל בזכוכית',0,GETDATE(),0,(SELECT ID FROM [dbo].[MainCategories] WHERE MainCategoryName=N'טמפרטורה ולחות')),
		(N'סימולציה',0,GETDATE(),0,(SELECT ID FROM [dbo].[MainCategories] WHERE MainCategoryName=N'טמפרטורה ולחות')),
		(N'מלחמים',0,GETDATE(),0,(SELECT ID FROM [dbo].[MainCategories] WHERE MainCategoryName=N'טמפרטורה ולחות')),
		(N'משאיות קירור',0,GETDATE(),0,(SELECT ID FROM [dbo].[MainCategories] WHERE MainCategoryName=N'טמפרטורה ולחות'))
		) ds([SecondaryCategoryName],[AddedByUserId],[CreatedAt],[IsDeleted],[MainCategoryId])
	) AS source
	ON dest.[SecondaryCategoryName] = source.[SecondaryCategoryName]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [SecondaryCategoryName]
			,[AddedByUserId]
			,[CreatedAt]
			,[IsDeleted]
			,[MainCategoryId]
			)
		VALUES (
			 source.[SecondaryCategoryName]
			,source.[AddedByUserId]
			,source.[CreatedAt]
			,source.[IsDeleted]
			,source.[MainCategoryId]
			)
WHEN MATCHED 
	THEN
		UPDATE
			SET [MainCategoryId] = source.[MainCategoryId];




