CREATE TABLE [stg].[stg_MeasurementsSpecifications] (
    [Name]                              VARCHAR (50)  NOT NULL,
    [Department]                        VARCHAR (100) NULL,
    [DescriptionHeb]                    VARCHAR (100) NULL,
    [DescriptionEng]                    VARCHAR (100) NULL,
    [Version]                           INT           NULL,
    [VersionDate]                       DATETIME      NULL,
    [MeasurementsSpecificationSourceId] INT           NULL
);

