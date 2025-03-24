CREATE TABLE [dbo].[CalibEquipments] (
    [ID]            INT           IDENTITY (1, 1) NOT NULL,
    [DepartmentId]  INT           NOT NULL,
    [Name]          NVARCHAR (50) NOT NULL,
    [Quantity]      INT           CONSTRAINT [DF_Tools_Quantity] DEFAULT ((1)) NOT NULL,
    [StatusId]      INT           NULL,
    [TotalQuantity] INT           NULL,
    CONSTRAINT [PK_Tools] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_CalibEquipments_StatusId] FOREIGN KEY ([StatusId]) REFERENCES [dbo].[Statuses] ([StatusId]),
    CONSTRAINT [FK_Equipment_Departments] FOREIGN KEY ([DepartmentId]) REFERENCES [dbo].[Departments] ([ID])
);

