CREATE TABLE [dbo].[MeasurementDevicesParents] (
    [MeasurementDeviceId]              INT           NOT NULL,
    [ParentId]                         INT           NOT NULL,
    [MeasurementDeviceParentsSourceId] INT           NULL,
    [CreatedDate]                      DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                      DATETIME2 (0) NULL,
    [IsDeleted]                        BIT           DEFAULT ((0)) NOT NULL,
    [UpdateUserID]                     INT           NULL,
    CONSTRAINT [PK_MeasurementDevicesParents] PRIMARY KEY CLUSTERED ([MeasurementDeviceId] ASC, [ParentId] ASC),
    CONSTRAINT [FK_MeasurementDevicesParents_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

