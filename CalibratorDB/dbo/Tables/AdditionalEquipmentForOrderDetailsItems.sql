CREATE TABLE [dbo].[AdditionalEquipmentForOrderDetailsItems] (
    [OrderDetailsItemId]                        INT            NOT NULL,
    [AdditionalEquipmentForOrderDetailsItemsId] INT            IDENTITY (1, 1) NOT NULL,
    [EquipmentNumber]                           NVARCHAR (100) NULL,
    [EquipmentName]                             NVARCHAR (100) NULL,
    [CreateDate]                                DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                               DATETIME2 (0)  NULL,
    [UpdateUserID]                              INT            NULL,
    [IsDeleted]                                 BIT            DEFAULT ((0)) NOT NULL,
    PRIMARY KEY CLUSTERED ([OrderDetailsItemId] ASC, [AdditionalEquipmentForOrderDetailsItemsId] ASC)
);

