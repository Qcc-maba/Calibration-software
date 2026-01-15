CREATE TABLE [dbo].[CalibratorWorkstationSettings] (
    [CalibratorWorkstationSettingId] INT            IDENTITY (1, 1) NOT NULL,
    [CalibratorWorkstationName]      NVARCHAR (100) NOT NULL,
    [CalibratorId]                   INT            NULL,
    [CreateDate]                     DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                    DATETIME2 (0)  NULL,
    [UpdateUserID]                   INT            NULL,
    [IsDeleted]                      BIT            DEFAULT ((0)) NOT NULL,
    PRIMARY KEY CLUSTERED ([CalibratorWorkstationSettingId] ASC),
    CONSTRAINT [FK_CalibratorWorkstationSettings_CalibratorId] FOREIGN KEY ([CalibratorId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_CalibratorWorkstationSettings_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

