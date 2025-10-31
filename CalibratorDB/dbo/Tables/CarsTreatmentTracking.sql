CREATE TABLE [dbo].[CarsTreatmentTracking] (
    [CarId]              INT           NOT NULL,
    [DateOfChange]       DATETIME2 (0) NOT NULL,
    [TreatmentStartDate] DATETIME2 (0) NULL,
    [TreatmentEndDate]   DATETIME2 (0) NULL,
    [UpdateUserID]       INT           NOT NULL,
    PRIMARY KEY CLUSTERED ([CarId] ASC, [DateOfChange] DESC),
    CONSTRAINT [FK_CarsTreatmentTracking_SourceId] FOREIGN KEY ([CarId]) REFERENCES [dbo].[Cars] ([CarId]),
    CONSTRAINT [FK_CarsTreatmentTracking_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

