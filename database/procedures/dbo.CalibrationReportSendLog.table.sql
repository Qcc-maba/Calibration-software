/*
    dbo.CalibrationReportSendLog                                                       MBA-337
    ---------------------------------------------------------------------------------------------
    Every attempt to e-mail a calibration report to a customer.

    Nothing recorded this before: there was no way to tell a customer whether their report had gone
    out, no way to show "not sent yet" on a screen, and no way to re-send safely because nobody knew
    what had already been sent to whom.

    Append-only, and it records *attempts*, not successes — a failed send is exactly the row you
    want to find when a customer says the report never arrived. `Status` separates the two.

    One row per recipient per attempt: sending the same report to two contacts is two rows, and
    re-sending later adds more. The history is the point.
*/
IF OBJECT_ID('dbo.CalibrationReportSendLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CalibrationReportSendLog
    (
        CalibrationReportSendLogId BIGINT        IDENTITY(1, 1) NOT NULL,

        /* what was sent */
        OrderDetailsItemId  INT            NOT NULL,
        MbaReportNumber     NVARCHAR(100)  NULL,
        /* S3 key of the exact file that went out, so a re-generated report can be told apart */
        DocumentPath        NVARCHAR(400)  NULL,
        /* the report carried the "Draft" watermark, i.e. it was sent unsigned (MBA-362) */
        IsDraft             BIT            NOT NULL CONSTRAINT DF_CalibrationReportSendLog_IsDraft DEFAULT (0),

        /* to whom */
        SentToEmail         NVARCHAR(100)  NOT NULL,
        CustomerContactId   INT            NULL,

        /* by whom - the calibrator who pressed Send */
        SentByUserId        INT            NULL,
        SentByEmail         NVARCHAR(100)  NULL,

        /* outcome */
        Status              NVARCHAR(20)   NOT NULL,   /* 'Sent' | 'Failed' */
        FailureReason       NVARCHAR(1000) NULL,

        SentAt              DATETIME2(3)   NOT NULL CONSTRAINT DF_CalibrationReportSendLog_SentAt DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_CalibrationReportSendLog PRIMARY KEY CLUSTERED (CalibrationReportSendLogId),
        CONSTRAINT CK_CalibrationReportSendLog_Status CHECK (Status IN (N'Sent', N'Failed'))
    );

    /* "has this device's report been sent, and when" - the question every screen asks */
    CREATE NONCLUSTERED INDEX IX_CalibrationReportSendLog_Item_SentAt
        ON dbo.CalibrationReportSendLog (OrderDetailsItemId, SentAt DESC)
        INCLUDE (Status, SentToEmail, MbaReportNumber, IsDraft);
END
GO
