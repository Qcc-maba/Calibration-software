CREATE TABLE [dbo].[COMPortSettings] (
    [CalibratorWorkstationSettingId] INT           NOT NULL,
    [COMPortSettingId]               INT           IDENTITY (1, 1) NOT NULL,
    [COMAddress]                     NVARCHAR (50) NOT NULL,
    [CreateDate]                     DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                    DATETIME2 (0) NULL,
    [UpdateUserID]                   INT           NULL,
    [IsDeleted]                      BIT           DEFAULT ((0)) NOT NULL,
    PRIMARY KEY CLUSTERED ([CalibratorWorkstationSettingId] ASC, [COMPortSettingId] ASC),
    CONSTRAINT [FK_COMPortSettings_CalibratorPCSettingsId] FOREIGN KEY ([CalibratorWorkstationSettingId]) REFERENCES [dbo].[CalibratorWorkstationSettings] ([CalibratorWorkstationSettingId]),
    CONSTRAINT [FK_COMPortSettings_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

