/*
    dbo.CrmDeviceDescription                                                           MBA-666 / MBA-999
    ---------------------------------------------------------------------------------------------
    Cache of the device descriptions Priority keeps in MBA_DOCLOAD.SERNDES, un-reversed from visual
    order. Filled and rebuilt only by dbo.RefreshDeviceDescriptions (SQL Agent job "Refresh device
    descriptions", database/jobs/Setup-SqlAgentJobs.sql); nothing else writes here.

    The table existed on both servers without a file in git. It was written down on 2026-10-25 for
    MBA-999, from the STAGE definition, after the 31/08 production package was found to have created
    it with columns and a primary key only - no RefreshedAt default and neither lookup index. The
    refresh passes RefreshedAt itself, so nothing broke; the indexes are what the description lookups
    read. PROD got the missing pieces from database/deploy-prod/10-MBA-999-cache-and-cycle-constraints.sql.

    NeedsReview marks a description whose un-reversal is uncertain (see 06-hotfix-MBA-666-unreverse.sql).
    Devices / Parts count how many serial numbers and part numbers carry the description.
*/
IF OBJECT_ID('dbo.CrmDeviceDescription', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CrmDeviceDescription
    (
        CrmDeviceDescriptionId INT IDENTITY(1,1) NOT NULL,
        DescriptionRaw         NVARCHAR(200)     NOT NULL,
        Description            NVARCHAR(200)     NOT NULL,
        NeedsReview            BIT               NOT NULL,
        Devices                INT               NOT NULL,
        Parts                  INT               NOT NULL,
        RefreshedAt            DATETIME2(7)      NOT NULL
            CONSTRAINT DF_CrmDeviceDescription_RefreshedAt DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_CrmDeviceDescription PRIMARY KEY CLUSTERED (CrmDeviceDescriptionId)
    );

    /* the refresh matches on the raw Priority text; screens look up the readable one */
    CREATE NONCLUSTERED INDEX IX_CrmDeviceDescription_Raw  ON dbo.CrmDeviceDescription (DescriptionRaw);
    CREATE NONCLUSTERED INDEX IX_CrmDeviceDescription_Desc ON dbo.CrmDeviceDescription (Description);
END
GO
