/*
    dbo.OrderDetailsItems.ShouldShowPercentOfSpec                                         MBA-1004
    ---------------------------------------------------------------------------------------------
    The Report screen's "% of Spec" checkbox: whether the report's results table carries the
    "% of Spec" column. The first calibrator chooses it; the second calibrator must see the report
    exactly as the first one signed it (Nofar, MBA-1004, 16/11).

    Why a column: until now the choice lived only in the browser's form state and always started
    unchecked, so the second calibrator - whose report options are read-only - regenerated and signed
    the PDF without the column the first calibrator had chosen.

    NOT NULL DEFAULT 0 = unchecked, the ticket's default, so every existing line keeps its report
    unchanged (6,186 STAGE lines, 16/11). The app writes it through dbo.SetReportDisplayOptions and
    reads it back from dbo.GetOrderDetailsDevices. Replayable.
*/
IF COL_LENGTH('dbo.OrderDetailsItems', 'ShouldShowPercentOfSpec') IS NULL
    ALTER TABLE dbo.OrderDetailsItems
        ADD ShouldShowPercentOfSpec BIT NOT NULL
            CONSTRAINT DF_OrderDetailsItems_ShouldShowPercentOfSpec DEFAULT (0);
GO
