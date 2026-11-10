/*
    dbo.PriorityCalibrationStatusFetch                                                 MBA-911
    ---------------------------------------------------------------------------------------------
    One row per Doc whose WHOLE Priority log dbo.RefreshPriorityCalibrationStatus has fetched at
    least once. It is how the refresh tells "never fetched" from "fetched, and Priority has nothing
    for it yet".

    Without it, "never fetched" was inferred from "has no rows in dbo.PriorityCalibrationStatusLog",
    so a Doc whose Priority log is still empty was queued for a whole-log fetch on every hourly run,
    forever, each one costing part of a linked-server round-trip (PR #50 review). Once a Doc is
    marked, its later steps arrive through the incremental pull by UDATE, which covers our whole Doc
    range.

    A full refresh (@FullRefresh = 1) ignores the marker and refetches everything.
*/
/*
    QUOTED_IDENTIFIER / ANSI_NULLS must be ON: set explicitly so the object does not depend on the
    client that deploys it (sqlcmd defaults QUOTED_IDENTIFIER to OFF). Same convention as
    dbo.CalibrationReportFile.table.sql.
*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.PriorityCalibrationStatusFetch', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PriorityCalibrationStatusFetch
    (
        Doc               INT           NOT NULL,
        LastWholeFetchAt  DATETIME2(3)  NOT NULL
            CONSTRAINT DF_PriorityCalibrationStatusFetch_LastWholeFetchAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_PriorityCalibrationStatusFetch PRIMARY KEY CLUSTERED (Doc)
    );
END
GO
