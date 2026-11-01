/*
    dbo.CalibrationRemarks                                                                 MBA-848
    ---------------------------------------------------------------------------------------------
    The remarks a calibrator put on one report: one row per remark, in the order they print.
    Written only by dbo.SaveCalibrationRemarks, read by dbo.GetCalibrationRemarks.

    What a remark belongs to
    ------------------------
    A report is one order line, dbo.OrderDetailsItems.OrderDetailsItemId (the wizard's
    OrderWorkPlanId follows from it through dbo.OrderDetails, so it is not stored twice).
      Scope 'Report' - the whole report; CalibrationCycleStartDate is NULL.
      Scope 'Cycle'  - one chamber cycle. dbo.CalibrationCycles has no id column: its key is
                       (OrderDetailsItemId, CalibrationCycleStartDate), and the foreign key below uses
                       it, as dbo.MeasurmentPointsToCalibrationCycles does.

    Changing a cycle's start time does not update its row: the app's updateCalibrationCycle inserts a
    new cycle row, moves the measurement points to the new start date and soft-deletes the old row.
    The same transaction must move this table's rows too, or the remarks stay on the deleted cycle
    and stop showing.

    There is no foreign key to dbo.OrderDetailsItems: its primary key is
    (OrderDetailId, OrderDetailsItemId), and on STAGE OrderDetailsItemId 112 sits on two order lines,
    so nothing unique can be referenced. dbo.SaveCalibrationRemarks checks the line exists instead.

    What is stored
    --------------
    PredefinedRemarkId  the list row it came from; NULL for a remark the calibrator typed.
    ValuesJson          the values filled into the list row's {1}, {2}, ... (JSON array).
    TextHEB / TextENG   the final text, rendered when the remark was saved. The report prints these,
                        so a later change to the list never changes a report.
    IsCustomized        1 = the calibrator changed the wording, not only the values; the texts are
                        theirs, and TextENG may be NULL when they gave no English (Nofar, 01/11).
    A typed remark is printed as typed in either language: the same text in both columns.

    Rows are never updated. A save soft-deletes the set it replaces and inserts the new one, so the
    edit history stays.
*/
IF OBJECT_ID('dbo.CalibrationRemarks', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CalibrationRemarks
    (
        CalibrationRemarkId       INT IDENTITY(1,1) NOT NULL,
        OrderDetailsItemId        INT               NOT NULL,
        Scope                     NVARCHAR(10)      NOT NULL,
        CalibrationCycleStartDate DATETIME2(0)      NULL,
        DisplayOrder              INT               NOT NULL,
        PredefinedRemarkId        INT               NULL,
        ValuesJson                NVARCHAR(MAX)     NULL,
        TextHEB                   NVARCHAR(MAX)     NOT NULL,
        TextENG                   NVARCHAR(MAX)     NULL,
        IsCustomized              BIT               NOT NULL
            CONSTRAINT DF_CalibrationRemarks_IsCustomized DEFAULT (0),
        IsDeleted                 BIT               NOT NULL
            CONSTRAINT DF_CalibrationRemarks_IsDeleted DEFAULT (0),
        CreatedDate               DATETIME2(0)      NOT NULL
            CONSTRAINT DF_CalibrationRemarks_CreatedDate DEFAULT (GETDATE()),
        CreatedByUserId           INT               NULL,
        UpdatedDate               DATETIME2(0)      NULL,
        UpdateUserID              INT               NULL,

        CONSTRAINT PK_CalibrationRemarks PRIMARY KEY CLUSTERED (CalibrationRemarkId),
        CONSTRAINT FK_CalibrationRemarks_CalibrationCycles
            FOREIGN KEY (OrderDetailsItemId, CalibrationCycleStartDate)
            REFERENCES dbo.CalibrationCycles (OrderDetailsItemId, CalibrationCycleStartDate),
        CONSTRAINT FK_CalibrationRemarks_PredefinedRemarks
            FOREIGN KEY (PredefinedRemarkId) REFERENCES dbo.PredefinedRemarks (PredefinedRemarkId),
        CONSTRAINT CK_CalibrationRemarks_Scope CHECK
            (   (Scope = N'Report' AND CalibrationCycleStartDate IS NULL)
             OR (Scope = N'Cycle'  AND CalibrationCycleStartDate IS NOT NULL)),
        CONSTRAINT CK_CalibrationRemarks_ValuesJson CHECK (ValuesJson IS NULL OR ISJSON(ValuesJson) = 1)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CalibrationRemarks_Item'
                                         AND object_id = OBJECT_ID('dbo.CalibrationRemarks'))
CREATE NONCLUSTERED INDEX IX_CalibrationRemarks_Item
    ON dbo.CalibrationRemarks (OrderDetailsItemId, Scope, CalibrationCycleStartDate, DisplayOrder)
    WHERE IsDeleted = 0;
GO
