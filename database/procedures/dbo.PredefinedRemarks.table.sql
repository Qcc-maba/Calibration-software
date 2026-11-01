/*
    dbo.PredefinedRemarks                                                                  MBA-848
    ---------------------------------------------------------------------------------------------
    The list of ready-made remarks a calibrator picks from on the report screen (Report remarks) and
    in a chamber cycle's remarks dialog (Cycle remarks). Loaded from Nofar's Excel (one worksheet per
    sub-domain) by database/data/Seed-PredefinedRemarks.sql; later changes are made directly in the
    database by a privileged user - there is no admin screen (Nofar, MBA-848, 01/11).

    Why not dbo.Statuses, where the Calibration Process descriptions live: it has no display order
    (GetStatusByCategory returns rows unordered), no active flag, and caps text at 255 characters.

    Sub-domain = SecondaryCategoryId (dbo.SecondaryCategories: רגשים, תאים, משאיות קירור, ...), so the
    screen filters by the stable id the order line already carries, never by a translated name.
    Scope says which picker shows the row: 'Report' or 'Cycle' (chamber cycles only).

    Editable values
    ---------------
    TextHEB and TextENG mark each editable value with a numbered placeholder, {1}, {2}, ... Numbered,
    not positional, because Hebrew and English do not always order the values the same way.
    DefaultValues is a JSON array of strings, one per placeholder, in placeholder order: "" means the
    calibrator must type it. dbo.SaveCalibrationRemarks fills both languages from the same values, so
    the English follows the Hebrew without any text matching.

    A row in use is never rewritten. To change a remark, set IsActive = 0 and add a new row: each
    remark on a report keeps its own rendered text, but the id is how the dialog re-opens it for
    editing, and a rewritten template would re-open a different sentence.
*/
IF OBJECT_ID('dbo.PredefinedRemarks', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PredefinedRemarks
    (
        PredefinedRemarkId  INT IDENTITY(1,1) NOT NULL,
        SecondaryCategoryId INT               NOT NULL,
        Scope               NVARCHAR(10)      NOT NULL,
        TextHEB             NVARCHAR(1000)    NOT NULL,
        TextENG             NVARCHAR(1000)    NOT NULL,
        DefaultValues       NVARCHAR(1000)    NULL,
        DisplayOrder        INT               NOT NULL,
        IsActive            BIT               NOT NULL
            CONSTRAINT DF_PredefinedRemarks_IsActive DEFAULT (1),
        CreatedDate         DATETIME2(0)      NOT NULL
            CONSTRAINT DF_PredefinedRemarks_CreatedDate DEFAULT (GETDATE()),
        CreatedByUserId     INT               NULL,
        UpdatedDate         DATETIME2(0)      NULL,
        UpdateUserID        INT               NULL,

        CONSTRAINT PK_PredefinedRemarks PRIMARY KEY CLUSTERED (PredefinedRemarkId),
        CONSTRAINT FK_PredefinedRemarks_SecondaryCategories
            FOREIGN KEY (SecondaryCategoryId) REFERENCES dbo.SecondaryCategories (ID),
        CONSTRAINT CK_PredefinedRemarks_Scope CHECK (Scope IN (N'Report', N'Cycle')),
        CONSTRAINT CK_PredefinedRemarks_DefaultValues
            CHECK (DefaultValues IS NULL OR ISJSON(DefaultValues) = 1)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PredefinedRemarks_Picker'
                                         AND object_id = OBJECT_ID('dbo.PredefinedRemarks'))
CREATE NONCLUSTERED INDEX IX_PredefinedRemarks_Picker
    ON dbo.PredefinedRemarks (SecondaryCategoryId, Scope, IsActive, DisplayOrder);
GO
