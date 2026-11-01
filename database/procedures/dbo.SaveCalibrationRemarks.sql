/*
    dbo.SaveCalibrationRemarks                                                             MBA-848
    ---------------------------------------------------------------------------------------------
    Saves one remarks section as a whole - the report's remarks, or one chamber cycle's - in one
    transaction: the set sent replaces the set saved. Remarks are saved with the order so they
    survive a refresh and re-opening the order, and stay editable until the report is signed
    (Nofar, MBA-848, criteria 16-17 and 01/11).

    @Scope 'Report' with @CalibrationCycleStartDate NULL, or 'Cycle' with the cycle's start time
    (the key of dbo.CalibrationCycles; cycles have no id).

    @Remarks  JSON array, in print order; [] clears the section. Each element is one of:
        {"PredefinedRemarkId": 17, "Values": ["15"]}
            a list remark; only its values changed. Both texts are rendered here from the list
            row's templates, so the English follows the Hebrew. Values fill {1}, {2}, ...; a
            missing or null element takes the row's default; every placeholder must end up with a
            non-empty value.
        {"PredefinedRemarkId": 17, "TextHEB": "...", "TextENG": "..."}
            a list remark whose wording the calibrator changed: their texts are kept as given,
            IsCustomized = 1. TextENG may be omitted - they translate only when needed (Nofar, 01/11).
        {"Text": "..."}
            a remark the calibrator typed, printed as typed in either language, no length limit.
    Deciding which of the first two a dialog edit is - did the calibrator change only the values? -
    is the screen's job: compare the edited text with the row's TextHEB, placeholders as wildcards.

    A list row that is no longer active can still be saved if this section already holds it, so a
    report started before a list update can be saved again unchanged.

    @Apply  0 (default) writes nothing and returns the rows as they WOULD be saved - including the
            rendered Hebrew and English - so the dialog can preview a remark in both languages.
            1 saves.

    Refuses (THROW 51000) when the report is locked (signed), the line or the cycle does not exist,
    or an element is malformed. Saving the same set again writes nothing (Outcome NoChange).

    One result set: one row per remark - Outcome (WouldSave | Saved | NoChange), DisplayOrder,
    PredefinedRemarkId, ValuesJson, IsCustomized, TextHEB, TextENG. An empty section returns no rows.
*/
CREATE OR ALTER PROCEDURE dbo.SaveCalibrationRemarks
    @LoggedInUserEmail         NVARCHAR(255),
    @OrderDetailsItemId        INT,
    @Scope                     NVARCHAR(10),
    @CalibrationCycleStartDate DATETIME2(0) = NULL,
    @Remarks                   NVARCHAR(MAX),
    @Apply                     BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @UserId INT = (SELECT ID FROM dbo.Users WHERE Email = @LoggedInUserEmail);

    IF @UserId IS NULL
        THROW 51000, 'Unknown user.', 1;
    IF @Scope NOT IN (N'Report', N'Cycle')
        THROW 51000, 'Scope must be Report or Cycle.', 1;
    IF @Scope = N'Report' AND @CalibrationCycleStartDate IS NOT NULL
        THROW 51000, 'A report remark takes no CalibrationCycleStartDate.', 1;
    IF @Scope = N'Cycle' AND @CalibrationCycleStartDate IS NULL
        THROW 51000, 'A cycle remark needs CalibrationCycleStartDate.', 1;
    IF ISJSON(@Remarks) = 0 OR LEFT(LTRIM(@Remarks), 1) <> N'['
        THROW 51000, 'Remarks must be a JSON array.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.OrderDetailsItems
                   WHERE OrderDetailsItemId = @OrderDetailsItemId AND IsDeleted = 0)
        THROW 51000, 'Unknown OrderDetailsItemId.', 1;
    IF @Scope = N'Cycle'
       AND NOT EXISTS (SELECT 1 FROM dbo.CalibrationCycles
                       WHERE OrderDetailsItemId = @OrderDetailsItemId
                         AND CalibrationCycleStartDate = @CalibrationCycleStartDate
                         AND IsDeleted = 0)
        THROW 51000, 'No live calibration cycle starts at that time on this line.', 1;

    /* ---- the set as sent ------------------------------------------------------------------- */
    DROP TABLE IF EXISTS #In;
    SELECT DisplayOrder       = CAST(e.[key] AS INT) + 1,
           PredefinedRemarkId = j.PredefinedRemarkId,
           InValues           = j.InValues,
           InTextHEB          = NULLIF(LTRIM(RTRIM(j.InTextHEB)), N''),
           InTextENG          = NULLIF(LTRIM(RTRIM(j.InTextENG)), N''),
           InText             = NULLIF(LTRIM(RTRIM(j.InText)), N''),
           HasValues          = CASE WHEN JSON_QUERY(e.[value], N'$.Values') IS NOT NULL THEN 1 ELSE 0 END,
           IsObject           = CASE WHEN e.[type] = 5 THEN 1 ELSE 0 END
    INTO #In
    FROM OPENJSON(@Remarks) AS e
    OUTER APPLY OPENJSON(CASE WHEN e.[type] = 5 THEN e.[value] END)
         WITH (PredefinedRemarkId INT           N'$.PredefinedRemarkId',
               InValues           NVARCHAR(MAX) N'$.Values' AS JSON,
               InTextHEB          NVARCHAR(MAX) N'$.TextHEB',
               InTextENG          NVARCHAR(MAX) N'$.TextENG',
               InText             NVARCHAR(MAX) N'$.Text') AS j;

    IF EXISTS (SELECT 1 FROM #In WHERE IsObject = 0)
        THROW 51000, 'Every remark must be a JSON object.', 1;
    /* JSON paths are case-sensitive, so a misspelled key ("TextEng") would silently read as absent;
       the key names are compared in binary for the same reason */
    IF EXISTS (SELECT 1 FROM OPENJSON(@Remarks) AS e
               CROSS APPLY OPENJSON(e.[value]) AS k
               WHERE e.[type] = 5
                 AND k.[key] COLLATE Latin1_General_100_BIN2
                     NOT IN (N'PredefinedRemarkId', N'Values', N'TextHEB', N'TextENG', N'Text'))
        THROW 51000, 'Unknown key in a remark: only PredefinedRemarkId, Values, TextHEB, TextENG and Text are read.', 1;
    IF EXISTS (SELECT 1 FROM OPENJSON(@Remarks) AS e
               CROSS APPLY OPENJSON(e.[value]) AS k
               WHERE e.[type] = 5 AND k.[key] COLLATE Latin1_General_100_BIN2 = N'Values' AND k.[type] <> 4)
        THROW 51000, 'Values must be a JSON array.', 1;
    IF EXISTS (SELECT 1 FROM #In WHERE PredefinedRemarkId IS NULL AND InText IS NULL)
        THROW 51000, 'A remark needs PredefinedRemarkId or a non-empty Text.', 1;
    IF EXISTS (SELECT 1 FROM #In WHERE PredefinedRemarkId IS NOT NULL AND InText IS NOT NULL)
        THROW 51000, 'A remark is either a list remark (PredefinedRemarkId) or typed (Text), not both.', 1;
    IF EXISTS (SELECT 1 FROM #In WHERE PredefinedRemarkId IS NULL AND (InTextHEB IS NOT NULL OR InTextENG IS NOT NULL OR HasValues = 1))
        THROW 51000, 'TextHEB, TextENG and Values belong to a list remark; a typed remark has only Text.', 1;
    IF EXISTS (SELECT 1 FROM #In WHERE PredefinedRemarkId IS NOT NULL AND InTextHEB IS NULL AND InTextENG IS NOT NULL)
        THROW 51000, 'A customized remark needs TextHEB.', 1;
    IF EXISTS (SELECT 1 FROM #In WHERE InTextHEB IS NOT NULL AND HasValues = 1)
        THROW 51000, 'A customized remark carries its own texts; send Values or TextHEB, not both.', 1;

    IF EXISTS (SELECT 1 FROM #In AS i
               LEFT JOIN dbo.PredefinedRemarks AS p ON p.PredefinedRemarkId = i.PredefinedRemarkId
               WHERE i.PredefinedRemarkId IS NOT NULL
                 AND (   p.PredefinedRemarkId IS NULL
                      OR p.Scope <> @Scope
                      OR (    p.IsActive = 0
                          AND NOT EXISTS (SELECT 1 FROM dbo.CalibrationRemarks AS r
                                          WHERE r.OrderDetailsItemId = @OrderDetailsItemId
                                            AND r.Scope = @Scope
                                            AND (r.CalibrationCycleStartDate = @CalibrationCycleStartDate
                                                 OR (@CalibrationCycleStartDate IS NULL AND r.CalibrationCycleStartDate IS NULL))
                                            AND r.PredefinedRemarkId = p.PredefinedRemarkId
                                            AND r.IsDeleted = 0))))
        THROW 51000, 'Unknown PredefinedRemarkId, one from the other scope, or one that is no longer active.', 1;

    /* a list remark must come from the line's own sub-domain - when the line has one: on STAGE
       4,781 of 5,918 lines carry no SecondaryCategoryId (01/11), and those are not checked */
    IF EXISTS (SELECT 1 FROM #In AS i
               JOIN dbo.PredefinedRemarks AS p ON p.PredefinedRemarkId = i.PredefinedRemarkId
               WHERE EXISTS (SELECT 1 FROM dbo.OrderDetailsItems AS odi
                             JOIN dbo.OrderDetails AS od ON od.OrderDetailId = odi.OrderDetailId
                             WHERE odi.OrderDetailsItemId = @OrderDetailsItemId AND odi.IsDeleted = 0
                               AND od.SecondaryCategoryId IS NOT NULL
                               AND od.SecondaryCategoryId <> p.SecondaryCategoryId))
        THROW 51000, 'A list remark from another sub-domain than the order line''s.', 1;

    /* ---- values: sent, else the row's default ----------------------------------------------- */
    DROP TABLE IF EXISTS #Val;
    SELECT i.DisplayOrder,
           Idx   = CAST(d.[key] AS INT),
           Value = COALESCE(JSON_VALUE(i.InValues, CONCAT(N'$[', d.[key], N']')) COLLATE DATABASE_DEFAULT,
                            d.[value] COLLATE DATABASE_DEFAULT)
    INTO #Val
    FROM #In AS i
    JOIN dbo.PredefinedRemarks AS p ON p.PredefinedRemarkId = i.PredefinedRemarkId
    CROSS APPLY OPENJSON(p.DefaultValues) AS d
    WHERE i.InTextHEB IS NULL;

    IF EXISTS (SELECT 1 FROM #In AS i
               JOIN dbo.PredefinedRemarks AS p ON p.PredefinedRemarkId = i.PredefinedRemarkId
               WHERE i.HasValues = 1
                 AND (SELECT COUNT(*) FROM OPENJSON(i.InValues))
                     > ISNULL((SELECT COUNT(*) FROM OPENJSON(p.DefaultValues)), 0))
        THROW 51000, 'More Values than the remark has placeholders.', 1;
    IF EXISTS (SELECT 1 FROM #Val WHERE NULLIF(LTRIM(RTRIM(Value)), N'') IS NULL)
        THROW 51000, 'Every placeholder of a list remark needs a value.', 1;

    /* ---- the set as it will be stored --------------------------------------------------------- */
    DROP TABLE IF EXISTS #New;
    /* text columns collated explicitly: OPENJSON output and the table do not share a collation,
       and the change check below compares the two */
    SELECT i.DisplayOrder,
           i.PredefinedRemarkId,
           ValuesJson   = v.ValuesJson COLLATE DATABASE_DEFAULT,
           IsCustomized = CAST(CASE WHEN i.InTextHEB IS NOT NULL THEN 1 ELSE 0 END AS BIT),
           TextHEB      = CASE WHEN i.PredefinedRemarkId IS NULL THEN i.InText
                               WHEN i.InTextHEB IS NOT NULL      THEN i.InTextHEB
                               ELSE dbo.fnRenderRemarkTemplate(p.TextHEB, v.ValuesJson) END COLLATE DATABASE_DEFAULT,
           TextENG      = CASE WHEN i.PredefinedRemarkId IS NULL THEN i.InText
                               WHEN i.InTextHEB IS NOT NULL      THEN i.InTextENG
                               ELSE dbo.fnRenderRemarkTemplate(p.TextENG, v.ValuesJson) END COLLATE DATABASE_DEFAULT
    INTO #New
    FROM #In AS i
    LEFT JOIN dbo.PredefinedRemarks AS p ON p.PredefinedRemarkId = i.PredefinedRemarkId
    OUTER APPLY (SELECT ValuesJson = N'[' + STRING_AGG(CAST(N'"' + STRING_ESCAPE(x.Value, 'json') + N'"' AS NVARCHAR(MAX)), N',')
                                               WITHIN GROUP (ORDER BY x.Idx) + N']'
                 FROM #Val AS x WHERE x.DisplayOrder = i.DisplayOrder) AS v;

    BEGIN TRANSACTION;

    /* checked here, holding the line, so a save cannot slip in after dbo.SetCalibrationRemarksLock */
    IF EXISTS (SELECT 1 FROM dbo.OrderDetailsItems WITH (UPDLOCK, HOLDLOCK)
               WHERE OrderDetailsItemId = @OrderDetailsItemId AND RemarksLockedDate IS NOT NULL)
        THROW 51000, 'The report is signed: its remarks can no longer be changed.', 1;

    DROP TABLE IF EXISTS #Old;
    SELECT r.CalibrationRemarkId, r.DisplayOrder, r.PredefinedRemarkId,
           ValuesJson = r.ValuesJson COLLATE DATABASE_DEFAULT, r.IsCustomized,
           TextHEB = r.TextHEB COLLATE DATABASE_DEFAULT, TextENG = r.TextENG COLLATE DATABASE_DEFAULT
    INTO #Old
    FROM dbo.CalibrationRemarks AS r WITH (UPDLOCK, HOLDLOCK)
    WHERE r.OrderDetailsItemId = @OrderDetailsItemId
      AND r.Scope = @Scope
      AND (r.CalibrationCycleStartDate = @CalibrationCycleStartDate
           OR (@CalibrationCycleStartDate IS NULL AND r.CalibrationCycleStartDate IS NULL))
      AND r.IsDeleted = 0;

    /* compared in binary: the database collation ignores case and accents, and "sensor" -> "Sensor"
       is a change the calibrator expects to be saved */
    DECLARE @NoChange BIT =
        CASE WHEN (SELECT COUNT(*) FROM #Old) = (SELECT COUNT(*) FROM #New)
              AND NOT EXISTS (SELECT DisplayOrder, PredefinedRemarkId, IsCustomized,
                                     ValuesJson COLLATE Latin1_General_100_BIN2,
                                     TextHEB    COLLATE Latin1_General_100_BIN2,
                                     TextENG    COLLATE Latin1_General_100_BIN2
                              FROM #New
                              EXCEPT
                              SELECT DisplayOrder, PredefinedRemarkId, IsCustomized,
                                     ValuesJson COLLATE Latin1_General_100_BIN2,
                                     TextHEB    COLLATE Latin1_General_100_BIN2,
                                     TextENG    COLLATE Latin1_General_100_BIN2
                              FROM #Old)
             THEN 1 ELSE 0 END;

    IF @Apply = 1 AND @NoChange = 0
    BEGIN
        UPDATE r
        SET IsDeleted = 1, UpdatedDate = GETDATE(), UpdateUserID = @UserId
        FROM dbo.CalibrationRemarks AS r
        JOIN #Old AS o ON o.CalibrationRemarkId = r.CalibrationRemarkId;

        INSERT dbo.CalibrationRemarks
              (OrderDetailsItemId, Scope, CalibrationCycleStartDate, DisplayOrder, PredefinedRemarkId,
               ValuesJson, TextHEB, TextENG, IsCustomized, CreatedByUserId)
        SELECT @OrderDetailsItemId, @Scope, @CalibrationCycleStartDate, n.DisplayOrder, n.PredefinedRemarkId,
               n.ValuesJson, n.TextHEB, n.TextENG, n.IsCustomized, @UserId
        FROM #New AS n;
    END;

    COMMIT TRANSACTION;

    SELECT Outcome = CASE WHEN @NoChange = 1 THEN N'NoChange'
                          WHEN @Apply = 1    THEN N'Saved'
                          ELSE N'WouldSave' END,
           n.DisplayOrder, n.PredefinedRemarkId, n.ValuesJson, n.IsCustomized, n.TextHEB, n.TextENG
    FROM #New AS n
    ORDER BY n.DisplayOrder;
END;
GO
