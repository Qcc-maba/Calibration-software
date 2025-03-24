CREATE TABLE [dbo].[Equipment] (
    [EquipmentId]         INT            IDENTITY (1, 1) NOT NULL,
    [EquipmentName]       NVARCHAR (255) NOT NULL,
    [SerialNumber]        NVARCHAR (100) NULL,
    [StatusId]            INT            NOT NULL,
    [CalibratorId]        INT            NULL,
    [MainCategoryId]      INT            NULL,
    [SubcategoryId]       INT            NULL,
    [NextCalibrationDate] DATE           NULL,
    [CreatedDate]         DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]         DATETIME2 (0)  NULL,
    PRIMARY KEY CLUSTERED ([EquipmentId] ASC),
    CONSTRAINT [FK_Equipment_CalibratorId] FOREIGN KEY ([CalibratorId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_Equipment_StatusId] FOREIGN KEY ([StatusId]) REFERENCES [dbo].[Statuses] ([StatusId])
);

