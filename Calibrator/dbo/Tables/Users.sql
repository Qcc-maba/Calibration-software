CREATE TABLE [dbo].[Users] (
    [ID]           INT           IDENTITY (1, 1) NOT NULL,
    [FirstName]    NVARCHAR (50) NOT NULL,
    [LastName]     NVARCHAR (50) NOT NULL,
    [FirstNameEng] NVARCHAR (50) NULL,
    [LastNameEng]  NVARCHAR (50) NULL,
    [Email]        NVARCHAR (50) NULL,
    [Password]     NVARCHAR (50) NULL,
    [Mobile]       NVARCHAR (20) NULL,
    [IsActive]     BIT           CONSTRAINT [DF_Users_IsActive] DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_Users] PRIMARY KEY CLUSTERED ([ID] ASC)
);

