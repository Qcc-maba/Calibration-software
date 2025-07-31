CREATE TABLE [dbo].[MeasurementsSpecificationsToSecondCategory] (
    [MeasurementsSpecificationId] INT           NOT NULL,
    [SecondaryCategoryId]         INT           NOT NULL,
    [CreateDate]                  DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                 DATETIME2 (0) NULL,
    [UpdateUserID]                INT           NULL,
    [IsDeleted]                   BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_MeasurementsSpecificationsToSecondCategory] PRIMARY KEY CLUSTERED ([MeasurementsSpecificationId] ASC, [SecondaryCategoryId] ASC, [CreateDate] ASC),
    CONSTRAINT [FK_MeasurementsSpecificationsToSecondCategory_MeasurementsSpecificationId] FOREIGN KEY ([MeasurementsSpecificationId]) REFERENCES [dbo].[MeasurementsSpecifications] ([ID]),
    CONSTRAINT [FK_MeasurementsSpecificationsToSecondCategory_SecondaryCategoryId] FOREIGN KEY ([SecondaryCategoryId]) REFERENCES [dbo].[SecondaryCategories] ([ID]),
    CONSTRAINT [FK_MeasurementsSpecificationsToSecondCategory_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

