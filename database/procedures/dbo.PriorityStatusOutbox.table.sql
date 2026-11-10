/*
    dbo.PriorityStatusOutbox                                                           MBA-911
    ---------------------------------------------------------------------------------------------
    Every calibration step the Calibrator app reports for Priority - calibration opened, report
    generated, first and second signature, rejection, on hold / resumed, update report - one row
    per event, written ONLY by dbo.RecordPriorityStatusEvent, which checks it first.

    Priority's calibration log is the customer-facing record, and a duplicated "sent" or
    "second signature" is a real support call. So the rules live here, in one place the app cannot
    skip:

    * KEYED BY Doc, NOT BY OUR ROW. Doc is Priority's calibration document. 134 Docs sit on 500
      OrderDetailsItems rows (PROD copy, 2026-10-21), so an event keyed by OrderDetailsItemId could be
      reported twice for one calibration. OrderDetailsItemId is kept only to show where it came from.

    * ONE ROW PER (Doc, StatusCode, EventKey). EventKey is the app's own stable id for the action
      (for example 'report:<CalibrationReportFileId>', 'sign1:<id>'), the same on a retry. The filtered
      unique index turns a retry or a double click into a no-op. A second report generation is a
      different action with a different key, and Priority does expect a second GR for it.

    * REFUSED EVENTS ARE KEPT, with the reason, so "why did Priority not get this" has an answer.
      They are outside the unique index, so the same key can be accepted once its rule is met.

    State
        ReportOnly : accepted while dbo.PriorityStatusWriteMode was 'ReportOnly'. NEVER sent, even
                     after sending is switched on: the dry-run log stays a dry-run log.
        Refused    : failed a rule; Reason says which.
    Phase 3 adds the sending states (Pending, Sent, Loaded, Rejected). A row Priority rejects is never
    retried automatically: a rejection means Priority refused the content, so a retry fails again, and
    a row that was in fact loaded would become a duplicate. A person decides.
*/
/*
    QUOTED_IDENTIFIER / ANSI_NULLS must be ON: this table has a filtered unique index (UX_PriorityStatusOutbox_Event), which SQL Server
    refuses to create under the OFF setting sqlcmd defaults to. Every procedure that WRITES here needs the
    same two lines: a procedure keeps the SET options it was created with, and one created under OFF fails
    every INSERT with error 1934. Keep them at the top of this file and of dbo.RecordPriorityStatusEvent.sql.
*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.PriorityStatusOutbox', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PriorityStatusOutbox
    (
        OutboxId            INT            IDENTITY(1, 1) NOT NULL,
        Doc                 INT            NOT NULL,  /* Priority calibration document              */
        StatusCode          CHAR(2)        NOT NULL,  /* -> dbo.PriorityCalibrationStatusCodes      */
        EventKey            NVARCHAR(100)  NOT NULL,  /* app's stable id of the action               */
        State               VARCHAR(12)    NOT NULL,
        Reason              VARCHAR(40)    NULL,      /* rule that refused it, for State = Refused   */
        OrderDetailsItemId  INT            NOT NULL,  /* the row the app acted on                    */
        MbaReportNumber     NVARCHAR(100)  NULL,      /* MBANUM, as Priority's load table needs it   */
        UpdateReportNumber  NVARCHAR(16)   NULL,      /* MBA_UPDTRPORTNUM; empty for a normal report */
        UserId              INT            NULL,      /* dbo.Users.ID of who did it                  */
        EventAt             DATETIME2(0)   NOT NULL,  /* when it happened in the app: LOCAL time,
                                                         like the app's other dates and Priority's   */
        RecordedAt          DATETIME2(3)   NOT NULL   /* when it was recorded: UTC bookkeeping      */
            CONSTRAINT DF_PriorityStatusOutbox_RecordedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_PriorityStatusOutbox PRIMARY KEY CLUSTERED (OutboxId),
        CONSTRAINT CK_PriorityStatusOutbox_State CHECK (State IN ('ReportOnly', 'Refused'))
    );

    /* The idempotency rule. Refused rows are outside it on purpose. */
    CREATE UNIQUE NONCLUSTERED INDEX UX_PriorityStatusOutbox_Event
        ON dbo.PriorityStatusOutbox (Doc, StatusCode, EventKey)
        WHERE State <> 'Refused';

    /* The rule checks read a Doc's accepted history in order. */
    CREATE NONCLUSTERED INDEX IX_PriorityStatusOutbox_Doc
        ON dbo.PriorityStatusOutbox (Doc, OutboxId)
        INCLUDE (StatusCode, State);
END
GO
