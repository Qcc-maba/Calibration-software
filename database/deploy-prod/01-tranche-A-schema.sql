/*  TRANCHE A - schema only. Additive: new tables and new columns.
    Nothing here drops or alters an existing column. Safe to re-run.  */

/* ---- dbo.CustomerPortalRequest ---- */
IF OBJECT_ID('dbo.CustomerPortalRequest','U') IS NULL
BEGIN
CREATE TABLE [dbo].[CustomerPortalRequest]
(
    [CustomerPortalRequestId] bigint IDENTITY(1,1) NOT NULL,
    [RequestType] nvarchar(40) NOT NULL,
    [Status] nvarchar(20) NOT NULL DEFAULT (N'New'),
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
    [CreatedDate] datetime2(3) NOT NULL DEFAULT (sysutcdatetime()),
    [ResolvedDate] datetime2(3) NULL,
    [ResolvedByUserId] int NULL,
    [ResolutionNotes] nvarchar(1000) NULL,
    [IsDeleted] bit NOT NULL DEFAULT ((0)),
    CONSTRAINT [PK_CustomerPortalRequest] PRIMARY KEY CLUSTERED ([CustomerPortalRequestId])
);
END
GO

/* ---- dbo.CustomerPortalRequestItem ---- */
IF OBJECT_ID('dbo.CustomerPortalRequestItem','U') IS NULL
BEGIN
CREATE TABLE [dbo].[CustomerPortalRequestItem]
(
    [CustomerPortalRequestItemId] bigint IDENTITY(1,1) NOT NULL,
    [CustomerPortalRequestId] bigint NOT NULL,
    [OrderDetailsItemId] int NULL,
    [CustomerDeviceId] int NULL,
    [MbaReportNumber] nvarchar(100) NULL,
    [SerialNumber] nvarchar(100) NULL,
    [Notes] nvarchar(1000) NULL,
    CONSTRAINT [PK_CustomerPortalRequestItem] PRIMARY KEY CLUSTERED ([CustomerPortalRequestItemId])
);
END
GO

/* ---- dbo.MeasurmentPointsToCalibrationCycles ---- */
IF OBJECT_ID('dbo.MeasurmentPointsToCalibrationCycles','U') IS NULL
BEGIN
CREATE TABLE [dbo].[MeasurmentPointsToCalibrationCycles]
(
    [MeasurmentPointsToCalibrationCycleId] int IDENTITY(1,1) NOT NULL,
    [OrderDetailsItemId] int NOT NULL,
    [CalibrationCycleStartDate] datetime2(0) NOT NULL,
    [SensorMeasurementDeviceId] int NOT NULL,
    [MeasurmentPointName] nvarchar(200) NOT NULL,
    [MeasurmentPointCoordX] decimal(10,4) NOT NULL,
    [MeasurmentPointCoordY] decimal(10,4) NOT NULL,
    [ChannelNumber] int NOT NULL,
    [CreateDate] datetime2(0) NOT NULL DEFAULT (getdate()),
    [UpdatedDate] datetime2(0) NULL,
    [UpdateUserID] int NULL,
    [IsDeleted] bit NOT NULL DEFAULT ((0)),
    [MasterValue] decimal(10,8) NULL,
    [MasterValueUnitId] int NULL,
    [AdditionalValue] decimal(10,4) NULL,
    [AdditionalValueUnitId] int NULL,
    [StabilityValue] decimal(10,4) NULL,
    [UncertancyValue] decimal(10,4) NULL,
    [MeasuredValue] decimal(10,4) NULL,
    [MeasuredValueUnitId] int NULL,
    CONSTRAINT [PK_MeasurmentPointsToCalibrationCycles] PRIMARY KEY CLUSTERED ([OrderDetailsItemId], [CalibrationCycleStartDate], [SensorMeasurementDeviceId], [ChannelNumber], [MeasurmentPointsToCalibrationCycleId])
);
END
GO

/* ---- dbo.OrderApprovalRequest ---- */
IF OBJECT_ID('dbo.OrderApprovalRequest','U') IS NULL
BEGIN
CREATE TABLE [dbo].[OrderApprovalRequest]
(
    [OrderApprovalRequestId] bigint IDENTITY(1,1) NOT NULL,
    [OrderWorkPlanId] int NOT NULL,
    [OrderNumber] nvarchar(20) NOT NULL,
    [TokenHash] varbinary(32) NOT NULL,
    [CustomerId] int NULL,
    [CustomerContactId] int NULL,
    [SentToEmail] nvarchar(100) NOT NULL,
    [CreatedAt] datetime2(3) NOT NULL DEFAULT (sysutcdatetime()),
    [ExpiresAt] datetime2(3) NOT NULL,
    [RespondedAt] datetime2(3) NULL,
    [Decision] nvarchar(10) NULL,
    [ResponseNotes] nvarchar(1000) NULL,
    [ResponseIp] nvarchar(45) NULL,
    [InvalidatedAt] datetime2(3) NULL,
    [PriorityDocumentNumber] nvarchar(50) NULL,
    [PriorityError] nvarchar(1000) NULL,
    [PriorityCompletedAt] datetime2(3) NULL,
    CONSTRAINT [PK_OrderApprovalRequest] PRIMARY KEY CLUSTERED ([OrderApprovalRequestId])
);
END
GO

/* ---- dbo.OrderNote ---- */
IF OBJECT_ID('dbo.OrderNote','U') IS NULL
BEGIN
CREATE TABLE [dbo].[OrderNote]
(
    [OrderNoteId] bigint IDENTITY(1,1) NOT NULL,
    [OrderWorkPlanId] int NOT NULL,
    [NoteText] nvarchar(2000) NOT NULL,
    [CreatedByUserId] int NULL,
    [CreatedByEmail] nvarchar(100) NULL,
    [CreatedDate] datetime2(3) NOT NULL DEFAULT (sysutcdatetime()),
    [IsDeleted] bit NOT NULL DEFAULT ((0)),
    [DeletedDate] datetime2(3) NULL,
    [DeletedByUserId] int NULL,
    CONSTRAINT [PK_OrderNote] PRIMARY KEY CLUSTERED ([OrderNoteId])
);
END
GO

/* ---- dbo.UserSensorTablePreferences ---- */
IF OBJECT_ID('dbo.UserSensorTablePreferences','U') IS NULL
BEGIN
CREATE TABLE [dbo].[UserSensorTablePreferences]
(
    [Id] int IDENTITY(1,1) NOT NULL,
    [UserId] int NULL,
    [ColumnVisibility] nvarchar(max) NULL,
    [ColumnOrder] nvarchar(max) NULL,
    [LockedColumns] nvarchar(max) NULL,
    [UpdatedDate] datetime2(7) NULL,
    [UpdateUserID] int NULL,
    CONSTRAINT [PK__UserSens__3214EC077A272941] PRIMARY KEY CLUSTERED ([Id])
);
END
GO

/* ---- three columns on dbo.MeasurementDevices ---- */
IF COL_LENGTH('dbo.MeasurementDevices','WorkRangeMin2') IS NULL
    ALTER TABLE dbo.MeasurementDevices ADD WorkRangeMin2 NUMERIC(18,6) NULL;
GO
IF COL_LENGTH('dbo.MeasurementDevices','WorkRangeMax2') IS NULL
    ALTER TABLE dbo.MeasurementDevices ADD WorkRangeMax2 NUMERIC(18,6) NULL;
GO
IF COL_LENGTH('dbo.MeasurementDevices','WorkRangeUnitId2') IS NULL
    ALTER TABLE dbo.MeasurementDevices ADD WorkRangeUnitId2 INT NULL;
GO

/* ---- three columns on dbo.OrderDetailsItems  (MBA-577, sensor identification) ---- */
IF COL_LENGTH('dbo.OrderDetailsItems','Tolerance') IS NULL
    ALTER TABLE dbo.OrderDetailsItems ADD Tolerance DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.OrderDetailsItems','Resolution') IS NULL
    ALTER TABLE dbo.OrderDetailsItems ADD Resolution DECIMAL(18,6) NULL;
GO
/* CSV of ids - Reference Document is multi-select. The singular SpecificationReferenceId
   column stays as it is. See dbo.AssignProductIdentificationData.sql for why. */
IF COL_LENGTH('dbo.OrderDetailsItems','SpecificationReferenceIds') IS NULL
    ALTER TABLE dbo.OrderDetailsItems ADD SpecificationReferenceIds NVARCHAR(MAX) NULL;
GO
