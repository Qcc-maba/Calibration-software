CREATE TABLE [dbo].[CertificationsToCalibrators] (
    [ID]              INT IDENTITY (1, 1) NOT NULL,
    [CertificationId] INT NOT NULL,
    [CalibratorId]    INT NOT NULL,
    CONSTRAINT [PK_CertificationsToCalibrators] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_CertificationsToCalibrators_Calibrators] FOREIGN KEY ([CalibratorId]) REFERENCES [dbo].[Calibrators] ([ID]),
    CONSTRAINT [FK_CertificationsToCalibrators_CalibratorsCertifications] FOREIGN KEY ([CertificationId]) REFERENCES [dbo].[CalibratorsCertifications] ([ID])
);

