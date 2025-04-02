CREATE TABLE [dbo].[CalibEquipmentsToOrderHeaders] (
    [OrderId]          INT           NOT NULL,
    [CalibEquipmentId] INT           NOT NULL,
    [CreateDate]       DATETIME2 (0) DEFAULT (getdate()) NULL,
    CONSTRAINT [PK_CalibEquipmentsToOrderHeaders] PRIMARY KEY CLUSTERED ([OrderId] ASC, [CalibEquipmentId] ASC)
);

