CREATE TABLE [dbo].[CalibEquipmentsToOrderHeaders] (
    [OrderWorkPlanId]  INT           NOT NULL,
    [CalibEquipmentId] INT           NOT NULL,
    [CreatedByUserId]  INT           NULL,
    [CreateDate]       DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]      DATETIME2 (0) NULL,
    [IsDeleted]        BIT           DEFAULT ((0)) NOT NULL,
    [UpdateUserID]     INT           NULL,
    CONSTRAINT [PK_CalibEquipmentsToOrderHeaders] PRIMARY KEY CLUSTERED ([OrderWorkPlanId] ASC, [CalibEquipmentId] ASC),
    CONSTRAINT [FK_CalibEquipmentsToOrderHeaders_CalibEquipmentId] FOREIGN KEY ([CalibEquipmentId]) REFERENCES [dbo].[CalibEquipments] ([ID]),
    CONSTRAINT [FK_CalibEquipmentsToOrderHeaders_CreatedByUserId] FOREIGN KEY ([CreatedByUserId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_CalibEquipmentsToOrderHeaders_OrderWorkPlanId] FOREIGN KEY ([OrderWorkPlanId]) REFERENCES [dbo].[OrderWorkPlans] ([OrderWorkPlanId]),
    CONSTRAINT [FK_CalibEquipmentsToOrderHeaders_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

