/*
    dbo.PriorityStatusWriteMode                                                        MBA-911
    ---------------------------------------------------------------------------------------------
    The switch for reporting the Calibrator app's calibration steps to Priority. One row.

        Off        : dbo.RecordPriorityStatusEvent records nothing (the kill switch).
        ReportOnly : events are checked and recorded in dbo.PriorityStatusOutbox, and are NEVER sent.
                     This is the dry run the ticket asks for: a week of it can be compared with what
                     Priority actually recorded before anything is written to the ERP.

    There is no 'Send' value yet, ON PURPOSE. The CHECK constraint below makes it impossible to
    switch sending on before the sender (phase 3) exists and has been tested against Priority's test
    company s190225. Phase 3 widens the constraint in the same change that adds the sender.

    Changing the mode is a deliberate, logged act: set UpdatedBy and Reason.
        UPDATE dbo.PriorityStatusWriteMode
        SET Mode = 'Off', UpdatedAt = SYSUTCDATETIME(), UpdatedBy = N'<who>', Reason = N'<why>'
        WHERE Id = 1;
*/
IF OBJECT_ID('dbo.PriorityStatusWriteMode', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PriorityStatusWriteMode
    (
        Id         TINYINT        NOT NULL
            CONSTRAINT DF_PriorityStatusWriteMode_Id DEFAULT (1),
        Mode       VARCHAR(12)    NOT NULL,
        UpdatedAt  DATETIME2(3)   NOT NULL
            CONSTRAINT DF_PriorityStatusWriteMode_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedBy  NVARCHAR(100)  NULL,
        Reason     NVARCHAR(400)  NULL,
        CONSTRAINT PK_PriorityStatusWriteMode PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT CK_PriorityStatusWriteMode_SingleRow CHECK (Id = 1),
        CONSTRAINT CK_PriorityStatusWriteMode_Mode CHECK (Mode IN ('Off', 'ReportOnly'))
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.PriorityStatusWriteMode)
    INSERT INTO dbo.PriorityStatusWriteMode (Id, Mode, UpdatedBy, Reason)
    VALUES (1, 'ReportOnly', N'MBA-911', N'Initial state: record and check, never send.');
GO
