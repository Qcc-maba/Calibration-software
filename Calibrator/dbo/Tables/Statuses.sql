CREATE TABLE [dbo].[Statuses] (
    [StatusId]             INT            IDENTITY (1, 1) NOT NULL,
    [StatusCategoryId]     INT            NOT NULL,
    [Code]                 NVARCHAR (255) NULL,
    [StatusDescriptionENG] NVARCHAR (255) NULL,
    [StatusDescriptionHEB] NVARCHAR (255) NULL,
    PRIMARY KEY CLUSTERED ([StatusId] ASC),
    CONSTRAINT [FK_Statuses_StatusesCategoriesId] FOREIGN KEY ([StatusCategoryId]) REFERENCES [dbo].[StatusesCategories] ([StatusCategoryId])
);

