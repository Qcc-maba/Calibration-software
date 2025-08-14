
DROP TABLE IF EXISTS #data

CREATE TABLE #data
(
Name NVARCHAR(100) COLLATE Latin1_General_100_CI_AI_SC,
MeasurementsSpecificationDescription NVARCHAR(100) COLLATE Latin1_General_100_CI_AI_SC,
SecondaryCategoryId	INT,
MainCategoryId INT
)
INSERT #data
(
    Name,
	MeasurementsSpecificationDescription,
	SecondaryCategoryId,
	MainCategoryId
)
SELECT 
    Name,
	MeasurementsSpecificationDescription,
	SecondaryCategoryId,
	MainCategoryId
	FROM (
	VALUES
	('WI-C065',N'רגש התנגדות רגש צמד תרמי', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'רגשים'),(SELECT TOP 1 ID FROM dbo.[MainCategories] WHERE [MainCategoryName] = N'טמפרטורה ולחות') ),
	('WI-C062',N'כיול תנורים', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'תאים'),(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = N'טמפרטורה ולחות') ),
	('WI-C080',N'טמפרטורה ללא מגע', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'ללא מגע'),(SELECT TOP 1 ID FROM dbo.[MainCategories] WHERE [MainCategoryName] = N'טמפרטורה ולחות') ),
	('WI-C080',N'טמפרטורה ללא מגע', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'גופים שחורים'),(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = N'טמפרטורה ולחות') ),
	('WI-C046',N'כיול לחות', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'לחות'),(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = N'טמפרטורה ולחות') ),
	('WI-C063',N'מד חום זכוכית מד חום חוגה', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'נוזל בזכוכית'),(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = N'טמפרטורה ולחות') ),
	('WI-C067',N'הדמיה חשמלית- צג, בקר,רשם', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'סימולציה'),(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = N'טמפרטורה ולחות') ),
	('WI-C077',N'סימולציה PH', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'סימולציה'),(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = N'טמפרטורה ולחות') ),
	('WI-C065',N'רגש התנגדות רגש צמד תרמי', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'מלחמים'),(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = N'טמפרטורה ולחות') ),
	('WI-C065',N'רגש התנגדות רגש צמד תרמי', (SELECT TOP 1 ID FROM dbo.[SecondaryCategories] WHERE SecondaryCategoryName = N'משאיות קירור'),(SELECT TOP 1 ID  FROM dbo.[MainCategories] WHERE [MainCategoryName] = N'טמפרטורה ולחות')) 
	) ds (Name,MeasurementsSpecificationDescription,SecondaryCategoryId,MainCategoryId)


MERGE INTO [dbo].[MeasurementsSpecifications] AS dest
USING (
	SELECT DISTINCT
		Name as Name,
		MeasurementsSpecificationDescription as MeasurementsSpecificationDescription,
		MainCategoryId
		FROM #data
	) AS source
	ON dest.Name = source.Name AND 
	   dest.MainCategoryId = source.MainCategoryId 
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [Name]
			,[MeasurementsSpecificationDescription]
			,[MainCategoryId]
			)
		VALUES (
             source.[Name]
			,source.[MeasurementsSpecificationDescription]
			,source.[MainCategoryId]
			)
WHEN MATCHED THEN UPDATE
SET [MeasurementsSpecificationDescription] = source.[MeasurementsSpecificationDescription],
	[UpdatedDate] = GETDATE(),
	[UpdateUserID] = 0
;


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
