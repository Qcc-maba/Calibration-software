CREATE TABLE [dbo].[Report] (
    [ID]                                 INT            IDENTITY (1, 1) NOT NULL,
    [ReportName]                         NVARCHAR (20)  NOT NULL,
    [CalibratedUnitID]                   INT            NOT NULL,
    [CalibratorId]                       INT            NOT NULL,
    [Standard]                           NVARCHAR (20)  NOT NULL,
    [ActualCalibrationDate]              DATETIME2 (7)  NOT NULL,
    [CalibrationSpecificationCompliency] BIT            NULL,
    [ReportConfirmationId]               INT            NULL,
    [GeneralInformation]                 NVARCHAR (255) NULL,
    [Comments]                           NVARCHAR (255) NULL,
    [UpdateDate]                         DATETIME2 (7)  NULL,
    [MeasurementDevicesId]               INT            NOT NULL,
    [ReportLanguage]                     NVARCHAR (10)  NULL,
    [CalibrationIcon]                    BIT            NULL,
    [ShowGraph]                          BIT            NULL,
    [ShowConclusion]                     BIT            NULL,
    [CreateDate]                         DATETIME2 (7)  CONSTRAINT [DF_Report_CreateDate] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_Report] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO
ALTER TABLE [dbo].[Report] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);

