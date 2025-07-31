CREATE TABLE [dbo].[MeasurementsSpecifications] (
    [ID]                                INT           IDENTITY (1, 1) NOT NULL,
    [Name]                              VARCHAR (50)  NOT NULL,
    [MainCategoryId]                    INT           NOT NULL,
    [CreatedDate]                       DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                       DATETIME2 (0) NULL,
    [IsDeleted]                         BIT           DEFAULT ((0)) NOT NULL,
    [UpdateUserID]                      INT           NULL,
    [MeasurementsSpecificationSourceId] INT           NULL,
    CONSTRAINT [PK_MeasurementsSpecifications] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_MeasurementsSpecifications_MainCategoryId] FOREIGN KEY ([MainCategoryId]) REFERENCES [dbo].[MainCategories] ([ID]),
    CONSTRAINT [FK_MeasurementsSpecifications_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

