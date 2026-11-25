/*
    dbo.LoggerOwnershipTransfer                                                         MBA-1056
    ---------------------------------------------------------------------------------------------
    One row each time a calibrator's save takes a logger away from another calibrator.

    A logger has one owner at a time and the last save wins (decision on MBA-1056, 25.11.2026):
    one person uses a logger at a time, and the logger's settings - interval, protocol, COM port -
    are stored once on its MeasurementDevices row anyway. The owner is
    SensorToLoggerRelation.UpdateUserID, and a save overwrites it. Without this table the previous
    owner simply lost the logger from page 2 and nothing said why.

    Written only by dbo.AssignMeasurmentDevicesToCalibrator, one row per previous owner, in the
    same transaction as the take-over. Read by dbo.GetLoggersTakenFromCalibrator, which shows the
    previous owner "21-337 was moved to <name> on <date>" until they dismiss it
    (dbo.DismissLoggerOwnershipTransfers) or take the logger back (the save closes it then).

    Relations whose UpdateUserID was NULL (created before MBA-902 recorded owners) belong to nobody,
    so taking one over writes no row here.
*/
IF OBJECT_ID('dbo.LoggerOwnershipTransfer', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.LoggerOwnershipTransfer
    (
        LoggerOwnershipTransferId INT IDENTITY(1,1) NOT NULL,
        LoggerMeasurementDeviceId INT          NOT NULL,
        FromUserId                INT          NOT NULL,
        ToUserId                  INT          NOT NULL,
        TransferredDate           DATETIME2(3) NOT NULL
            CONSTRAINT DF_LoggerOwnershipTransfer_TransferredDate DEFAULT (SYSUTCDATETIME()),
        DismissedDate             DATETIME2(3) NULL,

        CONSTRAINT PK_LoggerOwnershipTransfer PRIMARY KEY CLUSTERED (LoggerOwnershipTransferId),
        CONSTRAINT FK_LoggerOwnershipTransfer_Logger
            FOREIGN KEY (LoggerMeasurementDeviceId) REFERENCES dbo.MeasurementDevices (ID),
        CONSTRAINT FK_LoggerOwnershipTransfer_FromUser
            FOREIGN KEY (FromUserId) REFERENCES dbo.Users (ID),
        CONSTRAINT FK_LoggerOwnershipTransfer_ToUser
            FOREIGN KEY (ToUserId) REFERENCES dbo.Users (ID),
        CONSTRAINT CK_LoggerOwnershipTransfer_DifferentUsers CHECK (FromUserId <> ToUserId)
    );

    /* "what was taken from me that I have not dismissed" - the only question page 2 asks */
    CREATE NONCLUSTERED INDEX IX_LoggerOwnershipTransfer_From_Open
        ON dbo.LoggerOwnershipTransfer (FromUserId, LoggerMeasurementDeviceId, TransferredDate DESC)
        INCLUDE (ToUserId)
        WHERE DismissedDate IS NULL;
END
GO
