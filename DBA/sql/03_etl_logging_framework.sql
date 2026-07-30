/* ============================================================================
   03 — תשתית לוגים לסנכרון
   ----------------------------------------------------------------------------
   מה זה פותר:
     ביקורת סטטית על 16 פרוצדורות המיזוג הראתה:
       • 0 מתוך 16 עם TRY/CATCH   → כשל אינו נתפס
       • 0 מתוך 16 עם טרנזקציה    → כשל באמצע משאיר נתונים חלקיים
       • 1 מתוך 16 עם NOT MATCHED BY SOURCE → מחיקות לא מגיעות
       • אף אחת אינה סופרת שורות שנפלו בסינון

     התשתית כאן מוסיפה: רישום ריצה, ספירת שורות לפי פעולה, תפיסת שגיאות,
     וטרנזקציה — בלי לשנות את לוגיקת המיזוג הקיימת.

   סדר התקנה:  חלק א (טבלאות) → חלק ב (פרוצדורות) → חלק ג (החלת התבנית)
   בטיחות:     חלקים א+ב הם DDL חדש בלבד; אינם נוגעים בקוד או בנתונים קיימים.

   כללי SP-DEVELOPMENT-PLAN שהוחלו על התשתית עצמה:
       [1]  SET NOCOUNT ON + SET XACT_ABORT ON בכל פרוצדורה
       [2]  בלוק כותרת לכל פרוצדורה
       [7]  חלק א יוצר גם את etl.SyncReject — יעד הדחיות שכלל 7 דורש (SP-DEVELOPMENT-PLAN §3).
            בלי הטבלה הזו, כתיבת הדחיות ב-01 נכשלת.
   הערה:   פרוצדורות הרישום הן תשתית ולכן אינן רושמות/מגלגלות את עצמן; הן פקודות
           בודדות (INSERT/UPDATE/SELECT) ללא DML מרובה שדורש טרנזקציה מפורשת.
   ============================================================================ */


/* ==========================================================================
   חלק א — טבלאות הלוג
   ========================================================================== */

/* --- א.1: etl.SyncRunLog — מה רץ, מתי, כמה (הספירות) --------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
               WHERE s.name='etl' AND t.name='SyncRunLog')
BEGIN
    CREATE TABLE etl.SyncRunLog
    (
        RunId          BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_etl_SyncRunLog PRIMARY KEY CLUSTERED,
        ProcedureName  NVARCHAR(128)  NOT NULL,
        TargetTable    NVARCHAR(128)  NULL,
        StartedAt      DATETIME2(3)   NOT NULL
            CONSTRAINT DF_etl_SyncRunLog_StartedAt DEFAULT SYSDATETIME(),
        CompletedAt    DATETIME2(3)   NULL,
        DurationMs     AS DATEDIFF(MILLISECOND, StartedAt, CompletedAt),
        Status         VARCHAR(20)    NOT NULL
            CONSTRAINT DF_etl_SyncRunLog_Status DEFAULT 'RUNNING'
            CONSTRAINT CK_etl_SyncRunLog_Status
                CHECK (Status IN ('RUNNING','SUCCESS','FAILED')),
        SourceRows     INT            NULL,   -- שורות בנחיתה
        RowsInserted   INT            NULL,
        RowsUpdated    INT            NULL,
        RowsDeleted    INT            NULL,
        RowsRejected   INT            NULL,   -- נפלו בסינון — הפער שהיה חסר
        ErrorNumber    INT            NULL,
        ErrorMessage   NVARCHAR(2048) NULL
    );

    CREATE INDEX IX_etl_SyncRunLog_Proc_Started
        ON etl.SyncRunLog (ProcedureName, StartedAt DESC)
        INCLUDE (Status, RowsInserted, RowsUpdated, RowsRejected);
END
GO


/* --- א.2: etl.SyncReject — אילו שורות נדחו ולמה (כלל 7) ------------------
   SyncRunLog סופר *כמה* נדחו; הטבלה הזו אומרת *אילו* ו-*למה*. בלעדיה כלל 7 לא
   ניתן למימוש, ו-01_fix_MergeOrdersData.sql (INSERT etl.SyncReject) נכשל.
   ⚠ Payload NVARCHAR(MAX): על ~600 שורות/שעה יגדל מהר — דרוש ג'וב תחזוקה שמוחק
     דחיות מעל 90 יום (SP-DEVELOPMENT-PLAN §3). */
IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
               WHERE s.name = 'etl' AND t.name = 'SyncReject')
BEGIN
    CREATE TABLE etl.SyncReject
    (
        RejectId     BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_etl_SyncReject PRIMARY KEY CLUSTERED,
        RunId        BIGINT         NOT NULL
            CONSTRAINT FK_etl_SyncReject_Run REFERENCES etl.SyncRunLog (RunId),
        SourceTable  NVARCHAR(128)  NOT NULL,
        SourceKey    NVARCHAR(200)  NULL,     -- המזהה בנחיתה, למעקב חזרה למקור
        Reason       VARCHAR(50)    NOT NULL, -- קוד קצר: DOC_NULL / NO_DETAIL_ID / EMAIL_NO_MATCH
        Detail       NVARCHAR(500)  NULL,
        Payload      NVARCHAR(MAX)  NULL,     -- השורה כ-JSON, לשחזור ידני
        RejectedAt   DATETIME2(3)   NOT NULL
            CONSTRAINT DF_etl_SyncReject_At DEFAULT SYSDATETIME()
    );

    CREATE INDEX IX_etl_SyncReject_Run    ON etl.SyncReject (RunId);
    CREATE INDEX IX_etl_SyncReject_Reason ON etl.SyncReject (Reason, RejectedAt DESC);
END
GO


/* ==========================================================================
   חלק ב — פרוצדורות הרישום
   ========================================================================== */

-- =============================================
-- Author:      DBA
-- Create date: 2026-07-30
-- Description: פותח שורת ריצה ב-etl.SyncRunLog ומחזיר RunId (כלל 6)
-- =============================================
CREATE OR ALTER PROCEDURE etl.usp_SyncRunStart
    @ProcedureName NVARCHAR(128),
    @TargetTable   NVARCHAR(128) = NULL,
    @SourceRows    INT           = NULL,
    @RunId         BIGINT        OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    INSERT etl.SyncRunLog (ProcedureName, TargetTable, SourceRows, Status)
    VALUES (@ProcedureName, @TargetTable, @SourceRows, 'RUNNING');
    SET @RunId = SCOPE_IDENTITY();
END
GO


-- =============================================
-- Author:      DBA
-- Create date: 2026-07-30
-- Description: סוגר שורת ריצה ב-etl.SyncRunLog עם סטטוס וספירות (כלל 6)
-- =============================================
CREATE OR ALTER PROCEDURE etl.usp_SyncRunEnd
    @RunId        BIGINT,
    @Status       VARCHAR(20),
    @RowsInserted INT            = NULL,
    @RowsUpdated  INT            = NULL,
    @RowsDeleted  INT            = NULL,
    @RowsRejected INT            = NULL,
    @ErrorNumber  INT            = NULL,
    @ErrorMessage NVARCHAR(2048) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    UPDATE etl.SyncRunLog
       SET CompletedAt  = SYSDATETIME(),
           Status       = @Status,
           RowsInserted = @RowsInserted,
           RowsUpdated  = @RowsUpdated,
           RowsDeleted  = @RowsDeleted,
           RowsRejected = @RowsRejected,
           ErrorNumber  = @ErrorNumber,
           ErrorMessage = @ErrorMessage
     WHERE RunId = @RunId;
END
GO


/* --- דוח מצב: מה רץ, מה נכשל, מה תקוע ------------------------------------ */
-- =============================================
-- Author:      DBA
-- Create date: 2026-07-30
-- Description: דוח קריאה-בלבד על ריצות הסנכרון ב-N השעות האחרונות
-- =============================================
CREATE OR ALTER PROCEDURE etl.usp_SyncRunReport
    @Hours INT = 24
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SELECT TOP (200)
           RunId, ProcedureName, TargetTable, Status,
           StartedAt, CompletedAt, DurationMs,
           SourceRows, RowsInserted, RowsUpdated, RowsDeleted, RowsRejected,
           CASE WHEN SourceRows > 0
                THEN CAST(100.0 * ISNULL(RowsRejected,0) / SourceRows AS DECIMAL(5,2))
           END AS RejectedPct,
           ErrorMessage
      FROM etl.SyncRunLog
     WHERE StartedAt >= DATEADD(HOUR, -@Hours, SYSDATETIME())
     ORDER BY StartedAt DESC;

    /* ריצות תקועות: RUNNING יותר משעה */
    SELECT 'STUCK RUNS' AS alert, RunId, ProcedureName, StartedAt,
           DATEDIFF(MINUTE, StartedAt, SYSDATETIME()) AS running_minutes
      FROM etl.SyncRunLog
     WHERE Status = 'RUNNING'
       AND StartedAt < DATEADD(HOUR, -1, SYSDATETIME())
     ORDER BY StartedAt;

    /* סיכום לפי פרוצדורה */
    SELECT ProcedureName,
           COUNT(*)                                              AS runs,
           SUM(CASE WHEN Status='FAILED'  THEN 1 ELSE 0 END)      AS failed,
           SUM(CASE WHEN Status='RUNNING' THEN 1 ELSE 0 END)      AS still_running,
           AVG(DurationMs)                                        AS avg_ms,
           SUM(ISNULL(RowsRejected,0))                            AS total_rejected
      FROM etl.SyncRunLog
     WHERE StartedAt >= DATEADD(HOUR, -@Hours, SYSDATETIME())
     GROUP BY ProcedureName
     ORDER BY failed DESC, total_rejected DESC;
END
GO


/* ==========================================================================
   חלק ג — התבנית להחלה על פרוצדורת מיזוג קיימת
   --------------------------------------------------------------------------
   הדוגמה: stg.MergeCustomerRemarks (54 שורות, הקטנה מכולן) — נבחרה כפיילוט
   כי סיכון השינוי בה מינימלי. אחרי שהתבנית מוכיחה את עצמה, מחילים אותה
   על MergeOrdersData.

   שלושת הרכיבים שהתבנית מוסיפה:
     1. OUTPUT $action לתוך טבלה משתנית  → ספירת INSERT/UPDATE/DELETE אמיתית
     2. ספירת @rejected לפני המיזוג      → מה נפל בסינון
     3. TRY/CATCH + טרנזקציה             → כשל נתפס, נרשם, ולא משאיר חלקי
   ========================================================================== */
/*
ALTER PROCEDURE stg.MergeCustomerRemarks
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RunId BIGINT,
            @src   INT,
            @rej   INT,
            @ins   INT = 0,
            @upd   INT = 0,
            @del   INT = 0;

    -- שורות בנחיתה, ושורות שייפלו בסינון (כאן: ללא לקוח מתאים)
    SELECT @src = COUNT(*) FROM stg.stg_CustomerRemarks;

    SELECT @rej = COUNT(*)
      FROM stg.stg_CustomerRemarks AS r
     WHERE NOT EXISTS (SELECT 1 FROM dbo.Customers AS c
                        WHERE c.CustomerIdFromSource = r.CustomerId);

    EXEC etl.usp_SyncRunStart
             @ProcedureName = N'stg.MergeCustomerRemarks',
             @TargetTable   = N'dbo.CustomerRemarks',
             @SourceRows    = @src,
             @RunId         = @RunId OUTPUT;

    BEGIN TRY
        DECLARE @actions TABLE (act NVARCHAR(10));

        BEGIN TRANSACTION;

            MERGE INTO dbo.CustomerRemarks AS dest
            USING ( /* ...  ה-SELECT המקורי, ללא שינוי  ... */ ) AS source
               ON dest.CustomerId = source.CustomerId
            WHEN MATCHED AND ( /* ... תנאי השינוי המקוריים ... */ )
                THEN UPDATE SET /* ... */
            WHEN NOT MATCHED BY TARGET
                THEN INSERT ( /* ... */ ) VALUES ( /* ... */ )
            -- להוסיף כאשר מחליטים לטפל במחיקות:
            -- WHEN NOT MATCHED BY SOURCE
            --     THEN UPDATE SET dest.IsDeleted = 1
            OUTPUT $action INTO @actions;

        COMMIT TRANSACTION;

        SELECT @ins = SUM(CASE WHEN act='INSERT' THEN 1 ELSE 0 END),
               @upd = SUM(CASE WHEN act='UPDATE' THEN 1 ELSE 0 END),
               @del = SUM(CASE WHEN act='DELETE' THEN 1 ELSE 0 END)
          FROM @actions;

        EXEC etl.usp_SyncRunEnd @RunId, 'SUCCESS', @ins, @upd, @del, @rej;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

        DECLARE @errNum INT           = ERROR_NUMBER(),
                @errMsg NVARCHAR(2048) = ERROR_MESSAGE();

        EXEC etl.usp_SyncRunEnd @RunId, 'FAILED',
                 @ErrorNumber = @errNum, @ErrorMessage = @errMsg;

        THROW;   -- כדי שהג'וב ב-SQL Agent ייכשל וייראה כשל
    END CATCH
END
*/


/* ============================================================================
   שימוש:
       EXEC etl.usp_SyncRunReport;            -- 24 שעות אחרונות
       EXEC etl.usp_SyncRunReport @Hours = 168;

   התראה מומלצת — שלב שני בג'וב CalibratorMainLoadProd:
       IF EXISTS (SELECT 1 FROM etl.SyncRunLog
                   WHERE Status = 'FAILED'
                     AND StartedAt >= DATEADD(HOUR,-2,SYSDATETIME()))
           EXEC msdb.dbo.sp_send_dbmail @recipients='...', @subject='Calibrator sync failed';
   ============================================================================ */
