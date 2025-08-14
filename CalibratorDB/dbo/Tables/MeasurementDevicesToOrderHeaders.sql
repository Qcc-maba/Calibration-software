CREATE TABLE [dbo].[MeasurementDevicesToOrderHeaders] (
    [OrderWorkPlanId]     INT           NOT NULL,
    [MeasurementDeviceId] INT           NOT NULL,
    [CreatedByUserId]     INT           NULL,
    [CreateDate]          DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]         DATETIME2 (0) NULL,
    [IsDeleted]           BIT           DEFAULT ((0)) NOT NULL,
    [UpdateUserID]        INT           NULL,
    [AssigmentDate]       DATE          DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_CalibEquipmentsToOrderHeaders] PRIMARY KEY CLUSTERED ([OrderWorkPlanId] ASC, [MeasurementDeviceId] ASC, [CreateDate] ASC),
    CONSTRAINT [FK_MeasurementDevicesToOrderHeaders_CalibEquipmentId] FOREIGN KEY ([MeasurementDeviceId]) REFERENCES [dbo].[MeasurementDevices] ([ID]),
    CONSTRAINT [FK_MeasurementDevicesToOrderHeaders_CreatedByUserId] FOREIGN KEY ([CreatedByUserId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_MeasurementDevicesToOrderHeaders_OrderWorkPlanId] FOREIGN KEY ([OrderWorkPlanId]) REFERENCES [dbo].[OrderWorkPlans] ([OrderWorkPlanId]),
    CONSTRAINT [FK_MeasurementDevicesToOrderHeaders_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

