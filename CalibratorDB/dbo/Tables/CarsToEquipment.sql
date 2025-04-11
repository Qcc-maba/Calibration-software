CREATE TABLE [dbo].[CarsToEquipment] (
    [CarId]        INT           NOT NULL,
    [EquipmentId]  INT           NOT NULL,
    [CreatedDate]  DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]  DATETIME2 (0) NULL,
    [IsDeleted]    BIT           DEFAULT ((0)) NOT NULL,
    [UpdateUserID] INT           NULL,
    CONSTRAINT [PK_CarsToEquipment] PRIMARY KEY CLUSTERED ([EquipmentId] ASC, [CarId] ASC, [CreatedDate] ASC),
    CONSTRAINT [FK_CarsToEquipment_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_Equipment_CarId] FOREIGN KEY ([CarId]) REFERENCES [dbo].[Cars] ([CarId]),
    CONSTRAINT [FK_Equipment_EquipmentId] FOREIGN KEY ([EquipmentId]) REFERENCES [dbo].[CalibEquipments] ([ID])
);

