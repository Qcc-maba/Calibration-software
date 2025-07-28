MERGE INTO [dbo].[MeasurementsSpecifications] AS dest
USING (
	SELECT 
		Name,
		MainCategoryId,
		DescriptionHeb,
		NULL as [MeasurementsSpecificationSourceId]
		FROM (
		VALUES
		('WI-C065', N'רגשים',(SELECT TOP 1 ID FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות') ),
		('WI-C062', N'תאים',(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות') ),
		('WI-C080', N'ללא מגע',(SELECT TOP 1 ID FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות') ),
		('WI-C080', N'גופים שחורים',(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות') ),
		('WI-C046', N'לחות',(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות') ),
		('WI-C063', N'נוזל בזכוכית',(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות') ),
		('WI-C067', N'סימולציה',(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות') ),
		('WI-C077', N'',(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות') ),
		('WI-C065', N'מלחמים',(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות') ),
		('WI-C065', N'משאיות קירור',(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות')) 
		) ds (Name,DescriptionHeb,MainCategoryId)
	) AS source
	ON dest.Name = source.Name AND 
	   dest.MainCategoryId = source.MainCategoryId AND
	   dest.DescriptionHeb = source.DescriptionHeb
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [Name]
			,[MainCategoryId]
			,[DescriptionHeb]
			,[MeasurementsSpecificationSourceId]
			)
		VALUES (
             source.[Name]
			,source.[MainCategoryId]
			,source.[DescriptionHeb]
			,source.[MeasurementsSpecificationSourceId]
			);
