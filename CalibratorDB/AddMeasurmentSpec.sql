
DROP TABLE IF EXISTS #data

CREATE TABLE #data
(
Name NVARCHAR(100) COLLATE Hebrew_BIN,	
SecondaryCategoryId	INT,
MainCategoryId INT
)
INSERT #data
(
    Name,
	SecondaryCategoryId,
	MainCategoryId
)
SELECT 
    Name,
	SecondaryCategoryId,
	MainCategoryId
	FROM (
	VALUES
	('WI-C065', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'רגשים'),(SELECT TOP 1 ID FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות') ),
	('WI-C062', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'תאים'),(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות') ),
	('WI-C080', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'ללא מגע'),(SELECT TOP 1 ID FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות') ),
	('WI-C080', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'גופים שחורים'),(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות') ),
	('WI-C046', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'לחות'),(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות') ),
	('WI-C063', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'נוזל בזכוכית'),(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות') ),
	('WI-C067', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'סימולציה'),(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות') ),
	('WI-C077', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'סימולציה'),(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות') ),
	('WI-C065', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'מלחמים'),(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות') ),
	('WI-C065', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'משאיות קירור'),(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = 'טמפרטורה ולחות')) 
	) ds (Name,SecondaryCategoryId,MainCategoryId)


MERGE INTO [dbo].[MeasurementsSpecifications] AS dest
USING (
	SELECT DISTINCT
		Name COLLATE Hebrew_BIN as Name,
		MainCategoryId
		FROM #data
	) AS source
	ON dest.Name = source.Name AND 
	   dest.MainCategoryId = source.MainCategoryId 
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [Name]
			,[MainCategoryId]
			)
		VALUES (
             source.[Name]
			,source.[MainCategoryId]
			);


MERGE INTO [dbo].[MeasurementsSpecificationsToSecondCategory] AS dest
USING (
	SELECT 
	    ms.ID as MeasurementsSpecificationId,
		d.SecondaryCategoryId
		FROM #data as d
		JOIN [dbo].[MeasurementsSpecifications] as ms ON d.Name = ms.Name
	) AS source
	ON dest.MeasurementsSpecificationId = source.MeasurementsSpecificationId AND 
	   dest.SecondaryCategoryId = source.SecondaryCategoryId 
	   AND dest.IsDeleted = 0
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 MeasurementsSpecificationId
			,SecondaryCategoryId
			)
		VALUES (
             source.MeasurementsSpecificationId
			,source.SecondaryCategoryId
			);
