DROP TABLE IF EXISTS #CalibratorCertificationAuthorities
CREATE TABLE #CalibratorCertificationAuthorities
(
[AuthorityName] NVARCHAR(100) COLLATE Latin1_General_100_CI_AI_SC,
[MainCategoryId] INT
)

DECLARE @MainCategoryId INT = 0

SELECT @MainCategoryId = [ID]
FROM [dbo].[MainCategories] WHERE MainCategoryName = N'טמפרטורה ולחות'

INSERT #CalibratorCertificationAuthorities([AuthorityName],[MainCategoryId])

SELECT 
    LTRIM(RTRIM([AuthorityName])),[MainCategoryId]
FROM (
    VALUES
    (N'כיול מד CO2 בהשוואה למד אב תחת אווירה מבוקרת', @MainCategoryId),
    (N'מדי טמפרטורה ורגשים', @MainCategoryId),
    (N'מדידת לחות בהשוואה לרגש לחות מסטר', @MainCategoryId),
    (N'אוטוקלב כולל בדיקת לחץ', @MainCategoryId),
    (N'אמבט', @MainCategoryId),
    (N'דימוי באמצעות קליברטור', @MainCategoryId),
    (N'תאים מבוקרים טמפ'' + לחות', @MainCategoryId),
    (N'תרמומטר נוזל זכוכית בבית הלקוח', @MainCategoryId),
    (N'אמבט כיול דיוק גבוה', @MainCategoryId),
    (N'דימוי טמפרטורה באמצעות קליברטור', @MainCategoryId),
    (N'מד חום אינפרא אדום', @MainCategoryId),
    (N'מדי טמפרטורה ורגשים רגיל/דיוק גבוה', @MainCategoryId),
    (N'תנור כיול', @MainCategoryId),
    (N'תרמומטר נוזל זכוכית', @MainCategoryId),
    (N'מדידת טמפרטורת רכיב בבית הלקוח', @MainCategoryId),
    (N'גוף שחור', @MainCategoryId),
    (N'לחות יחסית כנגד היגרומטר מראה מקוררת', @MainCategoryId),
    (N'מד חום אינפרא אדום וגופים שחורים', @MainCategoryId),
    (N'מדידת לחות בהשוואה לתמיסות', @MainCategoryId)
) AS ds ([AuthorityName],[MainCategoryId]);


MERGE INTO [dbo].[CalibratorCertificationAuthorities] AS dest
USING (
	SELECT 
		 [AuthorityName]
		,[MainCategoryId]
	FROM #CalibratorCertificationAuthorities
	) AS source
	ON dest.[AuthorityName] = source.[AuthorityName]
WHEN MATCHED
	THEN
		UPDATE
		SET  dest.[MainCategoryId] = source.[MainCategoryId]
			,dest.[UpdatedDate] = GETDATE()
			,dest.[IsDeleted] = 0
			,dest.[UpdateUserID] = 0
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [AuthorityName]
			,[MainCategoryId]
			,[CreatedDate]
			,[IsDeleted]
			,[UpdateUserID]
			)
		VALUES (
             source.[AuthorityName]
			,source.[MainCategoryId]
			,GETDATE()
			,0
			,0
			);
