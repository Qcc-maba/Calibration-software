/*
    dbo.CustomerDevices                                                                 MBA-996
    ---------------------------------------------------------------------------------------------
    One row per physical device a customer owns. Until MBA-996 the portal had no device entity:
    a "device" was a group of order lines with the same serial string, and its id was the newest
    OrderDetailsItemId, so it changed with every calibration. A device the customer typed in had
    nowhere to live. Design: DBA/schema-updates.md section 2.

    Two kinds of row:
      SERN IS NOT NULL  registered in Priority (SERNUMBERS.SERN). Kept by
                        dbo.RefreshCustomerDevicesFromPriority. Its Priority-owned columns change
                        only in Priority - dbo.trCustomerDevices_PriorityOwned enforces it.
      SERN IS NULL      typed in by the customer through the portal, not registered yet. When MABA
                        registers it, the refresh claims the row (sets SERN) instead of adding a
                        second one, so the customer's id, site and contact survive.

    Visits are not stored here. dbo.vwCustomerDevices joins OrderDetailsItems by SERN at read time.

    COLUMN OWNERSHIP - every column has exactly one writer
    -------------------------------------------------------
      Priority (the refresh only, on registered rows):
        SERN, CustomerId, SerialNumber, Model, OrdersDeviceManufacturer, DevicePart,
        DeviceTypeName, DeviceDescription, CalibrationIntervalMonths, IsInactiveInSource,
        SourceUpdatedAt, RefreshedAt
      The portal (dbo.AssignCustomerDevicesData):
        CustomerSiteId, CustomerContactId, DeviceLocation, ReportLanguage, categories,
        specification and units, IsDeleted, and everything on a row with SERN IS NULL
      Never written for a registered row: OrdersProductTypeId and NextCalibrationDate. The first is
        a calibration SERVICE (OrdersProductTypes holds 680 service parts such as "... - in-house
        accredited calibration"); a device's own part is DevicePart, and the two never coincide
        (0 of 5,617 STAGE order lines with a SERN, 2026-11-10). The next calibration date of a
        registered device is its latest visit's.

    WHAT CHANGED FROM THE ORIGINAL TABLE
    ------------------------------------
    The original (STAGE, 2026-11-10) had PK (CustomerId, CustomerDeviceID), 8 FKs and 4 defaults,
    and no row on either server. This file replaces it, and only while it is EMPTY:
      - PK on CustomerDeviceID alone: other tables reference it, the portal routes on it;
      - SERN, unique where present;
      - SerialKey, the one comparison form of SerialNumber;
      - one typed device per (customer, serial): unique (CustomerId, SerialKey) on typed live rows.
        Not on registered rows - Priority itself holds double registrations we cannot fix;
      - DevicePart, DeviceTypeName, DeviceDescription, IsInactiveInSource, SourceUpdatedAt,
        RefreshedAt, NeedsReview, NeedsReviewReason;
      - FKs to CustomerSites and CustomerContacts, on (CustomerId, ...) because their keys are
        composite: a device's site and contact must belong to its own customer. Every FK is NO ACTION: maba2000's cascading
        FKs let one delete wipe a whole history (DB-SCHEMA-REFERENCE.md section 4).
    Lengths are the original's. Priority's SERNUM is VARCHAR(30), MODEL 30, SERNDES 48, MNFDES 32,
    PARTDES 59, so every Priority value fits.

    Safe to re-run: once SERN exists the replacement step is skipped, and the indexes below are
    each guarded.
*/
/*
    QUOTED_IDENTIFIER / ANSI_NULLS must be ON: set explicitly so the object does not depend on the client that deploys it (sqlcmd defaults
    QUOTED_IDENTIFIER to OFF). Same convention as dbo.CalibrationReportFile.table.sql. A filtered
    index and an indexed computed column also need them ON in every session that writes the table.
*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

/* ---- 1. Replace the original shape, only while it holds no rows -------------------------------- */
IF OBJECT_ID('dbo.CustomerDevices', 'U') IS NOT NULL
   AND COL_LENGTH('dbo.CustomerDevices', 'SERN') IS NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.CustomerDevices)
        THROW 51000, 'dbo.CustomerDevices has rows and the old shape. This file only replaces an empty table: migrate the rows by hand first.', 1;

    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE referenced_object_id = OBJECT_ID('dbo.CustomerDevices'))
        THROW 51000, 'Another table has a foreign key to dbo.CustomerDevices. Drop it first and re-create it after this file.', 1;

    DROP TABLE dbo.CustomerDevices;
    PRINT 'dbo.CustomerDevices: empty original shape dropped.';
END
GO

/* ---- 2. The table ------------------------------------------------------------------------------ */
IF OBJECT_ID('dbo.CustomerDevices', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CustomerDevices
    (
        CustomerDeviceID            INT IDENTITY(1,1) NOT NULL,
        CustomerId                  INT            NOT NULL,
        SERN                        INT            NULL,      /* Priority SERNUMBERS.SERN; NULL = typed in the portal */

        /* identity of the device */
        SerialNumber                NVARCHAR(50)   NULL,      /* registered: the whole SERNUM, customer code prefix included */
        SerialKey                   AS UPPER(LTRIM(RTRIM(SerialNumber))) PERSISTED,
        Model                       NVARCHAR(150)  NULL,
        OrdersDeviceManufacturer    NVARCHAR(100)  NULL,
        ManufacturerNumber          NVARCHAR(100)  NULL,
        AdditionalDeviceNumber      NVARCHAR(100)  NULL,
        DevicePart                  INT            NULL,      /* Priority SERNUMBERS.PART: the device's own part */
        DeviceTypeName              NVARCHAR(100)  NULL,      /* that part's PARTDES */
        DeviceDescription           NVARCHAR(200)  NULL,      /* MBA_SERNUMBERS.SERNDES */
        OrdersProductTypeId         INT            NULL,      /* typed rows only: the service the customer picked */

        /* what the customer keeps about it */
        MainCategoryId              INT            NULL,
        SecondaryCategoryId         INT            NULL,
        CustomerSiteId              INT            NULL,
        CustomerContactId           INT            NULL,
        DeviceLocation              NVARCHAR(50)   NULL,
        Accuracy                    TINYINT        NULL,
        LastAdjustmentDate          DATETIME2(0)   NULL,
        DateFormatStructure         NVARCHAR(20)   NULL,
        NextCalibrationDate         DATETIME2(0)   NULL,      /* typed rows only */
        CalibrationIntervalMonths   TINYINT        NULL,
        ReportLanguage              NVARCHAR(50)   NULL,
        IsThirdPartyCalibration     BIT            NULL CONSTRAINT DF_CustomerDevices_IsThirdPartyCalibration DEFAULT (0),
        BatteriesReplacement        BIT            NULL CONSTRAINT DF_CustomerDevices_BatteriesReplacement    DEFAULT (0),
        CalibrationMethod           NVARCHAR(100)  NULL,
        SpecificationReferenceId    INT            NULL,
        MeasurementsSpecificationId INT            NULL,
        PrimaryMeasurmentUnitId     INT            NULL,
        SecondaryMeasurmentUnitId   INT            NULL,
        GuardBand                   DECIMAL(9,4)   NULL,

        /* state */
        IsDeleted                   BIT            NOT NULL CONSTRAINT DF_CustomerDevices_IsDeleted          DEFAULT (0),  /* the customer hid it */
        IsInactiveInSource          BIT            NOT NULL CONSTRAINT DF_CustomerDevices_IsInactiveInSource DEFAULT (0),  /* CANCELDATE > 0 in Priority */
        NeedsReview                 BIT            NOT NULL CONSTRAINT DF_CustomerDevices_NeedsReview        DEFAULT (0),
        NeedsReviewReason           NVARCHAR(200)  NULL,
        SourceUpdatedAt             DATETIME2(0)   NULL,      /* SERNUMBERS.UDATE, also the refresh watermark */
        RefreshedAt                 DATETIME2(0)   NULL,      /* when the refresh last wrote the row */
        CreatedDate                 DATETIME2(0)   NOT NULL CONSTRAINT DF_CustomerDevices_CreatedDate DEFAULT (GETDATE()),
        UpdatedDate                 DATETIME2(0)   NULL,
        UpdateUserID                INT            NULL,

        CONSTRAINT PK_CustomerDevices PRIMARY KEY CLUSTERED (CustomerDeviceID),

        CONSTRAINT FK_CustomerDevices_CustomerId                  FOREIGN KEY (CustomerId)                  REFERENCES dbo.Customers (CustomerId),
        /* Both keys are composite on the parent side, so the FK carries CustomerId too - and that is
           the rule we want: a device's site and contact belong to the device's own customer. */
        CONSTRAINT FK_CustomerDevices_CustomerSite                FOREIGN KEY (CustomerSiteId, CustomerId)    REFERENCES dbo.CustomerSites (CustomerSiteId, CustomerId),
        CONSTRAINT FK_CustomerDevices_CustomerContact             FOREIGN KEY (CustomerId, CustomerContactId) REFERENCES dbo.CustomerContacts (CustomerId, CustomerContactId),
        CONSTRAINT FK_CustomerDevices_MainCategoryId              FOREIGN KEY (MainCategoryId)              REFERENCES dbo.MainCategories (ID),
        CONSTRAINT FK_CustomerDevices_SecondaryCategoryId         FOREIGN KEY (SecondaryCategoryId)         REFERENCES dbo.SecondaryCategories (ID),
        CONSTRAINT FK_CustomerDevices_OrdersProductTypeId         FOREIGN KEY (OrdersProductTypeId)         REFERENCES dbo.OrdersProductTypes (OrdersProductTypeId),
        CONSTRAINT FK_CustomerDevices_SpecificationReferenceId    FOREIGN KEY (SpecificationReferenceId)    REFERENCES dbo.SpecificationReference (ID),
        CONSTRAINT FK_CustomerDevices_MeasurementsSpecificationId FOREIGN KEY (MeasurementsSpecificationId) REFERENCES dbo.MeasurementsSpecifications (ID),
        CONSTRAINT FK_CustomerDevices_PrimaryMeasurmentUnitId     FOREIGN KEY (PrimaryMeasurmentUnitId)     REFERENCES dbo.MeasurementDeviceUnits (MeasurementDeviceUnitId),
        CONSTRAINT FK_CustomerDevices_SecondaryMeasurmentUnitId   FOREIGN KEY (SecondaryMeasurmentUnitId)   REFERENCES dbo.MeasurementDeviceUnits (MeasurementDeviceUnitId),

        /* A registered row is a registered row: its id never goes back to NULL by accident. */
        CONSTRAINT CK_CustomerDevices_SERN_Positive CHECK (SERN IS NULL OR SERN > 0)
    );
    PRINT 'dbo.CustomerDevices: created.';
END
GO

/* ---- 3. Indexes (each guarded, so a replay adds what is missing) -------------------------------- */

/* Priority's device id is unique here. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.CustomerDevices') AND name = 'UX_CustomerDevices_SERN')
    CREATE UNIQUE NONCLUSTERED INDEX UX_CustomerDevices_SERN
        ON dbo.CustomerDevices (SERN) WHERE SERN IS NOT NULL;
GO

/* One typed device per customer and serial. Registered rows are exempt: Priority holds 11
   (CUST, SERNUM) groups with several SERN of its own, and they must still load. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.CustomerDevices') AND name = 'UX_CustomerDevices_TypedSerial')
    CREATE UNIQUE NONCLUSTERED INDEX UX_CustomerDevices_TypedSerial
        ON dbo.CustomerDevices (CustomerId, SerialKey) WHERE SERN IS NULL AND IsDeleted = 0;
GO

/* The portal reads by customer; the duplicate check reads (CustomerId, SerialKey) on every kind of row. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.CustomerDevices') AND name = 'IX_CustomerDevices_Customer_SerialKey')
    CREATE NONCLUSTERED INDEX IX_CustomerDevices_Customer_SerialKey
        ON dbo.CustomerDevices (CustomerId, SerialKey)
        INCLUDE (SERN, IsDeleted, IsInactiveInSource);
GO

/* The incremental refresh asks for MAX(SourceUpdatedAt). */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.CustomerDevices') AND name = 'IX_CustomerDevices_SourceUpdatedAt')
    CREATE NONCLUSTERED INDEX IX_CustomerDevices_SourceUpdatedAt
        ON dbo.CustomerDevices (SourceUpdatedAt) WHERE SourceUpdatedAt IS NOT NULL;
GO

/* The history join: a device's visits by SERN. The only change on the visit table. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.OrderDetailsItems') AND name = 'IX_OrderDetailsItems_SERN')
    CREATE NONCLUSTERED INDEX IX_OrderDetailsItems_SERN
        ON dbo.OrderDetailsItems (SERN)
        INCLUDE (Doc, ActualCalibrationDate, NextCalibrationDate, IsDeleted, IsCancelled)
        WHERE SERN IS NOT NULL;
GO
