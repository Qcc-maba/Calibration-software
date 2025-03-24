CREATE TABLE [dbo].[UserMessages] (
    [Id]         INT           IDENTITY (1, 1) NOT NULL,
    [MessageHeb] NVARCHAR (50) NOT NULL,
    [MessageEng] NVARCHAR (50) NOT NULL,
    CONSTRAINT [PK_UserMessages] PRIMARY KEY CLUSTERED ([Id] ASC)
);

