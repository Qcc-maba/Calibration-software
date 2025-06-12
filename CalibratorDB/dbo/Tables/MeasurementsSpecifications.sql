CREATE TABLE [dbo].[MeasurementsSpecifications] (
    [ID]                                INT           IDENTITY (1, 1) NOT NULL,
    [Name]                              VARCHAR (50)  NOT NULL,
    [DepartmentId]                      INT           NOT NULL,
    [DescriptionHeb]                    VARCHAR (100) NULL,
    [DescriptionEng]                    VARCHAR (100) NULL,
    [Version]                           INT           NULL,
    [VersionDate]                       DATETIME      NULL,
    [CreatedDate]                       DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                       DATETIME2 (0) NULL,
    [IsDeleted]                         BIT           DEFAULT ((0)) NOT NULL,
    [UpdateUserID]                      INT           NULL,
    [MeasurementsSpecificationSourceId] INT           NULL,
    CONSTRAINT [PK_MeasurementsSpecifications] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_MeasurementsSpecifications_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

