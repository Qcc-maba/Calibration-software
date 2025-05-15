CREATE TABLE [dbo].[AgentsWaitingList] (
    [AgentName]      NVARCHAR (100)  NOT NULL,
    [CustomerNumber] NVARCHAR (50)   NOT NULL,
    [CustomerName]   NVARCHAR (300) NULL,
    [Klita]          NVARCHAR (16)   NOT NULL,
    [src]            NVARCHAR(50)   NOT NULL
);

