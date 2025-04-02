CREATE TABLE [dbo].[ClientRemarks] (
    [ClientRemarkId] INT            IDENTITY (1, 1) NOT NULL,
    [ClientRemark]   NVARCHAR (MAX) NULL,
    [TextHash]       VARBINARY (32) NULL,
    [OrderDetailId]  INT            NULL,
    PRIMARY KEY CLUSTERED ([ClientRemarkId] ASC)
);

