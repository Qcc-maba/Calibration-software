/* ============================================================================
   01 — stg.MergeOrdersData  (מוקשח לפי SP-DEVELOPMENT-PLAN)
   ----------------------------------------------------------------------------
   הבעיה המקורית:
       בבלוק WHEN MATCHED של MERGE ה-OrderDetails, שניים מתוך 12 התנאים השתמשו
       ב-'=' במקום ב-'<>'. בשרשרת OR הם התקיימו כמעט תמיד, ולכן ה-UPDATE רץ על
       ~9,820 שורות בכל ריצה שעתית (~235K עדכוני סרק ביום).

   מה השתנה בגרסה הזו (ההקשחה — לא רק תיקון שני התווים):
       הפרוצדורה נכתבה מחדש לפי התבנית הקנונית ב-SP-DEVELOPMENT-PLAN §4.
       לוגיקת המיזוג (3 MERGE, ניקוי הקטגוריות, בניית #OrderStatus, הסינונים)
       נשמרה כפי שהיא; רק המעטפת השתנתה.

   כללי התקן שהוחלו (מתוך 12):
       [1]  SET NOCOUNT ON + SET XACT_ABORT ON
       [2]  בלוק כותרת (מחבר/תאריך/תיאור/Jira) — נשמר מהמקור
       [3]  BEGIN TRY / BEGIN CATCH סביב כל ה-DML
       [4]  טרנזקציה מפורשת סביב שלוש פקודות ה-MERGE + ניקוי הקטגוריות (אטומי)
       [5]  ROLLBACK מותנה ב-XACT_STATE()<>0, רישום כשל, ואז THROW
       [6]  etl.usp_SyncRunStart בהתחלה + etl.usp_SyncRunEnd בשני נתיבי היציאה
       [7]  שורות שנזרקות (Doc IS NULL / OrderDetailId IS NULL) נכתבות ל-etl.SyncReject
       [8]  זיהוי שינויים ב-EXCEPT במקום שרשרת 12 ההשוואות — מייתר את תיקון האופרטור
       [12] אידמפוטנטיות: ריצה שנייה ללא שינוי במקור = 0 עדכונים

   כללים שנשארו פתוחים בכוונה (לא בהיקף ה-PR הזה — ראה SP-DEVELOPMENT-PLAN §5.3):
       [9]  WHEN NOT MATCHED BY SOURCE (מחיקה רכה) — לא נוסף. שלוש הרמות הן INSERT/UPDATE
            בלבד. הוספת מחיקה כאן דורשת צמצום היעד למקור הנכון (סיכון 🔴, שלב ד.4).
       [10] בלוק 29 הקטגוריות + כלל 100 הימים עדיין מקודדים — יציאה ל-ref.* היא N5/ה.1-ה.2.
       [11] @InintialOrderStatus עדיין נשלף לפי המחרוזת 'WaitingForCalibration' — יציאה
            לשליפה לפי Code היא שלב ה.5. סומן בהערה במקום.
       וכן בלוק העדכון של OrderDetailsItems נשאר מוער (שלב ד.1+ד.2 — דורש תיקון 7
       אופרטורים הפוכים בו-זמנית, אחרת הבאג חוזר גדול יותר).

   מקור:   calibrator_db/CalibratorDB/stg/Stored Procedures/MergeOrdersData.sql
   יעד:    CalibratorProd  (ואז Calibrator לאחר אימות)
   תלות:   03_etl_logging_framework.sql חייב לרוץ קודם (etl.SyncRunLog + etl.SyncReject
           + usp_SyncRunStart/End).

   ⚠ הנחות סכימה לאימות מול המסד האמיתי (אין גישה חיה בזמן הכתיבה):
       • etl.SyncReject קיימת עם העמודות RunId/SourceTable/SourceKey/Reason/Payload
         (מוגדרת ב-03). SourceKey כאן = SourceOrderId; אם המפתח היציב הוא OrderDetailId
         יש להחליף.
       • המרה ל-EXCEPT מטפלת ב-NULL כשווה ל-NULL, אבל — בשונה מ-COALESCE(...,0) המקורי —
         NULL אינו שווה ל-0. לכן בריצה הראשונה ייתכנו עדכונים נקודתיים בשורות שבהן
         dest=0 והמקור NULL (או להפך). מהריצה השנייה ואילך = 0 עדכונים (אידמפוטנטי).
   ============================================================================ */

SET NOCOUNT ON;
GO

/* --- שלב 1: מדידה לפני. הריצו ושמרו את התוצאה. ------------------------- */
SELECT
    'BEFORE' AS phase,
    COUNT(*)                                                   AS total_rows,
    SUM(CASE WHEN UpdatedDate >= DATEADD(HOUR,-2,GETDATE())
             THEN 1 ELSE 0 END)                                AS updated_last_2h,
    MAX(UpdatedDate)                                           AS max_updated
FROM dbo.OrderDetails;
GO

/* --- שלב 2: גיבוי ההגדרה הנוכחית. שמרו את הפלט לקובץ (תסריט חזרה לאחור). -- */
SELECT m.definition
FROM sys.sql_modules AS m
JOIN sys.objects     AS o ON o.object_id = m.object_id
JOIN sys.schemas     AS s ON s.schema_id = o.schema_id
WHERE s.name = 'stg' AND o.name = 'MergeOrdersData';
GO

/* --- שלב 3: החלת הגרסה המוקשחת ------------------------------------------- */
-- =============================================
-- Author:      Eduard Kudlaiev  (מוקשח: DBA, 2026-07-30)
-- Create date: 02/04/2025
-- Description: Merge orders data from amaba staging into dbo (3 levels)
-- JiraLink:
-- =============================================
ALTER PROCEDURE [stg].[MergeOrdersData]
    @DebugMode BIT = 0          -- 1 = להחזיר ספירות בסוף, בנוסף ללוג
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @proc  SYSNAME = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID),
            @RunId BIGINT,
            @src   INT,
            @ins   INT = 0,
            @upd   INT = 0,
            @del   INT = 0,
            @rej   INT = 0;

    /* ספירת פעולות אמיתית מכל שלוש ה-MERGE (כלל: OUTPUT $action) */
    DECLARE @acts TABLE (target_tbl NVARCHAR(40) NOT NULL, act NVARCHAR(10) NOT NULL);

    SELECT @src = COUNT(*) FROM [stg].[stg_Orders];

    EXEC etl.usp_SyncRunStart
         @ProcedureName = @proc,
         @TargetTable   = N'dbo.OrderWorkPlans/OrderDetails/OrderDetailsItems',
         @SourceRows    = @src,
         @RunId         = @RunId OUTPUT;

    BEGIN TRY
        /* ---- 0. בניית טבלת הסטטוסים (קריאה בלבד; לפני הטרנזקציה) ---------- */
        DROP TABLE IF EXISTS #OrderStatus;
        CREATE TABLE #OrderStatus
        (
            StatusId             INT NOT NULL,
            CodeINT              INT,
            StatusType           NVARCHAR(50)  COLLATE Latin1_General_100_CI_AI_SC,
            Code                 NVARCHAR(255) COLLATE Latin1_General_100_CI_AI_SC,
            StatusDescriptionENG NVARCHAR(255) COLLATE Latin1_General_100_CI_AI_SC
        );
        INSERT #OrderStatus (StatusId, CodeINT, StatusType, Code, StatusDescriptionENG)
        SELECT s.StatusId, TRY_CAST(s.Code AS INT) AS CodeINT,
               sc.StatusDescriptionENG AS StatusType, s.Code, s.StatusDescriptionENG
        FROM [dbo].[Statuses] AS s
        JOIN [dbo].[StatusesCategories] AS sc ON s.StatusCategoryId = sc.StatusCategoryId
        WHERE sc.StatusDescriptionENG IN ('OrderStatus','ReportStatus','CalibrationStatuses');

        DECLARE @InintialOrderStatus INT;
        /* ⚠ כלל 11: שליפה לפי מחרוזת תיאור. שינוי התיאור בטבלת Statuses ישתיק את
           הסנכרון בלי שגיאה. יציאה לשליפה לפי Code = שלב ה.5. נשמר כמקור בכוונה. */
        SELECT @InintialOrderStatus = StatusId
          FROM #OrderStatus AS os
         WHERE os.StatusType = N'OrderStatus'
           AND os.StatusDescriptionENG = 'WaitingForCalibration';

        BEGIN TRANSACTION;

        /* ---- 1. ניקוי קטגוריות ראשיות בנחיתה ----------------------------
           ⚠ כלל 10: 29 קטגוריות עברית מקודדות. יעד: ref.CategoryMapping (N5/ה.1). */
        UPDATE t
        SET MainCategorySourceId =
            CASE LTRIM(RTRIM(t.MainCategorySourceId))
                WHEN N'אורך'                    THEN N'אורך וזווית'
                WHEN N'אורך מדוייקים'           THEN N'אורך וזווית'
                WHEN N'אל חמה'                  THEN N'NA'
                WHEN N'אלקטרוניקה'              THEN N'אלקטרוניקה'
                WHEN N'בדיקות דגם'              THEN N'NA'
                WHEN N'גלאי גזים'               THEN N'גזים'
                WHEN N'גפן'                     THEN N'NA'
                WHEN N'זמן'                     THEN N'זמן'
                WHEN N'טמפרטורה'                THEN N'טמפרטורה ולחות'
                WHEN N'כח'                      THEN N'כוח'
                WHEN N'לחות'                    THEN N'טמפרטורה ולחות'
                WHEN N'לחץ'                     THEN N'לחץ'
                WHEN N'ללא מחלקה'               THEN N'NA'
                WHEN N'מאגנוס'                  THEN N'אלקטרוניקה'
                WHEN N'מדידים'                  THEN N'אורך וזווית'
                WHEN N'מהירות אוויר'            THEN N'מהירות אוויר'
                WHEN N'מומנט'                   THEN N'מומנט'
                WHEN N'מכונות'                  THEN N'NA'
                WHEN N'מסה'                     THEN N'מסה'
                WHEN N'מקבילונים'               THEN N'אורך וזווית'
                WHEN N'נפח'                     THEN N'נפח'
                WHEN N'סיבוב'                   THEN N'אורך וזווית'
                WHEN N'ספיקה'                   THEN N'ספיקה'
                WHEN N'קבלני משנה'              THEN N'NA'
                WHEN N'קבלני משנה כללי'         THEN N'NA'
                WHEN N'קושי'                    THEN N'קשיות'
                WHEN N'רדיומטריה ופוטומטריה'    THEN N'רדיומטריה'
                WHEN N'שירותי איכות ורגולציה'   THEN N'NA'
                WHEN N'תעשיה אוירית'            THEN N'NA'
                ELSE t.MainCategorySourceId
            END
        FROM [stg].[stg_Orders] AS t;

        /* ---- 2. MERGE רמה 1 — OrderWorkPlans (INSERT-only, כמקור) -------- */
        MERGE INTO [dbo].[OrderWorkPlans] WITH (HOLDLOCK) AS dest
        USING (
            SELECT DISTINCT
                 o.ORDNAME              AS [OrderNumber]
                ,o.OpenDate             AS [WorkPlanOpenDate]
                ,GETDATE()              AS [CreatedDate]
                ,0                      AS [UpdateUserID]
                ,0                      AS [CreatedByUserId]
                ,0                      AS [IsCancelled]
                ,c.[CustomerId]
                ,NULL                   AS [Notes]
                ,ss.[SourceId]
                ,@InintialOrderStatus   AS OrderOverallStatusId
                ,IIF(LEN(o.[ShipTypeDesc]) > 1, o.[ShipTypeDesc], NULL) AS [ShipTypeDesc]
                ,o.SourceOrderId        AS [OrderSourceId]
            FROM [stg].[stg_Orders] AS o
            JOIN [dbo].[Source] AS ss ON o.[SourceSystem] = ss.SourceName
            LEFT JOIN [dbo].[Customers] AS c
                   ON c.CustomerIdFromSource = o.CustomerSourceId
                  AND c.SourceId = ss.SourceId
                  AND c.IsDeleted = 0
        ) AS source
           ON dest.[OrderSourceId] = source.[OrderSourceId]
          AND dest.[SourceId]      = source.[SourceId]
        WHEN NOT MATCHED BY TARGET THEN
            INSERT ([OrderNumber],[WorkPlanOpenDate],[CreatedDate],[CreatedByUserId],
                    [UpdateUserID],[IsCancelled],[Notes],[OrderSourceId],[SourceId],
                    [CustomerId],[OrderOverallStatusId],[ShipTypeDesc])
            VALUES (source.[OrderNumber],source.[WorkPlanOpenDate],source.[CreatedDate],
                    source.[CreatedByUserId],source.[UpdateUserID],source.[IsCancelled],
                    source.[Notes],source.[OrderSourceId],source.[SourceId],source.[CustomerId],
                    source.[OrderOverallStatusId],source.[ShipTypeDesc])
        OUTPUT N'OrderWorkPlans', $action INTO @acts (target_tbl, act);

        /* ---- 3. MERGE רמה 2 — OrderDetails (זיהוי שינויים ב-EXCEPT) ------ */
        MERGE INTO [dbo].[OrderDetails] WITH (HOLDLOCK) AS dest
        USING (
            SELECT DISTINCT
                 wp.[OrderWorkPlanId]
                ,o.[SpecialCareTypeId]
                ,CASE
                    WHEN RIGHT(o.[PartName], 2) IN ('-7','-8','-9') AND TRY_CAST(RIGHT(o.[PartName], 2) AS INT) IS NOT NULL THEN 0
                    WHEN RIGHT(o.[PartName], 2) IN ('-3','-0','-1') AND TRY_CAST(RIGHT(o.[PartName], 2) AS INT) IS NOT NULL THEN 1 --10 should be external
                 ELSE NULL END          AS [IsInHouse]
                ,o.[PartName]
                ,o.[PART]
                ,GETDATE()              AS [CreatedDate]
                ,GETDATE()              AS [UpdatedDate]
                ,0                      AS [CreatedByUserId]
                ,0                      AS [UpdateUserID]
                ,o.OrderLineCnt
                ,pt.OrdersProductTypeId
                ,o.DeviceType
                ,o.OrderDetailId        AS OrderDetailSourceId
                ,o.VPRICE
                ,o.PRICE
                ,mc.[ID]                AS [MainCategoryId]
                ,sc.ID                  AS [SecondaryCategoryId]
                ,o.[CustomerPackingExists]
                ,o.[PackageLocation]
                ,cs.CustomerSiteId
            FROM [stg].[stg_Orders] AS o
            JOIN [dbo].[Source] AS s ON o.SourceSystem = s.SourceName
            JOIN [dbo].[OrderWorkPlans] AS wp
                  ON wp.OrderSourceId = o.SourceOrderId AND o.SourceSystem = s.SourceName
            LEFT JOIN [dbo].[OrdersProductTypes] AS pt
                  ON pt.OrdersProductTypeName = o.DeviceType AND pt.IsDeleted = 0
            LEFT JOIN [dbo].[MainCategories] AS mc
                  ON o.MainCategorySourceId = mc.MainCategoryName AND mc.IsDeleted = 0
            LEFT JOIN [dbo].[SecondaryCategories] AS sc
                  ON o.SecondCategorySourceId = sc.SecondaryCategoryName AND sc.IsDeleted = 0
            LEFT JOIN [dbo].[Customers] AS c
                  ON c.CustomerIdFromSource = o.CustomerSourceId AND c.SourceId = s.SourceId AND c.IsDeleted = 0
            LEFT JOIN [dbo].[CustomerSites] AS cs
                  ON c.CustomerId = cs.CustomerId AND cs.CustomerSiteCode = o.[DESTCODE] AND cs.IsDeleted = 0
        ) AS source
           ON dest.[OrderWorkPlanId]     = source.[OrderWorkPlanId]
          AND source.OrderDetailSourceId = dest.[OrderDetailSourceId]

        /* כלל 8: EXCEPT במקום שרשרת 12 ההשוואות. NULL-safe, בלי אופרטור שאפשר להפוך.
           רשימת ההשוואה = 13 עמודות עסקיות בלבד (לא CreatedDate/UpdatedDate — הן GETDATE()
           ולכן היו שוברות את האידמפוטנטיות). */
        WHEN MATCHED AND EXISTS (
                SELECT source.[SpecialCareTypeId], source.[IsInHouse], source.[OrderLineCnt],
                       source.[OrdersProductTypeId], source.[PART], source.[VPRICE], source.[PRICE],
                       source.[MainCategoryId], source.[SecondaryCategoryId],
                       source.[CustomerPackingExists], source.[CustomerSiteId],
                       source.[PackageLocation], source.[PartName]
                EXCEPT
                SELECT dest.[SpecialCareTypeId], dest.[IsInHouse], dest.[OrderLineCnt],
                       dest.[OrdersProductTypeId], dest.[PART], dest.[VPRICE], dest.[PRICE],
                       dest.[MainCategoryId], dest.[SecondaryCategoryId],
                       dest.[CustomerPackingExists], dest.[CustomerSiteId],
                       dest.[PackageLocation], dest.[PartName] )
            THEN UPDATE SET
                 dest.[SpecialCareTypeId]      = source.[SpecialCareTypeId]
                ,dest.[IsInHouse]              = source.[IsInHouse]
                ,dest.[UpdatedDate]            = source.[UpdatedDate]
                ,dest.[UpdateUserID]           = source.[UpdateUserID]
                ,dest.[OrderLineCnt]           = source.[OrderLineCnt]
                ,dest.[OrdersProductTypeId]    = source.[OrdersProductTypeId]
                ,dest.[PART]                   = source.[PART]
                ,dest.[VPRICE]                 = source.[VPRICE]
                ,dest.[PRICE]                  = source.[PRICE]
                ,dest.[MainCategoryId]         = source.[MainCategoryId]
                ,dest.[SecondaryCategoryId]    = source.[SecondaryCategoryId]
                ,dest.[CustomerPackingExists]  = source.[CustomerPackingExists]
                ,dest.[CustomerSiteId]         = source.[CustomerSiteId]
                ,dest.[PackageLocation]        = source.[PackageLocation]
                ,dest.[PartName]               = source.[PartName]

        WHEN NOT MATCHED BY TARGET THEN
            INSERT ([OrderWorkPlanId],[SpecialCareTypeId],[IsInHouse],[PartName],[CreatedDate],
                    [UpdatedDate],[CreatedByUserId],[UpdateUserID],[OrderLineCnt],
                    [OrdersProductTypeId],[PART],[OrderDetailSourceId],[VPRICE],[PRICE],
                    [MainCategoryId],[SecondaryCategoryId],[CustomerPackingExists],
                    [CustomerSiteId],[PackageLocation])
            VALUES (source.[OrderWorkPlanId],source.[SpecialCareTypeId],source.[IsInHouse],
                    source.[PartName],source.[CreatedDate],source.[UpdatedDate],
                    source.[CreatedByUserId],source.[UpdateUserID],source.[OrderLineCnt],
                    source.[OrdersProductTypeId],source.[PART],source.[OrderDetailSourceId],
                    source.[VPRICE],source.[PRICE],source.[MainCategoryId],
                    source.[SecondaryCategoryId],source.[CustomerPackingExists],
                    source.[CustomerSiteId],source.[PackageLocation])
        OUTPUT N'OrderDetails', $action INTO @acts (target_tbl, act);

        /* ---- 4. דחיות (כלל 7): שורות שלא ייצרו פריט כיול — נרשמות, לא נעלמות
           הסינון המקורי של MERGE רמה 3 הוא: OrderDetailId IS NOT NULL AND Doc IS NOT NULL.
           כאן סופרים ורושמים את מה שנופל שם (~593 שורות/ריצה). */
        INSERT etl.SyncReject (RunId, SourceTable, SourceKey, Reason, Payload)
        SELECT @RunId,
               N'stg.stg_Orders',
               CONVERT(NVARCHAR(200), o.SourceOrderId),
               CASE WHEN o.Doc IS NULL THEN 'DOC_NULL' ELSE 'NO_DETAIL_ID' END,
               (SELECT o.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
          FROM [stg].[stg_Orders] AS o
         WHERE o.OrderDetailId IS NULL
            OR o.Doc IS NULL;
        SET @rej = @@ROWCOUNT;

        /* ---- 5. MERGE רמה 3 — OrderDetailsItems (INSERT-only, כמקור) -----
           בלוק ה-WHEN MATCHED נשאר מוער בכוונה (שלב ד.1+ד.2): הפעלתו דורשת תיקון
           7 אופרטורים הפוכים בו-זמנית, אחרת הבאג חוזר גדול יותר. מחוץ להיקף PR זה.
           ⚠ כלל: REVERSE(o.[Devicemodel]) נשמר כמקור — הסרתו היא שלב ה.4 (נוגע בתצוגה). */
        MERGE INTO [dbo].[OrderDetailsItems] WITH (HOLDLOCK) AS dest
        USING (
            SELECT DISTINCT
                 o.[SerialNumber]
                ,od.OrderDetailId
                ,o.[ManufacturerNumber]
                ,REVERSE(o.[Devicemodel]) AS [DeviceModel]
                ,o.[SpecialCareTypeId]
                ,o.[InHouse]            AS [IsInHouse]
                ,o.[PartName]
                ,NULL                   AS [MbaReportNumber]
                ,c.[CustomerId]
                ,o.[KLINE]
                ,o.[SERN]
                ,o.[ProductLocation]
                ,NULL                   AS [StatusId]
                ,GETDATE()              AS [CreatedDate]
                ,GETDATE()              AS [UpdatedDate]
                ,0                      AS [CreatedByUserId]
                ,0                      AS [UpdateUserID]
                ,o.[Doc]
                ,o.[NextCalibrationDate]
                ,o.AdditionalDeviceNumber
                ,NULL /*o.CalibDate*/   AS [ActualCalibrationDate]
                ,NULL                   AS CustomerReceivingDate
                ,IIF(LEN(o.ShippingDoc) > 1, o.ShippingDoc, NULL)         AS ShippingDoc
                ,IIF(LEN(o.ShippingAddress) > 1, o.ShippingAddress, NULL) AS ShippingAddress
                ,o.DOC_N
                ,IIF(o.[ActualReturnDate]   > GETDATE()-100, o.[ActualReturnDate],   NULL) AS [ActualReturnDate]
                ,IIF(o.[ExpectedReturnDate] > GETDATE()-100, o.[ExpectedReturnDate], NULL) AS [ExpectedReturnDate]
                ,o.OrdersDeviceManufacturer
            FROM [stg].[stg_Orders] AS o
            JOIN [dbo].[Source] AS s ON o.SourceSystem = s.SourceName
            JOIN [dbo].[OrderWorkPlans] AS wp ON wp.OrderSourceId = o.SourceOrderId
            JOIN [dbo].[OrderDetails] AS od
                  ON wp.[OrderWorkPlanId] = od.[OrderWorkPlanId]
                 AND od.OrderDetailSourceId = o.OrderDetailId
            LEFT JOIN [dbo].[Customers] AS c
                  ON c.CustomerIdFromSource = o.CustomerSourceId AND c.SourceId = s.SourceId AND c.IsDeleted = 0
            WHERE o.OrderDetailId IS NOT NULL AND o.Doc IS NOT NULL
        ) AS source
           ON dest.OrderDetailId = source.OrderDetailId
          AND source.[Doc]       = dest.[Doc]
        /* WHEN MATCHED ... (מוער — שלב ד.1+ד.2; ראה תסריט המקור לגיבוי) */
        WHEN NOT MATCHED BY TARGET THEN
            INSERT ([OrderDetailId],[SerialNumber],[ManufacturerNumber],[DeviceModel],
                    [MbaReportNumber],[CreatedDate],[UpdatedDate],[CreatedByUserId],
                    [UpdateUserID],[SERN],[ProductLocation],[Doc],[NextCalibrationDate],
                    [AdditionalDeviceNumber],[ActualCalibrationDate],[CustomerReceivingDate],
                    [ShippingDoc],[ShippingAddress],[DOC_N],[ActualReturnDate],
                    [ExpectedReturnDate],[OrdersDeviceManufacturer])
            VALUES (source.[OrderDetailId],source.[SerialNumber],source.[ManufacturerNumber],
                    source.[DeviceModel],source.[MbaReportNumber],source.[CreatedDate],
                    source.[UpdatedDate],source.[CreatedByUserId],source.[UpdateUserID],
                    source.[SERN],source.[ProductLocation],source.[Doc],source.[NextCalibrationDate],
                    source.[AdditionalDeviceNumber],source.[ActualCalibrationDate],
                    source.[CustomerReceivingDate],source.[ShippingDoc],source.[ShippingAddress],
                    source.[DOC_N],source.[ActualReturnDate],source.[ExpectedReturnDate],
                    source.[OrdersDeviceManufacturer])
        OUTPUT N'OrderDetailsItems', $action INTO @acts (target_tbl, act);

        /* ---- 6. ספירות מצטברות משלוש הרמות ------------------------------ */
        SELECT @ins = SUM(CASE WHEN act = 'INSERT' THEN 1 ELSE 0 END),
               @upd = SUM(CASE WHEN act = 'UPDATE' THEN 1 ELSE 0 END),
               @del = SUM(CASE WHEN act = 'DELETE' THEN 1 ELSE 0 END)
          FROM @acts;

        COMMIT TRANSACTION;

        EXEC etl.usp_SyncRunEnd
             @RunId        = @RunId, @Status = 'SUCCESS',
             @RowsInserted = @ins,  @RowsUpdated = @upd,
             @RowsDeleted  = @del,  @RowsRejected = @rej;

        IF @DebugMode = 1
            SELECT @RunId AS RunId, @src AS SourceRows, @ins AS Inserted,
                   @upd AS Updated, @del AS Deleted, @rej AS Rejected;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

        DECLARE @errNum INT            = ERROR_NUMBER(),
                @errMsg NVARCHAR(2048) = ERROR_MESSAGE();

        EXEC etl.usp_SyncRunEnd
             @RunId = @RunId, @Status = 'FAILED',
             @ErrorNumber = @errNum, @ErrorMessage = @errMsg;

        THROW;   -- כלל 5: בלי THROW הג'וב ב-SQL Agent מדווח הצלחה על כשל
    END CATCH
END
GO

/* --- שלב 4: אימות שההקשחה נכנסה --------------------------------------------- */
SELECT
    CASE WHEN m.definition LIKE '%EXCEPT%'
          AND m.definition LIKE '%BEGIN TRY%'
          AND m.definition LIKE '%etl.SyncReject%'
          AND m.definition LIKE '%THROW%'
         THEN 'OK — TRY/CATCH + EXCEPT + SyncReject + THROW נמצאו'
         ELSE 'FAIL — ההקשחה לא הוחלה במלואה' END AS harden_status
FROM sys.sql_modules AS m
JOIN sys.objects     AS o ON o.object_id = m.object_id
JOIN sys.schemas     AS s ON s.schema_id = o.schema_id
WHERE s.name = 'stg' AND o.name = 'MergeOrdersData';
GO

/* --- שלב 5: מדידה אחרי + בדיקת אידמפוטנטיות ---------------------------------
   הריצו פעמיים ברצף אחרי שהג'וב טען את stg_Orders:
       EXEC stg.MergeOrdersData @DebugMode = 1;   -- ריצה 1
       EXEC stg.MergeOrdersData @DebugMode = 1;   -- ריצה 2  → Updated חייב להיות 0
   ואז:
       EXEC etl.usp_SyncRunReport @Hours = 1;
       SELECT Reason, COUNT(*) FROM etl.SyncReject
        WHERE RunId IN (SELECT RunId FROM etl.SyncRunLog
                         WHERE ProcedureName = 'stg.MergeOrdersData'
                           AND StartedAt >= DATEADD(HOUR,-1,SYSDATETIME()))
        GROUP BY Reason;
   הצפי: ~593 שורות DOC_NULL/NO_DETAIL_ID ב-SyncReject; updated_last_2h יורד לעשרות.
   קריטריון עצירה: אם ריצה 2 מחזירה Updated > 0 — זיהוי השינויים שבור, לחזור לאחור.
   --------------------------------------------------------------------------- */

/* --- החזרה לאחור ------------------------------------------------------------
   הריצו את ההגדרה שנשמרה בשלב 2, לאחר החלפת CREATE PROCEDURE ב-ALTER PROCEDURE.
   --------------------------------------------------------------------------- */
