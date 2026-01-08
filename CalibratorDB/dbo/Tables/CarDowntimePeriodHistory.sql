CREATE TABLE [dbo].[CarDowntimePeriodHistory] (
    [CarId]              INT           NOT NULL,
    [DateOfChange]       DATETIME2 (0) NOT NULL,
    [TreatmentStartDate] DATETIME2 (0) NULL,
    [TreatmentEndDate]   DATETIME2 (0) NULL,
    [UpdateUserID]       INT           NOT NULL,
    [StatusId]           INT           NOT NULL,
    [IsDeleted]          BIT           DEFAULT ((0)) NOT NULL,
    PRIMARY KEY CLUSTERED ([CarId] ASC, [DateOfChange] DESC),
    CONSTRAINT [FK_CarDowntimePeriodHistory_StatusId] FOREIGN KEY ([StatusId]) REFERENCES [dbo].[Statuses] ([StatusId]),
    CONSTRAINT [FK_CarsTreatmentTracking_SourceId] FOREIGN KEY ([CarId]) REFERENCES [dbo].[Cars] ([CarId]),
    CONSTRAINT [FK_CarsTreatmentTracking_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

