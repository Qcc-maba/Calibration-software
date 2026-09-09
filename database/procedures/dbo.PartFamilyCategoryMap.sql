-- =============================================
-- Object:      dbo.PartFamilyCategoryMap  (+ seed)
-- Jira:        MBA-882 / MBA-666 — device categories are wrong on the order screens
--
-- WHY THIS EXISTS
-- OrderDetails.MainCategoryId / SecondaryCategoryId come from stg_Orders.MainCategorySourceId,
-- i.e. from whatever was typed on the order line in Priority. That value is unreliable: the same
-- catalog number carries different categories across orders and is NULL most of the time.
-- Measured on STAGE: 120202-7 (מאזניים עד 100 ק"ג) is 'מסה' in 5 orders, 'טמפרטורה ולחות/תאים' in
-- order 12, 'טמפרטורה ולחות/רגשים' in order 107, and NULL in ~15 others — which is why a scale
-- shows a temperature category on its device card. 130101-0 has 2 categories over 87 rows with 51
-- NULL; 140101-0 and 170101-0 have 3 each. And the staging window only holds ~1,073 of 4,000
-- OrderDetails rows, so old rows are frozen with whatever was there and no sync will ever fix them.
--
-- amaba.dbo.PART.FAMILY is the authoritative device taxonomy instead: 66 families, clean names
-- (מאזניים / מד לחץ / רגש טמפרטורה / תנור ...), and 100% populated for every order line via
-- dbo.CrmPartInfo. This table translates a Priority family into OUR discipline.
--
-- NOTE ON SECONDARY CATEGORIES: all nine of ours are temperature sub-types (רגשים, תאים, ללא מגע,
-- גופים שחורים, לחות, נוזל בזכוכית, סימולציה, מלחמים, משאיות קירור). A secondary category on
-- anything that is not טמפרטורה ולחות is therefore wrong by construction — that is exactly the
-- 'תאים' seen on a scale.
--
-- NeedsReview = 1 marks families I could not infer from the name alone. They are deliberately left
-- unmapped (NULL category) rather than guessed, so nothing is silently mis-categorised.
-- This is a DATA table, not code: Nofar can correct any row and re-run dbo.ApplyPartFamilyCategories.
-- =============================================

IF OBJECT_ID('dbo.PartFamilyCategoryMap') IS NULL
    CREATE TABLE dbo.PartFamilyCategoryMap(
         FamilyId            INT NOT NULL PRIMARY KEY
        ,FamilyDescription   NVARCHAR(200) NULL      -- amaba FAMILY.FAMILYDES, for readability
        ,MainCategoryId      INT NULL                -- dbo.MainCategories.ID   (NULL = do not set)
        ,SecondaryCategoryId INT NULL                -- dbo.SecondaryCategories.ID
        ,IsCalibrationItem   BIT NOT NULL DEFAULT 1  -- 0 = travel / training / services
        ,NeedsReview         BIT NOT NULL DEFAULT 0  -- 1 = could not be inferred, needs Nofar
        ,UpdatedAt           DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
GO

/* Seed. Categories are resolved BY NAME so the script is independent of ids. */
DECLARE @m TABLE(FamilyId INT, Fam NVARCHAR(100), MainName NVARCHAR(100), SecName NVARCHAR(100), IsItem BIT, Review BIT);

INSERT INTO @m(FamilyId, Fam, MainName, SecName, IsItem, Review) VALUES
 -- mass
 (13,N'מאזניים',N'מסה',NULL,1,0), (14,N'משקולת',N'מסה',NULL,1,0),
 -- pressure
 (15,N'מד לחץ',N'לחץ',NULL,1,0), (16,N'כייל לחץ',N'לחץ',NULL,1,0),
 -- force
 (17,N'מד כוח',N'כוח',NULL,1,0), (18,N'מכונת מתיחה',N'כוח',NULL,1,0),
 (19,N'מכבש',N'כוח',NULL,1,0), (20,N'מתמר כוח',N'כוח',NULL,1,0),
 -- torque
 (24,N'מד פיתול',N'מומנט',NULL,1,0), (52,N'כייל פיתול',N'מומנט',NULL,1,0),
 -- temperature & humidity, with the sub-type where the family implies one
 (30,N'רגש טמפרטורה',N'טמפרטורה ולחות',N'רגשים',1,0),
 (26,N'מד חום סיפרתי',N'טמפרטורה ולחות',N'רגשים',1,0),
 (25,N'מד חום זכוכית',N'טמפרטורה ולחות',N'נוזל בזכוכית',1,0),
 (49,N'טמפרטורה',N'טמפרטורה ולחות',NULL,1,0),
 (27,N'תנור',N'טמפרטורה ולחות',N'תאים',1,0),
 (28,N'אמבט',N'טמפרטורה ולחות',N'תאים',1,0),
 (29,N'אינקובטור',N'טמפרטורה ולחות',N'תאים',1,0),
 (51,N'מקרר',N'טמפרטורה ולחות',N'תאים',1,0),
 (46,N'אוטוקלאב',N'טמפרטורה ולחות',N'תאים',1,0),
 (31,N'לחות',N'טמפרטורה ולחות',N'לחות',1,0),
 (32,N'טמפרטורה לחות משולב',N'טמפרטורה ולחות',N'לחות',1,0),
 -- length & angle
 (23,N'מיקרומטר',N'אורך וזווית',NULL,1,0), (48,N'מכשירי אורך',N'אורך וזווית',NULL,1,0),
 (33,N'מד גובה',N'אורך וזווית',NULL,1,0), (54,N'סרגל',N'אורך וזווית',NULL,1,0),
 (4,N'מדיד תקע',N'אורך וזווית',NULL,1,0), (11,N'מקבילונים',N'אורך וזווית',NULL,1,0),
 (44,N'כייל אורך',N'אורך וזווית',NULL,1,0), (8,N'מד עובי',N'אורך וזווית',NULL,1,0),
 (12,N'חוגן',N'אורך וזווית',NULL,1,0), (1,N'זחון',N'אורך וזווית',NULL,1,0),
 (3,N'מדיד הברגה קוני',N'אורך וזווית',NULL,1,0), (66,N'מדיד הברגה',N'אורך וזווית',NULL,1,0),
 (63,N'טבעת הברגה',N'אורך וזווית',NULL,1,0), (53,N'מד זוית/זויתן',N'אורך וזווית',NULL,1,0),
 (38,N'מוט אורך',N'אורך וזווית',NULL,1,0), (58,N'שולחן גרניט/מתכת',N'אורך וזווית',NULL,1,0),
 (56,N'פלס',N'אורך וזווית',NULL,1,0), (60,N'מיקרוסקופ/קומפרטור',N'אורך וזווית',NULL,1,0),
 (9,N'מד חריץ',N'אורך וזווית',NULL,1,0), (61,N'מדידי עלים',N'אורך וזווית',NULL,1,0),
 (111,N'מרחק',N'אורך וזווית',NULL,1,0),
 -- electronics
 (47,N'צב''ד אלקטרוני',N'אלקטרוניקה',NULL,1,0), (39,N'רב מודד',N'אלקטרוניקה',NULL,1,0),
 (40,N'סקופ',N'אלקטרוניקה',NULL,1,0), (41,N'ספק',N'אלקטרוניקה',NULL,1,0),
 (43,N'קליברטור אלקטרוני',N'אלקטרוניקה',NULL,1,0), (77,N'פיוזים',N'אלקטרוניקה',NULL,1,0),
 -- the rest of the disciplines
 (34,N'נפח',N'נפח',NULL,1,0), (68,N'ריינין',N'נפח',NULL,1,1),      -- Rainin = pipettes, brand name -> confirm
 (36,N'זרימה וספיקה',N'ספיקה',NULL,1,0),
 (117,N'רדיומטריה',N'רדיומטריה',NULL,1,0),
 (22,N'קושי מתכת',N'קשיות',NULL,1,0), (21,N'קושי גומי',N'קשיות',NULL,1,0),
 (101,N'Hp/מוליכות',N'תמיסות',NULL,1,0),                            -- pH / conductivity
 -- NOT calibration items: no category at all
 (65,N'נסיעות',NULL,NULL,0,0), (127,N'הדרכה',NULL,NULL,0,0), (35,N'שרותי איכות',NULL,NULL,0,0),
 (-1,N'ללא משפחה',NULL,NULL,0,0), (78,N'ללא משפחה',NULL,NULL,0,0), (0,N'',NULL,NULL,0,0),
 -- could NOT be inferred — left unmapped on purpose
 (37,N'סל''ד ומהירות',NULL,NULL,1,1),   -- RPM/speed: זמן? מהירות אוויר? neither is obvious
 (50,N'ציוד מיוחד',NULL,NULL,1,1),
 (45,N'מדמה',NULL,NULL,1,1),            -- simulator: אלקטרוניקה, or temperature/סימולציה?
 (7,N'דפינה',NULL,NULL,1,1),
 (42,N'FR',NULL,NULL,1,1);

MERGE dbo.PartFamilyCategoryMap AS dest
USING (
    SELECT m.FamilyId, m.Fam,
           mc.ID  AS MainCategoryId,
           sc.ID  AS SecondaryCategoryId,
           m.IsItem, m.Review
    FROM @m AS m
    LEFT JOIN dbo.MainCategories      AS mc ON mc.MainCategoryName      = m.MainName AND ISNULL(mc.IsDeleted,0)=0
    LEFT JOIN dbo.SecondaryCategories AS sc ON sc.SecondaryCategoryName = m.SecName  AND ISNULL(sc.IsDeleted,0)=0
) AS src ON src.FamilyId = dest.FamilyId
WHEN MATCHED THEN UPDATE SET
     dest.FamilyDescription = src.Fam
    ,dest.MainCategoryId = src.MainCategoryId
    ,dest.SecondaryCategoryId = src.SecondaryCategoryId
    ,dest.IsCalibrationItem = src.IsItem
    ,dest.NeedsReview = src.Review
    ,dest.UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET THEN
    INSERT (FamilyId, FamilyDescription, MainCategoryId, SecondaryCategoryId, IsCalibrationItem, NeedsReview)
    VALUES (src.FamilyId, src.Fam, src.MainCategoryId, src.SecondaryCategoryId, src.IsItem, src.Review);
GO

/* Any family that appears on a real order line but is not in the map at all — so nothing is
   silently skipped. Inserted with NeedsReview = 1 and no category. */
INSERT dbo.PartFamilyCategoryMap(FamilyId, FamilyDescription, MainCategoryId, SecondaryCategoryId, IsCalibrationItem, NeedsReview)
SELECT DISTINCT c.FamilyId, c.FamilyDescription, NULL, NULL, 1, 1
FROM dbo.CrmPartInfo AS c
WHERE c.FamilyId IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.PartFamilyCategoryMap m WHERE m.FamilyId = c.FamilyId);
GO
