CREATE TABLE [dbo].[WorkPlan] (
    [Id]          INT            IDENTITY (1, 1) NOT NULL,
    [OrderNumber] VARCHAR (20)   NOT NULL,
    [Notes]       NVARCHAR (255) NULL,
    [OpenDate]    DATETIME2 (7)  CONSTRAINT [DF_WorkPlan_OpenDate] DEFAULT (getdate()) NULL,
    CONSTRAINT [PK_WorkPlan] PRIMARY KEY CLUSTERED ([Id] ASC)
);

