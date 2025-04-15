CREATE TABLE [dbo].[MeasurementDevicesManufacturers] (
    [ID]           INT            IDENTITY (1, 1) NOT NULL,
    [Name]         NVARCHAR (50)  NOT NULL,
    [Description]  NVARCHAR (150) NULL,
    [CreatedDate]  DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]  DATETIME2 (0)  NULL,
    [IsDeleted]    BIT            DEFAULT ((0)) NOT NULL,
    [UpdateUserID] INT            NULL,
    CONSTRAINT [PK_MeasurementDevicesManufacturers] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_MeasurementDevicesManufacturers_MeasurementDevicesManufacturers] FOREIGN KEY ([ID]) REFERENCES [dbo].[MeasurementDevicesManufacturers] ([ID])
);

