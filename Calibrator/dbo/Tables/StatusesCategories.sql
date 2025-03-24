CREATE TABLE [dbo].[StatusesCategories] (
    [StatusCategoryId]     INT            IDENTITY (1, 1) NOT NULL,
    [StatusDescriptionENG] NVARCHAR (255) NULL,
    [StatusDescriptionHEB] NVARCHAR (255) NULL,
    PRIMARY KEY CLUSTERED ([StatusCategoryId] ASC)
);

