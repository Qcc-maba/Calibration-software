CREATE TABLE [dbo].[OrdersDeviceManufacturers] (
    [OrdersDeviceManufacturerId]            INT            IDENTITY (1, 1) NOT NULL,
    [OrdersDeviceManufacturerName]          NVARCHAR (100) NULL,
    [OrdersDeviceManufacturerDescription]   NVARCHAR (100) NULL,
    [OrdersDeviceManufacturersIdFromSource] INT            NULL,
    [SourceId]                              TINYINT        NULL,
    [CreateDate]                            DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                           DATETIME2 (0)  NULL,
    [UpdateUserID]                          INT            NULL,
    [IsDeleted]                             BIT            DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_OrdersDeviceManufacturers] PRIMARY KEY CLUSTERED ([OrdersDeviceManufacturerId] ASC),
    CONSTRAINT [FK_OrdersDeviceManufacturers_SourceId] FOREIGN KEY ([SourceId]) REFERENCES [dbo].[Source] ([SourceId])
);

