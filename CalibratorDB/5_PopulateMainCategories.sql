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
		FROM (
		VALUES
		(N'רגשים',0,GETDATE(),0),
		(N'תאים',0,GETDATE(),0),
		(N'ללא מגע',0,GETDATE(),0),
		(N'גופים שחורים',0,GETDATE(),0),
		(N'לחות',0,GETDATE(),0),
		(N'נוזל בזכוכית',0,GETDATE(),0),
		(N'סימולציה',0,GETDATE(),0),
		(N'מלחמים',0,GETDATE(),0),
		(N'משאיות קירור',0,GETDATE(),0)
		) ds([SecondaryCategoryName],[AddedByUserId],[CreatedAt],[IsDeleted])
	) AS source
	ON dest.[SecondaryCategoryName] = source.[SecondaryCategoryName]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [SecondaryCategoryName]
			,[AddedByUserId]
			,[CreatedAt]
			,[IsDeleted]
			)
		VALUES (
			 source.[SecondaryCategoryName]
			,source.[AddedByUserId]
			,source.[CreatedAt]
			,source.[IsDeleted]
			);
/*Add relation between categories*/
MERGE INTO [dbo].[MainToSecondaryCategories] AS dest
USING (
	SELECT 
		[MainCategoryId],
		[SecondaryCategoryId]
		FROM (
		VALUES
		((SELECT ID FROM [dbo].[MainCategories] WHERE MainCategoryName=N'טמפרטורה ולחות'),(SELECT ID FROM [dbo].[SecondaryCategories] WHERE IsDeleted = 0 AND [SecondaryCategoryName]=N'רגשים')),
		((SELECT ID FROM [dbo].[MainCategories] WHERE MainCategoryName=N'טמפרטורה ולחות'),(SELECT ID FROM [dbo].[SecondaryCategories] WHERE IsDeleted = 0 AND [SecondaryCategoryName]=N'תאים')),
		((SELECT ID FROM [dbo].[MainCategories] WHERE MainCategoryName=N'טמפרטורה ולחות'),(SELECT ID FROM [dbo].[SecondaryCategories] WHERE IsDeleted = 0 AND [SecondaryCategoryName]=N'ללא מגע')),
		((SELECT ID FROM [dbo].[MainCategories] WHERE MainCategoryName=N'טמפרטורה ולחות'),(SELECT ID FROM [dbo].[SecondaryCategories] WHERE IsDeleted = 0 AND [SecondaryCategoryName]=N'גופים שחורים')),
		((SELECT ID FROM [dbo].[MainCategories] WHERE MainCategoryName=N'טמפרטורה ולחות'),(SELECT ID FROM [dbo].[SecondaryCategories] WHERE IsDeleted = 0 AND [SecondaryCategoryName]=N'לחות')),
		((SELECT ID FROM [dbo].[MainCategories] WHERE MainCategoryName=N'טמפרטורה ולחות'),(SELECT ID FROM [dbo].[SecondaryCategories] WHERE IsDeleted = 0 AND [SecondaryCategoryName]=N'נוזל בזכוכית')),
		((SELECT ID FROM [dbo].[MainCategories] WHERE MainCategoryName=N'טמפרטורה ולחות'),(SELECT ID FROM [dbo].[SecondaryCategories] WHERE IsDeleted = 0 AND [SecondaryCategoryName]=N'סימולציה')),
		((SELECT ID FROM [dbo].[MainCategories] WHERE MainCategoryName=N'טמפרטורה ולחות'),(SELECT ID FROM [dbo].[SecondaryCategories] WHERE IsDeleted = 0 AND [SecondaryCategoryName]=N'מלחמים')),
		((SELECT ID FROM [dbo].[MainCategories] WHERE MainCategoryName=N'טמפרטורה ולחות'),(SELECT ID FROM [dbo].[SecondaryCategories] WHERE IsDeleted = 0 AND [SecondaryCategoryName]=N'משאיות קירור'))
		) ds([MainCategoryId],[SecondaryCategoryId])
	) AS source
	ON dest.[SecondaryCategoryId] = source.[SecondaryCategoryId]
	  AND dest.[MainCategoryId] = source.[MainCategoryId]
	  AND dest.IsDeleted = 0
WHEN NOT MATCHED BY TARGET
	THEN
	INSERT([SecondaryCategoryId]
		  ,[MainCategoryId])
		VALUES (
			 source.[SecondaryCategoryId]
			,source.[MainCategoryId]
			);




