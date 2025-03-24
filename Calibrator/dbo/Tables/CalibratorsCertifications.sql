CREATE TABLE [dbo].[CalibratorsCertifications] (
    [ID]          INT           IDENTITY (1, 1) NOT NULL,
    [Certificate] NVARCHAR (25) NOT NULL,
    CONSTRAINT [PK_CalibratorsCertifications] PRIMARY KEY CLUSTERED ([ID] ASC)
);

