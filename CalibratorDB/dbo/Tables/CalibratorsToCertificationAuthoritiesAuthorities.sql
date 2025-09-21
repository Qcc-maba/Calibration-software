CREATE TABLE [dbo].[CalibratorsToCertificationAuthoritiesAuthorities] (
    [CalibratorCertificationAuthorityId] INT           NOT NULL,
    [CalibratorId]                       INT           NOT NULL,
    [UpdateUserID]                       INT           NULL,
    [CreatedDate]                        DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                        DATETIME2 (0) NULL,
    [IsDeleted]                          BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_CalibratorsToCertificationAuthorities] PRIMARY KEY CLUSTERED ([CalibratorCertificationAuthorityId] ASC, [CalibratorId] ASC, [CreatedDate] ASC),
    CONSTRAINT [FK_CalibratorsToCertificationAuthorities_CalibratorCertificationAuthorityId] FOREIGN KEY ([CalibratorCertificationAuthorityId]) REFERENCES [dbo].[CalibratorCertificationAuthorities] ([ID]),
    CONSTRAINT [FK_CalibratorsToCertificationAuthorities_Calibrators] FOREIGN KEY ([CalibratorId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_CalibratorsToCertificationAuthorities_CreatedByUserId] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

