CREATE TABLE [etl].[Users] (
    [ID]           INT            NOT NULL,
    [FirstName]    NVARCHAR (50)  NOT NULL,
    [LastName]     NVARCHAR (50)  NOT NULL,
    [FirstNameEng] NVARCHAR (50)  NULL,
    [LastNameEng]  NVARCHAR (50)  NULL,
    [Email]        NVARCHAR (50)  NULL,
    [Password]     NVARCHAR (50)  NULL,
    [Phone]        NVARCHAR (20)  NULL,
    [IsActive]     BIT            NOT NULL,
    [CreatedDate]  DATETIME2 (0)  NOT NULL,
    [UpdatedDate]  DATETIME2 (0)  NULL,
    [UpdateUserID] INT            NULL,
    [UserAddress]  NVARCHAR (200) NULL,
    [LocationArea] NVARCHAR (200) NULL,
    [Stamp]        NVARCHAR (30)  NULL
);

