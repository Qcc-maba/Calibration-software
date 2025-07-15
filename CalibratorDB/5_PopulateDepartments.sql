MERGE INTO [dbo].[Departments] AS dest
USING (
	SELECT [DepartmentName]
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
		) ds([DepartmentName],[AddedByUserId],[CreatedAt],[UpdatedAt],[IsDeleted])
	) AS source
	ON dest.[DepartmentName] = source.[DepartmentName]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [DepartmentName]
			,[AddedByUserId]
			,[CreatedAt]
			,[UpdatedAt]
			,[IsDeleted]
			)
		VALUES (
			 source.[DepartmentName]
			,source.[AddedByUserId]
			,source.[CreatedAt]
			,source.[UpdatedAt]
			,source.[IsDeleted]
			);
