MERGE INTO [dbo].[UserMessages] AS dest
USING (
	SELECT 
	[Id],[MessageHeb],[MessageEng]
	FROM (
	VALUES
	(1,N'משתמש לא קיים','User is not exist'),
	(2,N'משתמש לא פעיל','User is not active'),
	(3,N'סיסמה שגויה','Wrong password')
	) ds ([Id],[MessageHeb],[MessageEng])
	) AS source
	ON dest.[MessageEng] = source.[MessageEng]
WHEN MATCHED
	THEN
		UPDATE
		SET dest.[MessageHeb] = source.[MessageHeb]
			
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [MessageHeb]
			,[MessageEng]
			)
		VALUES (
			 source.[MessageHeb]
			,source.[MessageEng]
			);
