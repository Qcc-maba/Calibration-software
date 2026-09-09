/*
    Tranche A - schema. Run this FIRST.
    ---------------------------------------------------------------------------------------------
    Additive except for one column widening, which is also safe: nothing is dropped, no data is
    rewritten, and every statement is guarded so the file can be re-run.

    Generated from the live STAGE schema, so what lands on PROD is what is running on STAGE.

    Regenerated 31/08 after the first deployment: STAGE moved while that round was being run, so
    this carries six more columns and one more table. Every statement is still guarded, so
    re-running the whole file is harmless - the parts already applied are skipped.
*/
SET NOCOUNT ON;
GO

/* ---- seven tables that do not exist on PROD ---- */

IF OBJECT_ID('dbo.CrmDeviceDescription') IS NULL
CREATE TABLE dbo.CrmDeviceDescription
(
    [CrmDeviceDescriptionId] int IDENTITY(1,1) NOT NULL,
    [DescriptionRaw] nvarchar(200) NOT NULL,
    [Description] nvarchar(200) NOT NULL,
    [NeedsReview] bit NOT NULL,
    [Devices] int NOT NULL,
    [Parts] int NOT NULL,
    [RefreshedAt] datetime2(7) NOT NULL,
    PRIMARY KEY CLUSTERED ([CrmDeviceDescriptionId])
);
GO

IF OBJECT_ID('dbo.CustomerPortalRequest') IS NULL
CREATE TABLE dbo.CustomerPortalRequest
(
    [CustomerPortalRequestId] bigint IDENTITY(1,1) NOT NULL,
    [RequestType] nvarchar(40) NOT NULL,
    [Status] nvarchar(20) NOT NULL,
    [CustomerId] int NOT NULL,
    [CustomerContactId] int NULL,
    [SubmittedByEmail] nvarchar(100) NOT NULL,
    [OrderWorkPlanId] int NULL,
    [OrderDetailsItemId] int NULL,
    [CustomerDeviceId] int NULL,
    [MbaReportNumber] nvarchar(100) NULL,
    [QuoteNumber] nvarchar(100) NULL,
    [RequestedDate] date NULL,
    [Reason] nvarchar(1000) NULL,
    [Notes] nvarchar(2000) NULL,
    [ShippingMethod] nvarchar(100) NULL,
    [ShippingDocument] nvarchar(100) NULL,
    [CustomerSiteId] int NULL,
    [DeviceLocation] nvarchar(200) NULL,
    [DeviceCount] int NULL,
    [CalibrationLocation] nvarchar(20) NULL,
    [CalibrateToDeviceSpec] bit NULL,
    [AttachmentPath] nvarchar(400) NULL,
    [CreatedDate] datetime2(3) NOT NULL,
    [ResolvedDate] datetime2(3) NULL,
    [ResolvedByUserId] int NULL,
    [ResolutionNotes] nvarchar(1000) NULL,
    [IsDeleted] bit NOT NULL,
    PRIMARY KEY CLUSTERED ([CustomerPortalRequestId])
);
GO

IF OBJECT_ID('dbo.CustomerPortalRequestItem') IS NULL
CREATE TABLE dbo.CustomerPortalRequestItem
(
    [CustomerPortalRequestItemId] bigint IDENTITY(1,1) NOT NULL,
    [CustomerPortalRequestId] bigint NOT NULL,
    [OrderDetailsItemId] int NULL,
    [CustomerDeviceId] int NULL,
    [MbaReportNumber] nvarchar(100) NULL,
    [SerialNumber] nvarchar(100) NULL,
    [Notes] nvarchar(1000) NULL,
    PRIMARY KEY CLUSTERED ([CustomerPortalRequestItemId])
);
GO

IF OBJECT_ID('dbo.MeasurmentPointsToCalibrationCycles') IS NULL
CREATE TABLE dbo.MeasurmentPointsToCalibrationCycles
(
    [MeasurmentPointsToCalibrationCycleId] int IDENTITY(1,1) NOT NULL,
    [OrderDetailsItemId] int NOT NULL,
    [CalibrationCycleStartDate] datetime2(0) NOT NULL,
    [SensorMeasurementDeviceId] int NOT NULL,
    [MeasurmentPointName] nvarchar(200) NOT NULL,
    [MeasurmentPointCoordX] decimal(10,4) NOT NULL,
    [MeasurmentPointCoordY] decimal(10,4) NOT NULL,
    [ChannelNumber] int NOT NULL,
    [CreateDate] datetime2(0) NOT NULL,
    [UpdatedDate] datetime2(0) NULL,
    [UpdateUserID] int NULL,
    [IsDeleted] bit NOT NULL,
    [MasterValue] decimal(18,6) NULL,
    [MasterValueUnitId] int NULL,
    [AdditionalValue] decimal(10,4) NULL,
    [AdditionalValueUnitId] int NULL,
    [StabilityValue] decimal(10,4) NULL,
    [UncertancyValue] decimal(10,4) NULL,
    [MeasuredValue] decimal(10,4) NULL,
    [MeasuredValueUnitId] int NULL,
    PRIMARY KEY CLUSTERED ([OrderDetailsItemId], [CalibrationCycleStartDate], [SensorMeasurementDeviceId], [ChannelNumber], [MeasurmentPointsToCalibrationCycleId])
);
GO

IF OBJECT_ID('dbo.OrderApprovalRequest') IS NULL
CREATE TABLE dbo.OrderApprovalRequest
(
    [OrderApprovalRequestId] bigint IDENTITY(1,1) NOT NULL,
    [OrderWorkPlanId] int NOT NULL,
    [OrderNumber] nvarchar(20) NOT NULL,
    [TokenHash] varbinary(32) NOT NULL,
    [CustomerId] int NULL,
    [CustomerContactId] int NULL,
    [SentToEmail] nvarchar(100) NOT NULL,
    [CreatedAt] datetime2(3) NOT NULL,
    [ExpiresAt] datetime2(3) NOT NULL,
    [RespondedAt] datetime2(3) NULL,
    [Decision] nvarchar(10) NULL,
    [ResponseNotes] nvarchar(1000) NULL,
    [ResponseIp] nvarchar(45) NULL,
    [InvalidatedAt] datetime2(3) NULL,
    [PriorityDocumentNumber] nvarchar(50) NULL,
    [PriorityError] nvarchar(1000) NULL,
    [PriorityCompletedAt] datetime2(3) NULL,
    PRIMARY KEY CLUSTERED ([OrderApprovalRequestId])
);
GO

IF OBJECT_ID('dbo.OrderNote') IS NULL
CREATE TABLE dbo.OrderNote
(
    [OrderNoteId] bigint IDENTITY(1,1) NOT NULL,
    [OrderWorkPlanId] int NOT NULL,
    [NoteText] nvarchar(2000) NOT NULL,
    [CreatedByUserId] int NULL,
    [CreatedByEmail] nvarchar(100) NULL,
    [CreatedDate] datetime2(3) NOT NULL,
    [IsDeleted] bit NOT NULL,
    [DeletedDate] datetime2(3) NULL,
    [DeletedByUserId] int NULL,
    PRIMARY KEY CLUSTERED ([OrderNoteId])
);
GO

IF OBJECT_ID('dbo.UserSensorTablePreferences') IS NULL
CREATE TABLE dbo.UserSensorTablePreferences
(
    [Id] int IDENTITY(1,1) NOT NULL,
    [UserId] int NULL,
    [ColumnVisibility] nvarchar(MAX) NULL,
    [ColumnOrder] nvarchar(MAX) NULL,
    [LockedColumns] nvarchar(MAX) NULL,
    [UpdatedDate] datetime2(7) NULL,
    [UpdateUserID] int NULL,
    PRIMARY KEY CLUSTERED ([Id])
);
GO

IF OBJECT_ID('dbo.CrmOrderAttachments') IS NULL
CREATE TABLE dbo.CrmOrderAttachments
(
    [ORD] int NOT NULL,
    [EXTFILENUM] int NOT NULL,
    [LINE] int NULL,
    [FilePath] nvarchar(200) NULL,
    [FileExtension] nvarchar(20) NULL,
    [Description] nvarchar(200) NULL,
    [DescriptionRaw] nvarchar(200) NULL,
    [IsPathTruncated] bit NOT NULL,
    [FetchedAt] datetime2(3) NOT NULL,
    PRIMARY KEY CLUSTERED ([ORD], [EXTFILENUM])
);
GO


/* ---- seven columns on existing tables ---- */
IF COL_LENGTH('dbo.MeasurementDevices','WorkRangeMin2') IS NULL
    ALTER TABLE dbo.MeasurementDevices ADD WorkRangeMin2 NUMERIC(18,6) NULL;
GO
IF COL_LENGTH('dbo.MeasurementDevices','WorkRangeMax2') IS NULL
    ALTER TABLE dbo.MeasurementDevices ADD WorkRangeMax2 NUMERIC(18,6) NULL;
GO
IF COL_LENGTH('dbo.MeasurementDevices','WorkRangeUnitId2') IS NULL
    ALTER TABLE dbo.MeasurementDevices ADD WorkRangeUnitId2 INT NULL;
GO
/* MBA-577 - the sensor identification page */
IF COL_LENGTH('dbo.OrderDetailsItems','Tolerance') IS NULL
    ALTER TABLE dbo.OrderDetailsItems ADD Tolerance DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.OrderDetailsItems','Resolution') IS NULL
    ALTER TABLE dbo.OrderDetailsItems ADD Resolution DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.OrderDetailsItems','SpecificationReferenceIds') IS NULL
    ALTER TABLE dbo.OrderDetailsItems ADD SpecificationReferenceIds NVARCHAR(MAX) NULL;
GO
/* The subsidiary should read SEPharma on screen. SourceName itself cannot change - it is the join
   key the whole Priority sync matches on, and Priority sends the literal SEPHARM. */
IF COL_LENGTH('dbo.Source','SourceDisplayName') IS NULL
    ALTER TABLE dbo.Source ADD SourceDisplayName NVARCHAR(100) NULL;
GO
UPDATE dbo.Source SET SourceDisplayName = N'MABA'     WHERE SourceId = 1 AND SourceDisplayName IS NULL;
UPDATE dbo.Source SET SourceDisplayName = N'SEPharma' WHERE SourceId = 2 AND SourceDisplayName IS NULL;
UPDATE dbo.Source SET SourceDisplayName = SourceName  WHERE SourceDisplayName IS NULL;
GO

/* ---- the one type change, and the reason it matters most in this file ----
   MasterValue was DECIMAL(10,8) on PROD. Precision 10 with scale 8 leaves TWO digits before the
   decimal point, so the column could not hold 100. A calibrator entering any reading of 100 or
   more got "arithmetic overflow", the save was rejected, and NOTHING on screen said so. 31-77's
   certificate runs to 349.98 and other masters reach 1104. */
IF EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id=c.user_type_id
           WHERE c.object_id=OBJECT_ID('dbo.MeasurmentPointsToOrderDetailsItems')
             AND c.name='MasterValue' AND (c.precision<>18 OR c.scale<>6))
    ALTER TABLE dbo.MeasurmentPointsToOrderDetailsItems ALTER COLUMN MasterValue DECIMAL(18,6) NULL;
GO
IF EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id=c.user_type_id
           WHERE c.object_id=OBJECT_ID('dbo.MeasurmentPointsToCalibrationCycles')
             AND c.name='MasterValue' AND (c.precision<>18 OR c.scale<>6))
    ALTER TABLE dbo.MeasurmentPointsToCalibrationCycles ALTER COLUMN MasterValue DECIMAL(18,6) NULL;
GO

/* ---- the index the compensation call needs ----
   Without it GetCalibrationValuesForManyOrderDetailItems takes 2.1 s per request instead of
   0.27 s, because every correction lookup scans the whole table. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MDC_Device_Version_Value')
CREATE NONCLUSTERED INDEX IX_MDC_Device_Version_Value
    ON dbo.MeasurementDevicesCorrections (MeasurementDevicesId, CorVersion DESC, Value1)
    INCLUDE (Deviation, MeasurementId, IsDeleted, Value2);
GO

/* ---- built after the first round, and the reason it needed a second ---- */

/* MBA-922 - the whole Priority phonebook, with a designated contact and the do-not-mail flag */
IF COL_LENGTH('dbo.CustomerContacts','IsPrimary') IS NULL
    ALTER TABLE dbo.CustomerContacts ADD IsPrimary BIT NOT NULL
        CONSTRAINT DF_CustomerContacts_IsPrimary DEFAULT(0);
GO
IF COL_LENGTH('dbo.CustomerContacts','DoNotMail') IS NULL
    ALTER TABLE dbo.CustomerContacts ADD DoNotMail BIT NOT NULL
        CONSTRAINT DF_CustomerContacts_DoNotMail DEFAULT(0);
GO
IF COL_LENGTH('stg.stg_CustomerContacts','IsPrimary') IS NULL
    ALTER TABLE stg.stg_CustomerContacts ADD IsPrimary BIT NULL;
GO
IF COL_LENGTH('stg.stg_CustomerContacts','DoNotMail') IS NULL
    ALTER TABLE stg.stg_CustomerContacts ADD DoNotMail BIT NULL;
GO
/* MBA-475 - may this instrument leave its range at all. Permissions, not thresholds. */
IF COL_LENGTH('dbo.MeasurementDevices','AllowMinOutOfRange') IS NULL
    ALTER TABLE dbo.MeasurementDevices ADD AllowMinOutOfRange BIT NULL;
GO
IF COL_LENGTH('dbo.MeasurementDevices','AllowMaxOutOfRange') IS NULL
    ALTER TABLE dbo.MeasurementDevices ADD AllowMaxOutOfRange BIT NULL;
GO
