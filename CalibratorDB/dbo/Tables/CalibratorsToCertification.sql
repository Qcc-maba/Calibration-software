CREATE TABLE [dbo].[CalibratorsToCertification] (
    [CertificationId] INT           NOT NULL,
    [CalibratorId]    INT           NOT NULL,
    [CreatedByUserId] INT           NULL,
    [CreatedDate]     DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_CalibratorsToCertification] PRIMARY KEY CLUSTERED ([CertificationId] ASC, [CalibratorId] ASC),
    CONSTRAINT [FK_CalibratorsToCertification_Calibrators] FOREIGN KEY ([CalibratorId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_CalibratorsToCertification_CertificationId] FOREIGN KEY ([CertificationId]) REFERENCES [dbo].[CalibratorsCertifications] ([ID]),
    CONSTRAINT [FK_CalibratorsToCertification_CreatedByUserId] FOREIGN KEY ([CreatedByUserId]) REFERENCES [dbo].[Users] ([ID])
);

