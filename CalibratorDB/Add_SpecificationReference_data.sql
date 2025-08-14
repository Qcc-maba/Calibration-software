MERGE INTO [dbo].[SpecificationReference] AS dest
USING (
SELECT [SpecificationReferenceName]
		,CAST([AddedByUserId] AS INT) as [AddedByUserId]
		,[CreatedAt]
		,[IsDeleted]
		,[SecondaryCategoryId]
		FROM (
		VALUES
		(N'נתוני לקוח',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'תאים')),
		(N'סיבולת יצרן',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'תאים')),
		(N'נתוני לקוח- ממוצע ממוצעים',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'תאים')),
		(N'DIN 12880',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'תאים')),
		(N'AMS 2750',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'תאים')),
		(N'ISO 11135',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'תאים')),
		(N'ISO 17665',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'תאים')),
		(N'ISO 1133, ASTM D1238',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'תאים')),
		(N'נוהל 126 משרד הבריאות',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'תאים')),
		(N'DKD-R-5-7',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'תאים')),
		(N'נתוני לקוח',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'גופים שחורים')),
		(N'סיבולת יצרן',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'גופים שחורים')),
		(N'ASTM E2847',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'גופים שחורים')),
		(N'נתוני לקוח',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'רגשים')),
		(N'סיבולת יצרן',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'רגשים')),
		(N'ASTM E1137',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'רגשים')),
		(N'ASTM E644',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'רגשים')),
		(N'ASTM E344',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'רגשים')),
		(N'IEC 751',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'רגשים')),
		(N'IEC 60751',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'רגשים')),
		(N'ITS-90',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'רגשים')),
		(N'ASTM E230',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'רגשים')),
		(N'ASTM E220',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'רגשים')),
		(N'ASTM E235',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'רגשים')),
		(N'ASTM E585',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'רגשים')),
		(N'ASTM E839',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'רגשים')),
		(N'ASTM E879',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'רגשים')),
		(N'ASTM E988',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'רגשים')),
		(N'נתוני לקוח',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'ללא מגע')),
		(N'סיבולת יצרן',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'ללא מגע')),
		(N'ASTM E2847',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'ללא מגע')),
		(N'נתוני לקוח',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'לחות')),
		(N'סיבולת יצרן',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'לחות')),
		(N'ASTM-E-104-20a',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'לחות')),
		(N'NIS 19',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'לחות')),
		(N'OIML R121',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'לחות')),
		(N'נתוני לקוח',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'נוזל בזכוכית')),
		(N'סיבולת יצרן',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'נוזל בזכוכית')),
		(N'ISO 1770',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'נוזל בזכוכית')),
		(N'ISO 1771',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'נוזל בזכוכית')),
		(N'ISO 386',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'נוזל בזכוכית')),
		(N'ASTM E77',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'נוזל בזכוכית')),
		(N'ASTM E1',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'נוזל בזכוכית')),
		(N'BS 593',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'נוזל בזכוכית')),
		(N'BS 1704',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'נוזל בזכוכית')),
		(N'נתוני לקוח',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'סימולציה')),
		(N'סיבולת יצרן',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'סימולציה')),
		(N'EURAMET cg-11',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'סימולציה')),
		(N'נתוני לקוח',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'סימולציה')),
		(N'סיבולת יצרן',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'סימולציה')),
		(N'נתוני לקוח',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'מלחמים')),
		(N'סיבולת יצרן',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'מלחמים')),
		(N'נתוני לקוח',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'משאיות קירור')),
		(N'סיבולת יצרן',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'משאיות קירור')),
		(N'תקן ישראלי ת"י 1291',0,GETDATE(),0,(SELECT ID FROM [dbo].[SecondaryCategories] WHERE SecondaryCategoryName = N'משאיות קירור'))
		) ds([SpecificationReferenceName],[AddedByUserId],[CreatedAt],[IsDeleted],[SecondaryCategoryId])

	) AS source
	ON dest.[Name] = source.[SpecificationReferenceName]
	   AND dest.[SecondaryCategoryId] = source.[SecondaryCategoryId]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
             [Name]
			,[UpdateUserID]
			,[SecondaryCategoryId]
			)
		VALUES (
             source.[SpecificationReferenceName]
			,source.[AddedByUserId]
			,source.[SecondaryCategoryId]
			);


