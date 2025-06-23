CREATE TABLE [dbo].[MeasurementDeviceParents] (
    [MeasurementDeviceId]              INT           NOT NULL,
    [MeasurementDeviceParentId]        INT           NOT NULL,
    [MeasurementDeviceParentsSourceId] INT           NULL,
    [CreatedDate]                      DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                      DATETIME2 (0) NULL,
    [IsDeleted]                        BIT           DEFAULT ((0)) NOT NULL,
    [UpdateUserID]                     INT           NULL,
    CONSTRAINT [PK_MeasurementDeviceParents] PRIMARY KEY CLUSTERED ([MeasurementDeviceParentId] ASC, [MeasurementDeviceId] ASC, [CreatedDate] ASC),
    CONSTRAINT [FK_MeasurementDeviceParents_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

