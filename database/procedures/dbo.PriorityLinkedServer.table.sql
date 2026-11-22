/*
    dbo.PriorityLinkedServer                                                           MBA-1028
    ---------------------------------------------------------------------------------------------
    Which linked server this database reads Priority through. One row.

    STAGE (Calibrator) and PROD (CalibratorProd) live on the same AWS instance and are deployed
    from the same procedure files, so the files cannot name the server: until MBA-1028, 20
    procedures on STAGE named [31.168.173.93] - live Priority - and STAGE read the production ERP.
    The name now comes from this row, resolved by dbo.GetPriorityLinkedServer:

        Calibrator      PRIORITY_TEST   -> priority-test\PRI, port 14330 on the office address
        CalibratorProd  31.168.173.93   -> maba-priority\PRI (live Priority)

    NO SEED ROW, ON PURPOSE. A database with no row cannot read Priority at all: every reader
    throws 51020 rather than guessing. A default would have to be one of the two servers, and the
    wrong default is either a STAGE that quietly reads production or a PROD that reads a copy.

    Set it only through dbo.SetPriorityLinkedServer, which also re-points the prio.* synonyms the
    four-part-name readers use, and refuses a server that is wrong for the database
    (dbo.fnPriorityLinkRefusal).
*/
/*
    QUOTED_IDENTIFIER / ANSI_NULLS must be ON: set explicitly so the object does not depend on the
    client that deploys it (sqlcmd defaults QUOTED_IDENTIFIER to OFF). Same convention as
    dbo.PriorityStatusWriteMode.table.sql.
*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.PriorityLinkedServer', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PriorityLinkedServer
    (
        Id           TINYINT        NOT NULL
            CONSTRAINT DF_PriorityLinkedServer_Id DEFAULT (1),
        LinkedServer SYSNAME        NOT NULL,
        UpdatedAt    DATETIME2(3)   NOT NULL
            CONSTRAINT DF_PriorityLinkedServer_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedBy    NVARCHAR(100)  NULL,
        Reason       NVARCHAR(400)  NULL,
        CONSTRAINT PK_PriorityLinkedServer PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT CK_PriorityLinkedServer_SingleRow CHECK (Id = 1)
    );
END
GO
