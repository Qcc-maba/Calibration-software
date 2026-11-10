/*
    dbo.PriorityCalibrationStatusLog                                                   MBA-911
    ---------------------------------------------------------------------------------------------
    Local mirror of Priority's calibration status log (amaba.dbo.MBA_CALIBSTATSLOG) for the
    calibrations this system holds: every step each one went through - received, calibration
    opened, report generated, first and second signature, packed, sent - with its date and who
    did it. Filled by dbo.RefreshPriorityCalibrationStatus; read through
    dbo.vwOrderDetailsItemsPriorityStatus.

    KEYED ON (Doc, Kline), NOT ON OUR ROW
    -------------------------------------
    Doc is Priority's calibration document, one per device per visit to the lab
    (= OrderDetailsItems.Doc). Kline is the step number within it. Measured on Priority
    2026-11-09 over DOC > 2,400,000: 746,015 rows, 746,015 distinct (DOC, KLINE), and in no case
    does a higher KLINE carry a lower insertion id - KLINE is the true order of the steps.

    It is deliberately NOT keyed on OrderDetailsItemId: 134 Docs sit on 500 OrderDetailsItems
    rows (same device, different order line - PROD copy of 2026-10-21). A status stored per row
    could show two values for one calibration; stored per Doc it cannot.

    WHY NOT stg_Orders.CurrentCalibrationStatus
    -------------------------------------------
    The order view (amaba.dbo.vwGetOrders_WorkPlan_Full_new) already carries a "current status",
    but it picks the latest row by CDATE. A CD row's CDATE is the calibration DATE at midnight,
    not the time it was written, so for 1,799 of 33,958 recent Docs (5.3%) the view's "current"
    status is not the latest step. It also only covers documents opened in the last 25 days.
    Reading the log directly, ordered by KLINE, avoids both.

    Priority owns this data. Rows are never deleted here when they disappear upstream (see the
    "carry a flag, never delete" rule, session1 decision 17); a full refresh reports them instead.
*/
/*
    QUOTED_IDENTIFIER / ANSI_NULLS must be ON: set explicitly so the object does not depend on the client that deploys it (sqlcmd defaults
    QUOTED_IDENTIFIER to OFF). Same convention as dbo.CalibrationReportFile.table.sql.
*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.PriorityCalibrationStatusLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PriorityCalibrationStatusLog
    (
        Doc                 INT            NOT NULL,  /* MBA_CALIBSTATSLOG.DOC = OrderDetailsItems.Doc  */
        Kline               INT            NOT NULL,  /* step number within the Doc, 1, 2, 3 ...        */
        StatusCode          CHAR(2)        NOT NULL,  /* -> dbo.PriorityCalibrationStatusCodes          */
        StatusDate          DATETIME2(0)   NULL,      /* CDATE. For CD this is the calibration date at
                                                         midnight, not the time of the step             */
        LoadedAt            DATETIME2(0)   NULL,      /* UDATE: when Priority stored the row. Also the
                                                         refresh watermark                              */
        StatusByUserName    NVARCHAR(40)   NULL,      /* CALIB_USERNAME, via tabula_hebconvert          */
        UpdateReportNumber  NVARCHAR(16)   NULL,      /* MBA_UPDTRPORTNUM, empty for a normal report    */
        FetchedAt           DATETIME2(3)   NOT NULL
            CONSTRAINT DF_PriorityCalibrationStatusLog_FetchedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_PriorityCalibrationStatusLog PRIMARY KEY CLUSTERED (Doc, Kline)
    );

    /* The incremental refresh asks for MAX(LoadedAt). */
    CREATE NONCLUSTERED INDEX IX_PriorityCalibrationStatusLog_LoadedAt
        ON dbo.PriorityCalibrationStatusLog (LoadedAt);
END
GO
