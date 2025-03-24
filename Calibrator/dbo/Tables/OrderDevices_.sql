CREATE TABLE [dbo].[OrderDevices_] (
    [Id]              INT           IDENTITY (1, 1) NOT NULL,
    [OrderId]         INT           NOT NULL,
    [OrderNumber]     NCHAR (12)    NOT NULL,
    [MbaReportNumber] NCHAR (15)    NOT NULL,
    [CalibDate]       DATETIME2 (7) NULL,
    [NextCalibDate]   DATETIME2 (7) NULL,
    CONSTRAINT [PK_OrderDevices] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_OrderDevices_Orders] FOREIGN KEY ([OrderId]) REFERENCES [dbo].[Orders_] ([ID])
);

