CREATE TABLE [dbo].[MeasurementDevicesSubClass] (
    [ID]                                 INT           IDENTITY (1, 1) NOT NULL,
    [Name]                               NVARCHAR (50) NOT NULL,
    [Description]                        NCHAR (10)    NULL,
    [CreatedDate]                        DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                        DATETIME2 (0) NULL,
    [IsDeleted]                          BIT           DEFAULT ((0)) NOT NULL,
    [UpdateUserID]                       INT           NULL,
    [MeasurementDevicesSubClassSourceId] INT           NULL,
    CONSTRAINT [PK_MeasurementDevicesFunction] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_MeasurementDevicesSubClass_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

